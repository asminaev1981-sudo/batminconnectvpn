package pro.batmin.connect

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import androidx.core.app.NotificationCompat

class BatminVpnService : VpnService() {
    enum class State { STOPPED, STARTING, READY, STOPPING, ERROR }

    companion object {
        const val ACTION_START = "pro.batmin.connect.action.START"
        const val ACTION_STOP = "pro.batmin.connect.action.STOP"
        const val EXTRA_PROFILE_JSON = "profileJson"
        private const val CHANNEL_ID = "batmin_connect_vpn"
        private const val NOTIFICATION_ID = 4601

        @Volatile var currentState: State = State.STOPPED
            private set
        @Volatile var currentMessage: String = "VPN-служба остановлена"
            private set
        @Volatile var engineAvailable: Boolean = false
            private set
    }

    private lateinit var tunnelController: TunnelController

    override fun onCreate() {
        super.onCreate()
        tunnelController = TunnelController(this)
        engineAvailable = tunnelController.engineAvailable
        VpnLog.add("BatminVpnService created; engineAvailable=$engineAvailable")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopTunnel()
            ACTION_START -> startTunnel(intent.getStringExtra(EXTRA_PROFILE_JSON).orEmpty())
            else -> setError("Неизвестная команда VPN-службы")
        }
        return START_NOT_STICKY
    }

    private fun startTunnel(profileJson: String) {
        currentState = State.STARTING
        currentMessage = "Проверка профиля и запуск VPN-ядра"
        VpnLog.add(currentMessage)
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification(currentMessage))

        val result = tunnelController.start(profileJson)
        engineAvailable = tunnelController.engineAvailable
        if (result.success) {
            currentState = State.READY
            currentMessage = result.message
            VpnLog.add("READY: ${result.message}")
            updateNotification(result.message)
        } else {
            setError(result.message)
        }
    }

    private fun setError(message: String) {
        currentState = State.ERROR
        currentMessage = message
        VpnLog.add("ERROR: $message")
        createNotificationChannel()
        updateNotification(message)
    }

    private fun stopTunnel() {
        currentState = State.STOPPING
        currentMessage = "Остановка VPN-ядра"
        VpnLog.add(currentMessage)
        tunnelController.stop()
        currentState = State.STOPPED
        currentMessage = "VPN-служба остановлена"
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onRevoke() {
        VpnLog.add("Android revoked VPN permission")
        stopTunnel()
        super.onRevoke()
    }

    override fun onDestroy() {
        if (::tunnelController.isInitialized) tunnelController.stop()
        currentState = State.STOPPED
        currentMessage = "VPN-служба остановлена"
        VpnLog.add("BatminVpnService destroyed")
        super.onDestroy()
    }

    private fun updateNotification(text: String) {
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun buildNotification(text: String): Notification {
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("Batmin Connect")
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setOngoing(currentState == State.STARTING || currentState == State.READY)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Batmin Connect VPN", NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }
}
