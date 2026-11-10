package pt.margaridapereira.device_link

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import pt.margaridapereira.device_link.ble.AndroidGattLink
import pt.margaridapereira.device_link.ble.BleHeartRateSession
import pt.margaridapereira.device_link.protocol.DeviceMessage
import pt.margaridapereira.device_link.session.DeviceConnection
import pt.margaridapereira.device_link.session.DeviceSession
import pt.margaridapereira.device_link.session.FirmwareUpdater
import pt.margaridapereira.device_link.session.LinkState
import pt.margaridapereira.device_link.session.SessionEvent
import pt.margaridapereira.device_link.transport.TcpTransport
import java.util.concurrent.CopyOnWriteArraySet

/**
 * Process-wide owner of the device session. It lives as long as the process,
 * which the foreground service keeps alive, so recording survives the Flutter
 * UI being closed (SRS-013). The UI attaches and detaches as a listener.
 */
object DeviceHub {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val listeners = CopyOnWriteArraySet<(SessionEvent) -> Unit>()
    private var session: DeviceConnection? = null

    // Last known state, replayed to a listener that attaches later.
    @Volatile var link: SessionEvent.Link = SessionEvent.Link(LinkState.DISCONNECTED)
        private set
    @Volatile var hello: DeviceMessage.Hello? = null
        private set
    @Volatile var battery: DeviceMessage.Battery? = null
        private set
    @Volatile var streaming = false
        private set
    private var updater: FirmwareUpdater? = null

    @Synchronized
    fun connect(host: String, port: Int) = replace(DeviceSession({ TcpTransport(host, port) }, scope, ::dispatch))

    /** A standard Bluetooth LE heart-rate sensor. */
    @Synchronized
    fun connectBle(context: Context, address: String) {
        val app = context.applicationContext
        replace(BleHeartRateSession(address, { AndroidGattLink(app, address) }, scope, ::dispatch))
    }

    /**
     * Starts a firmware update on the connected ECG device. Returns why it
     * cannot start, or null. Bluetooth heart-rate sensors are updated by their
     * maker's app, not here.
     */
    @Synchronized
    fun updateFirmware(image: ByteArray, version: String): String? {
        val tcp = session as? DeviceSession ?: return "connect to the ECG device first"
        if (streaming) return "stop the recording first"
        if (updater?.finished == false) return "an update is already running"
        updater = FirmwareUpdater(image, version, tcp::send, scope, { dispatch(SessionEvent.Firmware(it)) })
            .also { it.start(link.state == LinkState.CONNECTED) }
        return null
    }

    @Synchronized
    fun cancelFirmware() {
        updater?.cancel()
    }

    private fun replace(next: DeviceConnection) {
        updater?.cancel()
        session?.stop()
        hello = null
        battery = null
        session = next.also {
            it.start()
            if (streaming) it.startStreaming()
        }
    }

    @Synchronized
    fun disconnect() {
        updater?.cancel()
        session?.stop()
        session = null
        streaming = false
        dispatch(SessionEvent.Link(LinkState.DISCONNECTED, "disconnected by user"))
    }

    fun startStreaming() {
        streaming = true
        session?.startStreaming()
    }

    fun stopStreaming() {
        streaming = false
        session?.stopStreaming()
    }

    fun addListener(listener: (SessionEvent) -> Unit) {
        listener(link)
        hello?.let { listener(SessionEvent.Message(it)) }
        battery?.let { listener(SessionEvent.Message(it)) }
        listeners += listener
    }

    fun removeListener(listener: (SessionEvent) -> Unit) {
        listeners -= listener
    }

    private fun dispatch(event: SessionEvent) {
        if (event is SessionEvent.Link || event is SessionEvent.Message) updater?.onEvent(event)
        when (event) {
            is SessionEvent.Link -> link = event
            is SessionEvent.Message -> when (val m = event.message) {
                is DeviceMessage.Hello -> hello = m
                is DeviceMessage.Battery -> battery = m
                else -> Unit
            }
            else -> Unit
        }
        listeners.forEach { it(event) }
    }
}
