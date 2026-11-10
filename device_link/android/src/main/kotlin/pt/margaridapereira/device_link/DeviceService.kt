package pt.margaridapereira.device_link

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import pt.margaridapereira.device_link.protocol.DeviceMessage
import pt.margaridapereira.device_link.session.LinkState
import pt.margaridapereira.device_link.session.SessionEvent

/**
 * Foreground service that keeps the device session running while the app is in
 * the background (SRS-013, HAZ-006). The ongoing notification shows the link
 * state and the latest heart rate, so the user always knows whether they are
 * being monitored.
 */
class DeviceService : Service() {
    companion object {
        private const val CHANNEL_ID = "device_link"
        private const val NOTIFICATION_ID = 1
        private const val EXTRA_HOST = "host"
        private const val EXTRA_PORT = "port"
        private const val EXTRA_BLE_ADDRESS = "bleAddress"

        fun start(context: Context, host: String, port: Int) {
            val intent = Intent(context, DeviceService::class.java)
                .putExtra(EXTRA_HOST, host)
                .putExtra(EXTRA_PORT, port)
            context.startForegroundService(intent)
        }

        fun startBle(context: Context, address: String) {
            context.startForegroundService(Intent(context, DeviceService::class.java).putExtra(EXTRA_BLE_ADDRESS, address))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, DeviceService::class.java))
        }
    }

    private var linkText = "Connecting…"
    private var bpm: Int? = null
    private val listener: (SessionEvent) -> Unit = { event -> onSessionEvent(event) }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, buildNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, buildNotification())
        }
        val host = intent?.getStringExtra(EXTRA_HOST)
        val bleAddress = intent?.getStringExtra(EXTRA_BLE_ADDRESS)
        if (host != null || bleAddress != null) {
            DeviceHub.removeListener(listener)
            if (bleAddress != null) DeviceHub.connectBle(this, bleAddress)
            else DeviceHub.connect(host!!, intent.getIntExtra(EXTRA_PORT, 7878))
            DeviceHub.addListener(listener)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        DeviceHub.removeListener(listener)
        DeviceHub.disconnect()
        super.onDestroy()
    }

    private fun onSessionEvent(event: SessionEvent) {
        val changed = when (event) {
            is SessionEvent.Link -> {
                linkText = when (event.state) {
                    LinkState.CONNECTED -> "Device connected"
                    LinkState.CONNECTING -> "Connecting…"
                    LinkState.DISCONNECTED -> "Device link lost"
                }
                if (event.state != LinkState.CONNECTED) bpm = null
                true
            }
            is SessionEvent.Message -> (event.message as? DeviceMessage.HeartRate)?.let { bpm = it.bpm; true } ?: false
            else -> false
        }
        if (changed) getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, buildNotification())
    }

    private fun createChannel() {
        val channel = NotificationChannel(CHANNEL_ID, "Device monitoring", NotificationManager.IMPORTANCE_LOW)
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentTitle(linkText)
            .setContentText(bpm?.let { "Heart rate $it bpm" } ?: "Monitoring")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(launch)
            .build()
    }
}
