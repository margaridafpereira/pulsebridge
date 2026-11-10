package pt.margaridapereira.device_link.protocol

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

private fun hex(s: String) = ByteArray(s.length / 2) { s.substring(it * 2, it * 2 + 2).toInt(16).toByte() }

/** Frames produced by the Python simulator (simulator/pulsebridge_sim/protocol.py). */
private object Golden {
    val hello = hex("a55a01010001001400fa0b50422d53494d2d3030303105312e302e30db76")
    val ecg = hex("a55a01100002000a000003e80000ff6a04b03b72")
    val heartRate = hex("a55a01110003000348034165b0")
    val alarm = hex("a55a01130004000201015d62")
    val ack = hex("a55a017f000500030201023f51")
    val start = hex("a55a012000070000c694")
}

class ProtocolTest {
    @Test
    fun crcMatchesStandardCheckValue() {
        assertEquals(0x29B1, Crc16.compute("123456789".encodeToByteArray()))
    }

    @Test
    fun encodesExactlyLikeThePythonSimulator() {
        assertContentEquals(Golden.start, Protocol.encode(Frame(MessageType.START_STREAM, 7)))
    }

    @Test
    fun parsesEveryMessageFromThePythonSimulator() {
        val decoder = FrameDecoder()
        val frames = listOf(Golden.hello, Golden.ecg, Golden.heartRate, Golden.alarm, Golden.ack)
            .flatMap { decoder.feed(it) }
        val messages = frames.map(DeviceMessage::parse)

        assertEquals(DeviceMessage.Hello("PB-SIM-0001", "1.0.0", 250), messages[0])
        val ecg = messages[1] as DeviceMessage.EcgSamples
        assertEquals(1000L, ecg.firstIndex)
        assertContentEquals(intArrayOf(0, -150, 1200), ecg.samplesUv)
        assertEquals(DeviceMessage.HeartRate(72, 833), messages[2])
        assertEquals(DeviceMessage.Alarm(AlarmCode.LEAD_OFF, true), messages[3])
        assertEquals(DeviceMessage.Ack(513, AckResult.INVALID_STATE), messages[4])
        assertEquals(listOf(1, 2, 3, 4, 5), frames.map { it.seq })
    }

    @Test
    fun decodesFrameSplitByteByByte() {
        val decoder = FrameDecoder()
        val frames = Golden.heartRate.flatMap { decoder.feed(byteArrayOf(it)) }
        assertEquals(listOf(3), frames.map { it.seq })
    }

    @Test
    fun skipsGarbageBeforeAFrame() {
        val decoder = FrameDecoder()
        val frames = decoder.feed(byteArrayOf(0x00, 0xA5.toByte(), 0x13, 0xFF.toByte()) + Golden.alarm)
        assertEquals(listOf(4), frames.map { it.seq })
        assertEquals(4, decoder.skippedBytes)
    }

    @Test
    fun rejectsCorruptFrameAndKeepsTheNextOne() {
        val corrupt = Golden.ecg.copyOf().also { it[10] = (it[10].toInt() xor 0xFF).toByte() }
        val decoder = FrameDecoder()
        val frames = decoder.feed(corrupt + Golden.heartRate)
        assertEquals(listOf(3), frames.map { it.seq })
        assertEquals(1, decoder.crcErrors)
    }

    @Test
    fun rejectsUnknownVersion() {
        val frame = Golden.alarm.copyOf().also { it[2] = 99 }
        assertTrue(FrameDecoder().feed(frame).isEmpty())
    }

    @Test
    fun refusesOversizedPayload() {
        assertFailsWith<IllegalArgumentException> {
            Protocol.encode(Frame(MessageType.ECG_SAMPLES, 1, ByteArray(Protocol.MAX_PAYLOAD + 1)))
        }
    }

    @Test
    fun roundTripsLargeFramesThroughTheGrowingBuffer() {
        val frames = (1..20).map { Frame(MessageType.ECG_SAMPLES, it, ByteArray(1000) { i -> i.toByte() }) }
        val bytes = frames.map(Protocol::encode).reduce(ByteArray::plus)
        assertEquals(frames, FrameDecoder().feed(bytes))
    }
}
