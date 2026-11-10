package pt.margaridapereira.device_link.session

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import pt.margaridapereira.device_link.protocol.AckResult
import pt.margaridapereira.device_link.protocol.DeviceMessage
import pt.margaridapereira.device_link.protocol.Frame
import pt.margaridapereira.device_link.protocol.FrameDecoder
import pt.margaridapereira.device_link.protocol.MessageType
import pt.margaridapereira.device_link.protocol.Protocol
import pt.margaridapereira.device_link.transport.DeviceTransport
import java.io.IOException
import java.net.SocketTimeoutException
import java.util.concurrent.Executors
import kotlin.math.min

enum class LinkState { CONNECTING, CONNECTED, DISCONNECTED }

/** A link to one device, whatever the transport. DeviceHub holds one at a time. */
interface DeviceConnection {
    fun start()
    fun stop()
    fun startStreaming()
    fun stopStreaming()
}

sealed interface SessionEvent {
    data class Link(val state: LinkState, val reason: String? = null) : SessionEvent
    data class Message(val message: DeviceMessage) : SessionEvent

    /** ECG samples that never arrived (SRS-003). The trace must show a break here. */
    data class Gap(val fromIndex: Long, val lostSamples: Long) : SessionEvent
    data class Stats(val crcErrors: Int, val skippedBytes: Int, val lostFrames: Int, val lostSamples: Long) : SessionEvent
    data class Firmware(val progress: FirmwareProgress) : SessionEvent
}

/**
 * Owns the connection to one device: connects, keeps the link alive, decodes
 * frames, detects lost data and reconnects with backoff when the link drops
 * (SRS-004). Streaming is resumed after a reconnect if it was on before.
 *
 * Events are delivered on a background thread.
 */
class DeviceSession(
    private val transportFactory: () -> DeviceTransport,
    private val scope: CoroutineScope,
    private val onEvent: (SessionEvent) -> Unit,
    private val keepAliveMs: Long = 1_000,
    private val initialBackoffMs: Long = 500,
    private val maxBackoffMs: Long = 5_000,
) : DeviceConnection {
    private val writer = Executors.newSingleThreadExecutor { Thread(it, "device-writer").apply { isDaemon = true } }
    private val lock = Any()

    @Volatile private var transport: DeviceTransport? = null
    @Volatile private var wantStreaming = false
    private var job: Job? = null
    private var seq = 0
    @Volatile private var startSeq = -1

    // Loss tracking, touched only by the reader coroutine.
    private var decoder = FrameDecoder()
    private var lastDeviceSeq: Int? = null
    private var expectedIndex: Long? = null
    private var lostFrames = 0
    private var lostSamples = 0L

    val isRunning get() = job?.isActive == true

    override fun start() {
        if (isRunning) return
        job = scope.launch(Dispatchers.IO) { connectLoop() }
    }

    override fun stop() {
        wantStreaming = false
        job?.cancel()
        job = null
        transport?.close()
    }

    override fun startStreaming() {
        wantStreaming = true
        send(MessageType.START_STREAM)
    }

    override fun stopStreaming() {
        wantStreaming = false
        send(MessageType.STOP_STREAM)
    }

    private suspend fun connectLoop() {
        var backoff = initialBackoffMs
        while (currentCoroutineContext().isActive) {
            onEvent(SessionEvent.Link(LinkState.CONNECTING))
            val t = transportFactory()
            try {
                t.open()
                transport = t
                resetTracking()
                onEvent(SessionEvent.Link(LinkState.CONNECTED))
                backoff = initialBackoffMs
                if (wantStreaming) send(MessageType.START_STREAM)
                coroutineScope {
                    val keepAlive = launch {
                        while (isActive) {
                            delay(keepAliveMs)
                            send(MessageType.PING)
                            onEvent(SessionEvent.Stats(decoder.crcErrors, decoder.skippedBytes, lostFrames, lostSamples))
                        }
                    }
                    try {
                        readLoop(t)
                    } finally {
                        keepAlive.cancel()
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: SocketTimeoutException) {
                onEvent(SessionEvent.Link(LinkState.DISCONNECTED, "no data from device"))
            } catch (e: IOException) {
                onEvent(SessionEvent.Link(LinkState.DISCONNECTED, e.message ?: "link lost"))
            } finally {
                transport = null
                t.close()
            }
            delay(backoff)
            backoff = min(backoff * 2, maxBackoffMs)
        }
    }

    private fun readLoop(t: DeviceTransport) {
        val input = t.input
        val buffer = ByteArray(4096)
        while (true) {
            val n = input.read(buffer)
            if (n < 0) throw IOException("device closed the link")
            for (frame in decoder.feed(buffer, n)) handle(frame)
        }
    }

    private fun handle(frame: Frame) {
        lastDeviceSeq?.let { last ->
            val missed = (frame.seq - last - 1) and 0xFFFF
            lostFrames += missed
        }
        lastDeviceSeq = frame.seq

        when (val message = DeviceMessage.parse(frame)) {
            is DeviceMessage.EcgSamples -> {
                val expected = expectedIndex
                if (expected != null && message.firstIndex > expected) {
                    val lost = message.firstIndex - expected
                    lostSamples += lost
                    onEvent(SessionEvent.Gap(expected, lost))
                }
                expectedIndex = message.firstIndex + message.samplesUv.size
                onEvent(SessionEvent.Message(message))
            }
            is DeviceMessage.Ack -> {
                // A (re)started stream counts samples from 0 again.
                if (message.result == AckResult.OK && message.ackedSeq == startSeq) expectedIndex = null
                onEvent(SessionEvent.Message(message))
            }
            else -> onEvent(SessionEvent.Message(message))
        }
    }

    /** Sends a command; dropped silently if the link is down (the reconnect logic handles that). */
    fun send(type: Int, payload: ByteArray = ByteArray(0)) {
        writer.execute {
            val t = transport ?: return@execute
            synchronized(lock) {
                seq = (seq + 1) and 0xFFFF
                if (type == MessageType.START_STREAM) startSeq = seq
                try {
                    t.output.write(Protocol.encode(Frame(type, seq, payload)))
                    t.output.flush()
                } catch (_: IOException) {
                    // The reader sees the broken link and reconnects.
                }
            }
        }
    }

    private fun resetTracking() {
        decoder = FrameDecoder()
        lastDeviceSeq = null
        expectedIndex = null
    }
}
