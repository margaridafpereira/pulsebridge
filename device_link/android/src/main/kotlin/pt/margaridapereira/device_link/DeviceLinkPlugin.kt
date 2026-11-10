package pt.margaridapereira.device_link

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import pt.margaridapereira.device_link.ble.BleScanner
import pt.margaridapereira.device_link.protocol.DeviceMessage
import pt.margaridapereira.device_link.session.SessionEvent
import pt.margaridapereira.device_link.storage.SecureStore
import java.io.File
import java.util.concurrent.Executors

/**
 * Bridges DeviceHub to Flutter: commands over a MethodChannel, device events
 * over an EventChannel. Events are converted to plain maps here so the Dart side
 * stays independent of the Kotlin types.
 */
class DeviceLinkPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ActivityAware {
    private lateinit var context: Context
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())
    private val listener: (SessionEvent) -> Unit = { event ->
        toMap(event)?.let { map -> main.post { sink?.success(map) } }
    }

    private lateinit var storeChannel: MethodChannel
    private val storeExecutor = Executors.newSingleThreadExecutor()
    private val store by lazy { SecureStore(File(context.filesDir, "secure")) { SecureStore.keystoreKey() } }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "pt.margaridapereira.device_link/methods")
        events = EventChannel(binding.binaryMessenger, "pt.margaridapereira.device_link/events")
        storeChannel = MethodChannel(binding.binaryMessenger, "pt.margaridapereira.device_link/store")
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
        storeChannel.setMethodCallHandler(::onStoreCall)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        storeChannel.setMethodCallHandler(null)
        DeviceHub.removeListener(listener)
    }

    /** Encryption and file I/O run off the main thread; results are posted back to it. */
    private fun onStoreCall(call: MethodCall, result: MethodChannel.Result) {
        storeExecutor.execute {
            try {
                val value: Any? = when (call.method) {
                    "write" -> store.write(call.argument("name")!!, call.argument<ByteArray>("data")!!).let { null }
                    "read" -> store.read(call.argument("name")!!)
                    "list" -> store.list(call.argument<String>("prefix") ?: "")
                    "delete" -> store.delete(call.argument("name")!!)
                    else -> {
                        main.post { result.notImplemented() }
                        return@execute
                    }
                }
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("store_error", e.message, null) }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                requestNotificationPermission()
                DeviceService.start(context, call.argument<String>("host")!!, call.argument<Int>("port")!!)
                result.success(null)
            }
            "disconnect" -> {
                DeviceService.stop(context)
                result.success(null)
            }
            "startStreaming" -> {
                DeviceHub.startStreaming()
                result.success(null)
            }
            "stopStreaming" -> {
                DeviceHub.stopStreaming()
                result.success(null)
            }
            "isStreaming" -> result.success(DeviceHub.streaming)
            "updateFirmware" -> {
                val problem = DeviceHub.updateFirmware(call.argument<ByteArray>("image")!!, call.argument<String>("version")!!)
                if (problem == null) result.success(null) else result.error("firmware", problem, null)
            }
            "cancelFirmware" -> {
                DeviceHub.cancelFirmware()
                result.success(null)
            }
            "bluetoothState" -> result.success(bluetoothState())
            "requestBluetoothPermissions" -> requestBluetoothPermissions(result)
            "scanBle" -> {
                if (!hasBluetoothPermissions()) return result.error("permission", "Bluetooth permission missing", null)
                BleScanner(context).scan(call.argument<Int>("durationMs")?.toLong() ?: 6_000) { r ->
                    r.fold(
                        { list ->
                            result.success(list.map {
                                mapOf("address" to it.address, "name" to it.name, "rssi" to it.rssi, "heartRate" to it.heartRate)
                            })
                        },
                        { e -> result.error("scan", e.message, null) },
                    )
                }
            }
            "connectBle" -> {
                if (!hasBluetoothPermissions()) return result.error("permission", "Bluetooth permission missing", null)
                requestNotificationPermission()
                DeviceService.startBle(context, call.argument<String>("address")!!)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        DeviceHub.addListener(listener)
    }

    override fun onCancel(arguments: Any?) {
        DeviceHub.removeListener(listener)
        sink = null
    }

    private val bluetoothPermissions: Array<String>
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private fun hasBluetoothPermissions() =
        bluetoothPermissions.all { context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }

    private fun bluetoothState(): Map<String, Boolean> {
        val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter
        return mapOf(
            "supported" to (adapter != null && context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)),
            "enabled" to (adapter?.isEnabled == true),
            "permitted" to hasBluetoothPermissions(),
        )
    }

    private fun requestBluetoothPermissions(result: MethodChannel.Result) {
        val activity = activity
        if (hasBluetoothPermissions()) return result.success(true)
        if (activity == null || pendingPermission != null) return result.success(false)
        pendingPermission = result
        activity.requestPermissions(bluetoothPermissions, BLUETOOTH_REQUEST)
    }

    private val permissionListener = PluginRegistry.RequestPermissionsResultListener { code, _, grants ->
        if (code != BLUETOOTH_REQUEST) return@RequestPermissionsResultListener false
        pendingPermission?.success(grants.isNotEmpty() && grants.all { it == PackageManager.PERMISSION_GRANTED })
        pendingPermission = null
        true
    }

    private fun requestNotificationPermission() {
        val activity = activity ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 0)
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(permissionListener)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(permissionListener)
        activityBinding = null
        activity = null
    }

    companion object {
        private const val BLUETOOTH_REQUEST = 7301

        internal fun toMap(event: SessionEvent): Map<String, Any?>? = when (event) {
            is SessionEvent.Link -> mapOf("type" to "link", "state" to event.state.name.lowercase(), "reason" to event.reason)
            is SessionEvent.Gap -> mapOf("type" to "gap", "fromIndex" to event.fromIndex, "lostSamples" to event.lostSamples)
            is SessionEvent.Stats -> mapOf(
                "type" to "stats", "crcErrors" to event.crcErrors, "skippedBytes" to event.skippedBytes,
                "lostFrames" to event.lostFrames, "lostSamples" to event.lostSamples,
            )
            is SessionEvent.Firmware -> mapOf(
                "type" to "firmware",
                "stage" to event.progress.stage.name.lowercase(),
                "sent" to event.progress.sent,
                "total" to event.progress.total,
                "detail" to event.progress.detail,
            )
            is SessionEvent.Message -> when (val m = event.message) {
                is DeviceMessage.Hello -> mapOf(
                    "type" to "hello", "deviceId" to m.deviceId, "firmware" to m.firmware, "sampleRate" to m.sampleRate,
                )
                is DeviceMessage.EcgSamples -> mapOf("type" to "ecg", "firstIndex" to m.firstIndex, "samples" to m.samplesUv)
                is DeviceMessage.HeartRate -> mapOf("type" to "heartRate", "bpm" to m.bpm, "rrMs" to m.rrMs)
                is DeviceMessage.Battery -> mapOf("type" to "battery", "percent" to m.percent)
                is DeviceMessage.Alarm -> mapOf("type" to "alarm", "code" to m.code.name, "active" to m.active)
                is DeviceMessage.Ack -> mapOf("type" to "ack", "ackedSeq" to m.ackedSeq, "result" to m.result.name)
                is DeviceMessage.FirmwareStatus, is DeviceMessage.Unknown -> null
            }
        }
    }
}
