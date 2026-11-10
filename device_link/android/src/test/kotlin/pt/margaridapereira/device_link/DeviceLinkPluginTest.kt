package pt.margaridapereira.device_link

import pt.margaridapereira.device_link.protocol.AlarmCode
import pt.margaridapereira.device_link.protocol.DeviceMessage
import pt.margaridapereira.device_link.session.LinkState
import pt.margaridapereira.device_link.session.SessionEvent
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertNull

/** The map keys here are the contract with device_link/lib/src/events.dart. */
internal class DeviceLinkPluginTest {
    @Test
    fun linkEventsCarryStateAndReason() {
        val map = DeviceLinkPlugin.toMap(SessionEvent.Link(LinkState.DISCONNECTED, "no data from device"))
        assertEquals(mapOf("type" to "link", "state" to "disconnected", "reason" to "no data from device"), map)
    }

    @Test
    fun ecgSamplesStayAnIntArray() {
        val map = DeviceLinkPlugin.toMap(SessionEvent.Message(DeviceMessage.EcgSamples(250, intArrayOf(1, -2, 3))))!!
        assertEquals("ecg", map["type"])
        assertEquals(250L, map["firstIndex"])
        assertContentEquals(intArrayOf(1, -2, 3), map["samples"] as IntArray)
    }

    @Test
    fun alarmsUseTheirName() {
        val map = DeviceLinkPlugin.toMap(SessionEvent.Message(DeviceMessage.Alarm(AlarmCode.LEAD_OFF, true)))
        assertEquals(mapOf("type" to "alarm", "code" to "LEAD_OFF", "active" to true), map)
    }

    @Test
    fun unknownMessagesAreDropped() {
        assertNull(DeviceLinkPlugin.toMap(SessionEvent.Message(DeviceMessage.Unknown(0x55))))
    }
}
