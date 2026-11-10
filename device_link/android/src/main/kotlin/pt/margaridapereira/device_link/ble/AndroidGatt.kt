package pt.margaridapereira.device_link.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid

/**
 * BluetoothGatt behind [GattLink]. GATT allows one operation at a time, so
 * reads and descriptor writes go through a small queue, each started when the
 * previous one's callback arrives.
 *
 * Callers check the Bluetooth permissions first; a SecurityException is still
 * reported as a lost link rather than crashing the service.
 */
@SuppressLint("MissingPermission")
class AndroidGattLink(private val context: Context, private val address: String) : GattLink {
    private var gatt: BluetoothGatt? = null
    private var onEvent: (GattEvent) -> Unit = {}
    private val queue = ArrayDeque<(BluetoothGatt) -> Boolean>()
    private var name: String? = null
    private var firmware: String? = null

    override fun open(onEvent: (GattEvent) -> Unit) {
        this.onEvent = onEvent
        try {
            val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter
            if (adapter == null || !adapter.isEnabled) return onEvent(GattEvent.Lost("Bluetooth is off"))
            val device = adapter.getRemoteDevice(address)
            name = device.name
            gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
        } catch (e: SecurityException) {
            onEvent(GattEvent.Lost("Bluetooth permission missing"))
        } catch (e: IllegalArgumentException) {
            onEvent(GattEvent.Lost("invalid address $address"))
        }
    }

    override fun close() {
        try {
            gatt?.disconnect()
            gatt?.close()
        } catch (_: SecurityException) {
        }
        gatt = null
    }

    private fun next(g: BluetoothGatt) {
        while (queue.isNotEmpty()) {
            // An operation that cannot start (characteristic missing) is skipped.
            if (queue.removeFirst()(g)) return
        }
    }

    private val callback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            when {
                newState == BluetoothProfile.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS -> g.discoverServices()
                newState == BluetoothProfile.STATE_DISCONNECTED ->
                    onEvent(GattEvent.Lost(if (status == BluetoothGatt.GATT_SUCCESS) "sensor disconnected" else "GATT error $status"))
                status != BluetoothGatt.GATT_SUCCESS -> onEvent(GattEvent.Lost("GATT error $status"))
            }
        }

        override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
            val hr = g.getService(GattIds.HEART_RATE_SERVICE)?.getCharacteristic(GattIds.HEART_RATE_MEASUREMENT)
            if (status != BluetoothGatt.GATT_SUCCESS || hr == null) {
                return onEvent(GattEvent.Lost("not a heart-rate sensor"))
            }
            val fw = g.getService(GattIds.DEVICE_INFORMATION)?.getCharacteristic(GattIds.FIRMWARE_REVISION)
            val battery = g.getService(GattIds.BATTERY_SERVICE)?.getCharacteristic(GattIds.BATTERY_LEVEL)
            queue.clear()
            queue += { fw != null && it.readCharacteristic(fw) }
            queue += { battery != null && it.readCharacteristic(battery) }
            queue += { battery != null && subscribe(it, battery) }
            queue += { subscribe(it, hr) }
            queue += { onEvent(GattEvent.Ready(name, firmware)); false }
            next(g)
        }

        @Deprecated("Deprecated in API 33")
        override fun onCharacteristicRead(g: BluetoothGatt, c: BluetoothGattCharacteristic, status: Int) {
            @Suppress("DEPRECATION")
            onRead(g, c, c.value ?: ByteArray(0), status)
        }

        override fun onCharacteristicRead(g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray, status: Int) =
            onRead(g, c, value, status)

        private fun onRead(g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                when (c.uuid) {
                    GattIds.FIRMWARE_REVISION -> firmware = value.toString(Charsets.UTF_8).trim()
                    GattIds.BATTERY_LEVEL -> value.firstOrNull()?.let { onEvent(GattEvent.Battery(it.toInt() and 0xFF)) }
                }
            }
            next(g)
        }

        override fun onDescriptorWrite(g: BluetoothGatt, d: BluetoothGattDescriptor, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS && d.characteristic.uuid == GattIds.HEART_RATE_MEASUREMENT) {
                return onEvent(GattEvent.Lost("could not subscribe to heart rate"))
            }
            next(g)
        }

        @Deprecated("Deprecated in API 33")
        override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic) {
            @Suppress("DEPRECATION")
            onChanged(c, c.value ?: return)
        }

        override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray) =
            onChanged(c, value)

        private fun onChanged(c: BluetoothGattCharacteristic, value: ByteArray) {
            when (c.uuid) {
                GattIds.HEART_RATE_MEASUREMENT -> onEvent(GattEvent.Measurement(value.copyOf()))
                GattIds.BATTERY_LEVEL -> value.firstOrNull()?.let { onEvent(GattEvent.Battery(it.toInt() and 0xFF)) }
            }
        }
    }

    private fun subscribe(g: BluetoothGatt, c: BluetoothGattCharacteristic): Boolean {
        val cccd = c.getDescriptor(GattIds.CCCD) ?: return false
        if (!g.setCharacteristicNotification(c, true)) return false
        val value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            g.writeDescriptor(cccd, value) == BluetoothGatt.GATT_SUCCESS
        } else {
            @Suppress("DEPRECATION")
            cccd.value = value
            @Suppress("DEPRECATION")
            g.writeDescriptor(cccd)
        }
    }
}

data class BleDevice(val address: String, val name: String?, val rssi: Int, val heartRate: Boolean)

/**
 * Scans for nearby LE devices for a fixed time. Every named device is listed,
 * not only those advertising 0x180D, because many sensors put the service in
 * the scan response or not at all; heart-rate sensors are listed first.
 */
@SuppressLint("MissingPermission")
class BleScanner(private val context: Context) {
    fun scan(durationMs: Long, done: (Result<List<BleDevice>>) -> Unit) {
        // A failed scan reports early; the timer must not report a second time.
        var reported = false
        val onDone = { r: Result<List<BleDevice>> -> if (!reported) { reported = true; done(r) } }
        val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter
        if (adapter == null) return onDone(Result.failure(IllegalStateException("This device has no Bluetooth")))
        if (!adapter.isEnabled) return onDone(Result.failure(IllegalStateException("Bluetooth is off")))
        val scanner = adapter.bluetoothLeScanner
            ?: return onDone(Result.failure(IllegalStateException("Bluetooth LE scanning unavailable")))

        val found = linkedMapOf<String, BleDevice>()
        val hrUuid = ParcelUuid(GattIds.HEART_RATE_SERVICE)
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val name = result.scanRecord?.deviceName ?: try {
                    result.device.name
                } catch (_: SecurityException) {
                    null
                }
                val hr = result.scanRecord?.serviceUuids?.contains(hrUuid) == true
                if (name == null && !hr) return
                found[result.device.address] = BleDevice(result.device.address, name, result.rssi, hr)
            }

            override fun onScanFailed(errorCode: Int) {
                onDone(Result.failure(IllegalStateException("Scan failed ($errorCode)")))
            }
        }
        try {
            val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
            scanner.startScan(null, settings, callback)
        } catch (e: SecurityException) {
            return onDone(Result.failure(IllegalStateException("Bluetooth permission missing")))
        }
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                scanner.stopScan(callback)
            } catch (_: SecurityException) {
            }
            onDone(Result.success(found.values.sortedWith(compareBy({ !it.heartRate }, { -it.rssi }))))
        }, durationMs)
    }
}
