package pt.margaridapereira.device_link.ble

import java.util.UUID

/** GATT identifiers from the Bluetooth SIG assigned numbers. */
object GattIds {
    private fun uuid16(short: Int) = UUID.fromString(String.format("%08x-0000-1000-8000-00805f9b34fb", short))

    val HEART_RATE_SERVICE: UUID = uuid16(0x180D)
    val HEART_RATE_MEASUREMENT: UUID = uuid16(0x2A37)
    val BATTERY_SERVICE: UUID = uuid16(0x180F)
    val BATTERY_LEVEL: UUID = uuid16(0x2A19)
    val DEVICE_INFORMATION: UUID = uuid16(0x180A)
    val FIRMWARE_REVISION: UUID = uuid16(0x2A26)

    /** Client Characteristic Configuration descriptor: turns notifications on. */
    val CCCD: UUID = uuid16(0x2902)
}

/**
 * One Heart Rate Measurement notification (characteristic 0x2A37), as defined
 * in the Bluetooth SIG Heart Rate Service 1.0, section 3.1.
 *
 * @property contact null if the sensor cannot detect skin contact.
 * @property rrMs beat-to-beat intervals since the last notification, converted
 *   from 1/1024 s units. A notification can carry none, one or several.
 */
data class HeartRateMeasurement(
    val bpm: Int,
    val contact: Boolean?,
    val energyKj: Int?,
    val rrMs: List<Int>,
) {
    companion object {
        private const val HR_UINT16 = 0x01
        private const val CONTACT_SUPPORTED = 0x04
        private const val CONTACT_DETECTED = 0x02
        private const val ENERGY_PRESENT = 0x08
        private const val RR_PRESENT = 0x10

        fun parse(value: ByteArray): HeartRateMeasurement {
            require(value.size >= 2) { "Heart rate measurement too short: ${value.size} bytes" }
            fun u8(i: Int) = value[i].toInt() and 0xFF
            fun u16(i: Int) = u8(i) or (u8(i + 1) shl 8) // little-endian, as all GATT values

            val flags = u8(0)
            var i = 1
            val bpm: Int
            if (flags and HR_UINT16 != 0) {
                require(value.size >= 3) { "Missing 16-bit heart rate" }
                bpm = u16(i); i += 2
            } else {
                bpm = u8(i); i += 1
            }
            val contact = if (flags and CONTACT_SUPPORTED != 0) flags and CONTACT_DETECTED != 0 else null
            var energy: Int? = null
            if (flags and ENERGY_PRESENT != 0 && i + 1 < value.size) {
                energy = u16(i); i += 2
            }
            val rr = mutableListOf<Int>()
            if (flags and RR_PRESENT != 0) {
                while (i + 1 < value.size) {
                    rr += (u16(i) * 1000 + 512) / 1024
                    i += 2
                }
            }
            return HeartRateMeasurement(bpm, contact, energy, rr)
        }
    }
}
