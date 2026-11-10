package pt.margaridapereira.device_link.ble

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import pt.margaridapereira.device_link.protocol.AlarmCode
import pt.margaridapereira.device_link.protocol.DeviceMessage
import pt.margaridapereira.device_link.session.LinkState
import pt.margaridapereira.device_link.session.SessionEvent
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.fail

class HeartRateMeasurementTest {
    private fun bytes(vararg v: Int) = ByteArray(v.size) { v[it].toByte() }

    @Test
    fun parsesAn8BitRateWithoutContactSupport() {
        val m = HeartRateMeasurement.parse(bytes(0x00, 72))
        assertEquals(72, m.bpm)
        assertNull(m.contact)
        assertEquals(emptyList(), m.rrMs)
    }

    @Test
    fun parsesA16BitRate() {
        assertEquals(300, HeartRateMeasurement.parse(bytes(0x01, 0x2C, 0x01)).bpm)
    }

    @Test
    fun readsSkinContact() {
        assertEquals(true, HeartRateMeasurement.parse(bytes(0x06, 60)).contact)
        assertEquals(false, HeartRateMeasurement.parse(bytes(0x04, 0)).contact)
    }

    @Test
    fun skipsEnergyAndConvertsRrFrom1024ths() {
        // flags: energy + RR present; 70 bpm; energy 0x0102; RR 1024 (1000 ms) and 512 (500 ms)
        val m = HeartRateMeasurement.parse(bytes(0x18, 70, 0x02, 0x01, 0x00, 0x04, 0x00, 0x02))
        assertEquals(258, m.energyKj)
        assertEquals(listOf(1000, 500), m.rrMs)
    }

    @Test
    fun rejectsATruncatedValue() {
        assertFailsWith<IllegalArgumentException> { HeartRateMeasurement.parse(bytes(0x01)) }
        assertFailsWith<IllegalArgumentException> { HeartRateMeasurement.parse(bytes(0x01, 0x40)) }
    }
}

/** A sensor whose connections the test drives by hand. */
private class FakeGatt {
    val links = LinkedBlockingQueue<Link>()

    inner class Link : GattLink {
        lateinit var emit: (GattEvent) -> Unit
        @Volatile var closed = false

        override fun open(onEvent: (GattEvent) -> Unit) {
            emit = onEvent
            links += this
        }

        override fun close() {
            closed = true
        }
    }

    fun nextLink(): Link = links.poll(3, TimeUnit.SECONDS) ?: fail("no connection attempt")
}

class BleHeartRateSessionTest {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val events = LinkedBlockingQueue<SessionEvent>()
    private val gatt = FakeGatt()

    @AfterTest
    fun tearDown() = scope.cancel()

    private fun session(silenceMs: Long = 5_000) = BleHeartRateSession(
        "AA:BB:CC:DD:EE:FF", { gatt.Link() }, scope, { events += it },
        silenceMs = silenceMs, connectTimeoutMs = 2_000, initialBackoffMs = 50, maxBackoffMs = 100,
    ).also { it.start() }

    private inline fun <reified T : SessionEvent> next(match: (T) -> Boolean = { true }): T {
        val deadline = System.currentTimeMillis() + 4_000
        while (System.currentTimeMillis() < deadline) {
            val e = events.poll(100, TimeUnit.MILLISECONDS) ?: continue
            if (e is T && match(e)) return e
        }
        fail("no ${T::class.simpleName}")
    }

    private fun measurement(vararg v: Int) = GattEvent.Measurement(ByteArray(v.size) { v[it].toByte() })

    @Test
    fun connectsAndReportsTheSensor() {
        session()
        val link = gatt.nextLink()
        link.emit(GattEvent.Ready("Polar H10", "3.1.1"))
        next<SessionEvent.Link> { it.state == LinkState.CONNECTED }
        assertEquals(DeviceMessage.Hello("Polar H10", "3.1.1", 0), next<SessionEvent.Message> { it.message is DeviceMessage.Hello }.message)
    }

    @Test
    fun emitsOneBeatPerRrInterval() {
        session()
        gatt.nextLink().apply {
            emit(GattEvent.Ready("HR", null))
            emit(measurement(0x10, 70, 0x00, 0x04, 0x00, 0x02)) // RR 1000 ms then 500 ms
        }
        assertEquals(DeviceMessage.HeartRate(60, 1000), next<SessionEvent.Message> { it.message is DeviceMessage.HeartRate }.message)
        assertEquals(DeviceMessage.HeartRate(120, 500), next<SessionEvent.Message> { it.message is DeviceMessage.HeartRate }.message)
    }

    @Test
    fun lostSkinContactRaisesLeadOffAndSuppressesTheRate() {
        session()
        gatt.nextLink().apply {
            emit(GattEvent.Ready("HR", null))
            emit(measurement(0x04, 0)) // contact supported, not detected
            emit(measurement(0x06, 64)) // contact back
        }
        assertEquals(DeviceMessage.Alarm(AlarmCode.LEAD_OFF, true), next<SessionEvent.Message> { it.message is DeviceMessage.Alarm }.message)
        assertEquals(DeviceMessage.Alarm(AlarmCode.LEAD_OFF, false), next<SessionEvent.Message> { it.message is DeviceMessage.Alarm }.message)
        assertEquals(64, (next<SessionEvent.Message> { it.message is DeviceMessage.HeartRate }.message as DeviceMessage.HeartRate).bpm)
    }

    @Test
    fun silentSensorCountsAsLostAndReconnects() {
        session(silenceMs = 300)
        val first = gatt.nextLink()
        first.emit(GattEvent.Ready("HR", null))
        next<SessionEvent.Link> { it.state == LinkState.CONNECTED }
        assertEquals("no data from sensor", next<SessionEvent.Link> { it.state == LinkState.DISCONNECTED }.reason)
        assert(first.closed)
        gatt.nextLink().emit(GattEvent.Ready("HR", null))
        next<SessionEvent.Link> { it.state == LinkState.CONNECTED }
    }

    @Test
    fun aDroppedLinkIsReportedWithItsReason() {
        session()
        gatt.nextLink().apply {
            emit(GattEvent.Ready("HR", null))
            emit(GattEvent.Lost("sensor disconnected"))
        }
        assertEquals("sensor disconnected", next<SessionEvent.Link> { it.state == LinkState.DISCONNECTED }.reason)
    }

    @Test
    fun malformedNotificationsAreDropped() {
        session()
        gatt.nextLink().apply {
            emit(GattEvent.Ready("HR", null))
            emit(measurement(0x01)) // truncated
            emit(measurement(0x00, 80))
        }
        assertEquals(80, (next<SessionEvent.Message> { it.message is DeviceMessage.HeartRate }.message as DeviceMessage.HeartRate).bpm)
    }
}
