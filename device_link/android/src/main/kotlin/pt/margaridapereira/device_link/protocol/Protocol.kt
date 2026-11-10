package pt.margaridapereira.device_link.protocol

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * PulseBridge wire protocol, version 1. Mirrors simulator/pulsebridge_sim/protocol.py;
 * the specification is docs/protocol.md.
 */
object Protocol {
    const val VERSION = 1
    const val MAX_PAYLOAD = 1024
    const val SYNC_0 = 0xA5
    const val SYNC_1 = 0x5A
    const val HEADER_SIZE = 6          // version, type, seq (2), length (2)
    const val OVERHEAD = 2 + HEADER_SIZE + 2

    fun encode(frame: Frame): ByteArray {
        require(frame.payload.size <= MAX_PAYLOAD) { "payload too large: ${frame.payload.size}" }
        val body = ByteBuffer.allocate(HEADER_SIZE + frame.payload.size).order(ByteOrder.BIG_ENDIAN)
            .put(VERSION.toByte())
            .put(frame.type.toByte())
            .putShort(frame.seq.toShort())
            .putShort(frame.payload.size.toShort())
            .put(frame.payload)
            .array()
        val crc = Crc16.compute(body)
        return ByteArrayOutputStream(OVERHEAD + frame.payload.size).apply {
            write(SYNC_0); write(SYNC_1)
            write(body)
            write(crc ushr 8); write(crc and 0xFF)
        }.toByteArray()
    }
}

/** CRC-16/CCITT-FALSE: poly 0x1021, init 0xFFFF, no reflection, no final XOR. */
object Crc16 {
    fun compute(data: ByteArray, from: Int = 0, to: Int = data.size): Int {
        var crc = 0xFFFF
        for (i in from until to) {
            crc = crc xor ((data[i].toInt() and 0xFF) shl 8)
            repeat(8) {
                crc = if (crc and 0x8000 != 0) (crc shl 1) xor 0x1021 else crc shl 1
                crc = crc and 0xFFFF
            }
        }
        return crc
    }
}

object MessageType {
    const val HELLO = 0x01
    const val ECG_SAMPLES = 0x10
    const val HEART_RATE = 0x11
    const val BATTERY = 0x12
    const val ALARM = 0x13
    const val FW_STATUS = 0x14
    const val ACK = 0x7F
    const val START_STREAM = 0x20
    const val STOP_STREAM = 0x21
    const val PING = 0x22
    const val FW_BEGIN = 0x30
    const val FW_CHUNK = 0x31
    const val FW_COMMIT = 0x32
    const val FW_ABORT = 0x33
}

/** Payloads of the firmware update commands (protocol.md, "Firmware update"). */
object FirmwareCommands {
    /** The bootloader accepts at most this many image bytes per chunk. */
    const val MAX_CHUNK = 512

    fun begin(size: Int, crc32: Long, version: String): ByteArray {
        val v = version.encodeToByteArray()
        return ByteBuffer.allocate(9 + v.size).order(ByteOrder.BIG_ENDIAN)
            .putInt(size).putInt(crc32.toInt()).put(v.size.toByte()).put(v).array()
    }

    fun chunk(offset: Int, data: ByteArray, from: Int, count: Int): ByteArray =
        ByteBuffer.allocate(4 + count).order(ByteOrder.BIG_ENDIAN).putInt(offset).put(data, from, count).array()
}

class Frame(val type: Int, val seq: Int, val payload: ByteArray = ByteArray(0)) {
    override fun equals(other: Any?) =
        other is Frame && type == other.type && seq == other.seq && payload.contentEquals(other.payload)

    override fun hashCode() = 31 * (31 * type + seq) + payload.contentHashCode()
    override fun toString() = "Frame(type=0x%02X, seq=%d, %d bytes)".format(type, seq, payload.size)
}

/**
 * Turns a byte stream into frames. Invalid data is skipped and decoding resumes one
 * byte after the rejected sync, so a corrupt frame never hides the next valid one.
 * Not thread-safe: feed it from a single reader.
 */
class FrameDecoder {
    private var buf = ByteArray(4096)
    private var len = 0

    var crcErrors = 0
        private set
    var skippedBytes = 0
        private set

