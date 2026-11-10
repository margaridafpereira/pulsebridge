package pt.margaridapereira.device_link.session

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import pt.margaridapereira.device_link.protocol.DeviceMessage
import pt.margaridapereira.device_link.protocol.Frame
import pt.margaridapereira.device_link.protocol.FrameDecoder
import pt.margaridapereira.device_link.protocol.MessageType
import pt.margaridapereira.device_link.protocol.Protocol
import pt.margaridapereira.device_link.transport.TcpTransport
import java.net.ServerSocket
import java.net.Socket
import java.nio.ByteBuffer
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.fail

/** A minimal device on a local socket, scripted from each test. */
private class FakeDevice {
    val server = ServerSocket(0)
    val port get() = server.localPort
    val clients = LinkedBlockingQueue<Socket>()
    val received = LinkedBlockingQueue<Frame>()
    private var seq = 0

    init {
        thread(isDaemon = true) {
            while (!server.isClosed) {
                val socket = runCatching { server.accept() }.getOrNull() ?: break
                clients += socket
                thread(isDaemon = true) {
                    val decoder = FrameDecoder()
                    val buf = ByteArray(1024)
                    runCatching {
                        while (true) {
                            val n = socket.getInputStream().read(buf)
                            if (n < 0) break
                            decoder.feed(buf, n).forEach(received::add)
                        }
                    }
                }
            }
        }
    }

    fun send(socket: Socket, type: Int, payload: ByteArray = ByteArray(0), seqOverride: Int? = null) {
        seq = seqOverride ?: (seq + 1)
        socket.getOutputStream().write(Protocol.encode(Frame(type, seq, payload)))
    }

    fun ecg(firstIndex: Int, count: Int): ByteArray =
        ByteBuffer.allocate(4 + count * 2).putInt(firstIndex).also { b -> repeat(count) { b.putShort(0) } }.array()

    fun nextCommand(type: Int): Frame {
        while (true) {
            val frame = received.poll(5, TimeUnit.SECONDS) ?: fail("no command 0x%02X received".format(type))
            if (frame.type == type) return frame
        }
    }

    fun close() = server.close()
}

class DeviceSessionTest {
    private lateinit var device: FakeDevice
    private lateinit var scope: CoroutineScope
    private lateinit var session: DeviceSession
    private val events = LinkedBlockingQueue<SessionEvent>()

    @BeforeTest
    fun setUp() {
        device = FakeDevice()
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        session = DeviceSession(
            transportFactory = { TcpTransport("127.0.0.1", device.port, readTimeoutMs = 1_500) },
            scope = scope,
            onEvent = events::add,
            keepAliveMs = 200,
            initialBackoffMs = 100,
        )
    }

    @AfterTest
    fun tearDown() {
        session.stop()
        scope.cancel()
        device.close()
    }

    private inline fun <reified T : SessionEvent> next(predicate: (T) -> Boolean = { true }): T {
        val deadline = System.currentTimeMillis() + 5_000
        while (System.currentTimeMillis() < deadline) {
            val event = events.poll(100, TimeUnit.MILLISECONDS) ?: continue
            if (event is T && predicate(event)) return event
        }
        fail("no ${T::class.simpleName} event")
    }

    private fun connect(): Socket {
        session.start()
        next<SessionEvent.Link> { it.state == LinkState.CONNECTED }
        return device.clients.poll(5, TimeUnit.SECONDS) ?: fail("device saw no connection")
    }

    @Test
    fun connectsAndDeliversDeviceMessages() {
        val client = connect()
        device.send(client, MessageType.BATTERY, byteArrayOf(87))
        assertEquals(DeviceMessage.Battery(87), next<SessionEvent.Message>().message)
    }

    @Test
    fun startStreamingSendsTheCommand() {
        connect()
        session.startStreaming()
        device.nextCommand(MessageType.START_STREAM)
    }

    @Test
    fun keepsTheLinkAliveWithPings() {
        connect()
        device.nextCommand(MessageType.PING)
    }

    @Test
    fun reportsLostEcgSamples() {
        val client = connect()
        device.send(client, MessageType.ECG_SAMPLES, device.ecg(0, 25))
        device.send(client, MessageType.ECG_SAMPLES, device.ecg(50, 25))   // 25 samples missing
        assertEquals(SessionEvent.Gap(fromIndex = 25, lostSamples = 25), next<SessionEvent.Gap>())
    }

    @Test
    fun countsLostFramesFromSequenceGaps() {
        val client = connect()
        device.send(client, MessageType.BATTERY, byteArrayOf(90), seqOverride = 10)
        device.send(client, MessageType.BATTERY, byteArrayOf(89), seqOverride = 14)  // 11, 12, 13 lost
        next<SessionEvent.Stats> { it.lostFrames == 3 }
    }

    @Test
    fun reconnectsAndResumesStreamingAfterLinkLoss() {
        val first = connect()
        session.startStreaming()
        device.nextCommand(MessageType.START_STREAM)

        first.close()
        next<SessionEvent.Link> { it.state == LinkState.DISCONNECTED }
        next<SessionEvent.Link> { it.state == LinkState.CONNECTED }
        device.nextCommand(MessageType.START_STREAM)
    }

    @Test
    fun silentDeviceIsTreatedAsLinkLoss() {
        connect()
        // The fake device never answers pings, so the read times out.
        val lost = next<SessionEvent.Link> { it.state == LinkState.DISCONNECTED }
        assertEquals("no data from device", lost.reason)
    }
}
