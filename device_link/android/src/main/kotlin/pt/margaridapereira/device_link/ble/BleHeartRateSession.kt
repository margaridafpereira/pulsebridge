package pt.margaridapereira.device_link.ble

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import pt.margaridapereira.device_link.protocol.AlarmCode
import pt.margaridapereira.device_link.protocol.DeviceMessage
import pt.margaridapereira.device_link.session.DeviceConnection
import pt.margaridapereira.device_link.session.LinkState
import pt.margaridapereira.device_link.session.SessionEvent
import kotlin.math.min

/** What a GATT link reports. Kept apart from Android types so the session can be unit-tested. */
sealed interface GattEvent {
    data class Ready(val name: String?, val firmware: String?) : GattEvent
    data class Measurement(val value: ByteArray) : GattEvent
    data class Battery(val percent: Int) : GattEvent
    data class Lost(val reason: String) : GattEvent
}

/** One GATT connection attempt. [open] connects, discovers and subscribes, then reports through [onEvent]. */
interface GattLink {
    fun open(onEvent: (GattEvent) -> Unit)
    fun close()
}

/**
 * A standard Bluetooth heart-rate sensor (Heart Rate Service 0x180D): a chest
 * strap, a watch, or nRF Connect advertising the service.
 *
 * It applies the same safety rules as the TCP session: link state is always
 * reported, a sensor silent for [silenceMs] counts as lost (SRS-006), and the
 * session reconnects with backoff (SRS-004). Lost skin contact is reported as
 * LEAD_OFF, so the app suppresses the heart rate exactly as for the ECG device.
 *
 * These sensors send no ECG, only heart rate and RR intervals.
 */
class BleHeartRateSession(
    private val address: String,
    private val linkFactory: () -> GattLink,
    private val scope: CoroutineScope,
    private val onEvent: (SessionEvent) -> Unit,
    private val silenceMs: Long = 5_000,
    private val connectTimeoutMs: Long = 15_000,
    private val initialBackoffMs: Long = 1_000,
    private val maxBackoffMs: Long = 10_000,
) : DeviceConnection {
    private var job: Job? = null
    private var contactLost = false

    override fun start() {
        if (job?.isActive == true) return
        job = scope.launch { connectLoop() }
    }

    override fun stop() {
        job?.cancel()
        job = null
    }

    // A heart-rate sensor notifies continuously once subscribed; recording is
    // decided in the app, so there is nothing to send.
    override fun startStreaming() = Unit

    override fun stopStreaming() = Unit

    private suspend fun connectLoop() {
        var backoff = initialBackoffMs
        while (currentCoroutineContext().isActive) {
            onEvent(SessionEvent.Link(LinkState.CONNECTING))
            val events = Channel<GattEvent>(Channel.UNLIMITED)
            val link = linkFactory()
            val reason = try {
                link.open { events.trySend(it) }
                session(events).also { if (it == null) backoff = initialBackoffMs }
            } finally {
                link.close()
            }
            if (contactLost) {
                contactLost = false
                onEvent(SessionEvent.Message(DeviceMessage.Alarm(AlarmCode.LEAD_OFF, false)))
            }
            onEvent(SessionEvent.Link(LinkState.DISCONNECTED, reason ?: "link lost"))
            delay(backoff)
            backoff = min(backoff * 2, maxBackoffMs)
        }
    }

    /** Runs one connection until it is lost. Returns why. */
    private suspend fun session(events: Channel<GattEvent>): String? {
        val ready = withTimeoutOrNull(connectTimeoutMs) {
            var first = events.receive()
            while (first is GattEvent.Battery) first = events.receive()
            first
        } ?: return "sensor not found"
        when (ready) {
            is GattEvent.Lost -> return ready.reason
            is GattEvent.Ready -> {
                onEvent(SessionEvent.Link(LinkState.CONNECTED))
                onEvent(SessionEvent.Message(DeviceMessage.Hello(ready.name ?: address, ready.firmware ?: "", 0)))
            }
            else -> handle(ready)
        }
        while (true) {
            val event = withTimeoutOrNull(silenceMs) { events.receive() } ?: return "no data from sensor"
            when (event) {
                is GattEvent.Lost -> return event.reason
                else -> handle(event)
            }
        }
    }

    private fun handle(event: GattEvent) {
        when (event) {
            is GattEvent.Battery -> onEvent(SessionEvent.Message(DeviceMessage.Battery(event.percent)))
            is GattEvent.Measurement -> {
                val m = try {
                    HeartRateMeasurement.parse(event.value)
                } catch (_: IllegalArgumentException) {
                    return // malformed notification: drop it, as the TCP side drops a bad frame
                }
                val lost = m.contact == false
                if (lost != contactLost) {
                    contactLost = lost
                    onEvent(SessionEvent.Message(DeviceMessage.Alarm(AlarmCode.LEAD_OFF, lost)))
                }
                if (lost || m.bpm == 0) return
                // One beat per RR interval keeps the rhythm analysis working. Without
                // RR data, the reported rate is the only beat information.
                if (m.rrMs.isEmpty()) {
                    onEvent(SessionEvent.Message(DeviceMessage.HeartRate(m.bpm, 60_000 / m.bpm)))
                } else {
                    for (rr in m.rrMs) {
                        if (rr > 0) onEvent(SessionEvent.Message(DeviceMessage.HeartRate((60_000 + rr / 2) / rr, rr)))
                    }
                }
            }
            else -> Unit
        }
    }
}