    fun feed(data: ByteArray, count: Int = data.size): List<Frame> {
        ensureCapacity(len + count)
        System.arraycopy(data, 0, buf, len, count)
        len += count

        val frames = mutableListOf<Frame>()
        while (true) {
            val start = findSync()
            if (start < 0) {
                // A trailing 0xA5 may be the first half of the next sync.
                skip(if (len > 0 && u8(len - 1) == Protocol.SYNC_0) len - 1 else len)
                return frames
            }
            skip(start)
            if (len < 2 + Protocol.HEADER_SIZE) return frames

            val version = u8(2)
            val type = u8(3)
            val seq = (u8(4) shl 8) or u8(5)
            val length = (u8(6) shl 8) or u8(7)
            if (version != Protocol.VERSION || length > Protocol.MAX_PAYLOAD) {
                skip(1); continue
            }
            val total = Protocol.OVERHEAD + length
            if (len < total) return frames

            val crc = (u8(total - 2) shl 8) or u8(total - 1)
            if (crc != Crc16.compute(buf, 2, total - 2)) {
                crcErrors++
                skip(1); continue
            }
            frames += Frame(type, seq, buf.copyOfRange(2 + Protocol.HEADER_SIZE, total - 2))
            skip(total, countAsSkipped = false)
        }
    }

    private fun u8(i: Int) = buf[i].toInt() and 0xFF

    private fun findSync(): Int {
        for (i in 0 until len - 1) {
            if (u8(i) == Protocol.SYNC_0 && u8(i + 1) == Protocol.SYNC_1) return i
        }
        return -1
    }

    private fun skip(n: Int, countAsSkipped: Boolean = true) {
        if (n <= 0) return
        if (countAsSkipped) skippedBytes += n
        System.arraycopy(buf, n, buf, 0, len - n)
        len -= n
    }

    private fun ensureCapacity(needed: Int) {
        if (needed > buf.size) buf = buf.copyOf(maxOf(needed, buf.size * 2))
    }
}

/** Device-to-app messages, decoded from frame payloads. */
sealed interface DeviceMessage {
    data class Hello(val deviceId: String, val firmware: String, val sampleRate: Int) : DeviceMessage
    class EcgSamples(val firstIndex: Long, val samplesUv: IntArray) : DeviceMessage
    data class HeartRate(val bpm: Int, val rrMs: Int) : DeviceMessage
    data class Battery(val percent: Int) : DeviceMessage
    data class Alarm(val code: AlarmCode, val active: Boolean) : DeviceMessage
    data class Ack(val ackedSeq: Int, val result: AckResult) : DeviceMessage

    /** The bootloader's answer to every firmware command: its state and how many image bytes it holds. */
    data class FirmwareStatus(val state: FirmwareState, val received: Long, val detail: String) : DeviceMessage
    data class Unknown(val type: Int) : DeviceMessage

    companion object {
        fun parse(frame: Frame): DeviceMessage {
            val b = ByteBuffer.wrap(frame.payload).order(ByteOrder.BIG_ENDIAN)
            return when (frame.type) {
                MessageType.HELLO -> {
                    val sampleRate = b.short.toInt() and 0xFFFF
                    val id = ByteArray(b.get().toInt() and 0xFF).also { b.get(it) }
                    val fw = ByteArray(b.get().toInt() and 0xFF).also { b.get(it) }
                    Hello(id.decodeToString(), fw.decodeToString(), sampleRate)
                }
                MessageType.ECG_SAMPLES -> {
                    val first = b.int.toLong() and 0xFFFFFFFFL
                    EcgSamples(first, IntArray(b.remaining() / 2) { b.short.toInt() })
                }
                MessageType.HEART_RATE -> HeartRate(b.get().toInt() and 0xFF, b.short.toInt() and 0xFFFF)
                MessageType.BATTERY -> Battery(b.get().toInt() and 0xFF)
                MessageType.ALARM -> Alarm(AlarmCode.of(b.get().toInt() and 0xFF), b.get().toInt() != 0)
                MessageType.ACK -> Ack(b.short.toInt() and 0xFFFF, AckResult.of(b.get().toInt() and 0xFF))
                MessageType.FW_STATUS -> {
                    val state = FirmwareState.of(b.get().toInt() and 0xFF)
                    val received = b.int.toLong() and 0xFFFFFFFFL
                    val detail = ByteArray(b.get().toInt() and 0xFF).also { b.get(it) }
                    FirmwareStatus(state, received, detail.decodeToString())
                }
                else -> Unknown(frame.type)
            }
        }
    }
}

enum class AlarmCode(val code: Int) {
    LEAD_OFF(1), LOW_BATTERY(2), UNKNOWN(-1);

    companion object {
        fun of(code: Int) = entries.firstOrNull { it.code == code } ?: UNKNOWN
    }
}

enum class FirmwareState(val code: Int) {
    IDLE(0), RECEIVING(1), INSTALLED(2), REJECTED(3), UNKNOWN(-1);

    companion object {
        fun of(code: Int) = entries.firstOrNull { it.code == code } ?: UNKNOWN
    }
}

enum class AckResult(val code: Int) {
    OK(0), UNKNOWN_COMMAND(1), INVALID_STATE(2), UNKNOWN(-1);

    companion object {
        fun of(code: Int) = entries.firstOrNull { it.code == code } ?: UNKNOWN
    }
}
