package com.wiozen.goodnight

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Keeps screen sharing alive while the sharer is in another app. Android
 * needs a foreground service of type mediaProjection (and microphone, for the
 * voice) for as long as the screen is captured. Its notification has "Mute"
 * and "Stop" buttons, and shows the latest reaction from the viewer.
 */
class ScreenShareService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                onAction?.invoke("stop")
                return START_NOT_STICKY
            }
            ACTION_MIC -> {
                onAction?.invoke("mic")
                return START_NOT_STICKY
            }
        }
        partner = intent?.getStringExtra(EXTRA_PARTNER) ?: partner
        ensureChannel(this)
        val n = build(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            var types = ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && micGranted(this)) {
                types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            }
            startForeground(NOTIFICATION_ID, n, types)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
        return START_NOT_STICKY
    }

    companion object {
        private const val CHANNEL_ID = "goodnight_share"
        private const val NOTIFICATION_ID = 4711
        private const val ACTION_STOP = "com.wiozen.goodnight.share.STOP"
        private const val ACTION_MIC = "com.wiozen.goodnight.share.MIC"
        private const val EXTRA_PARTNER = "partner"

        /** "stop" or "mic", from the notification buttons. */
        var onAction: ((String) -> Unit)? = null

        private var partner = "your partner"
        private var micOn = false
        private var reaction: String? = null

        fun start(context: Context, partnerName: String) {
            micOn = false
            reaction = null
            val i = Intent(context, ScreenShareService::class.java).putExtra(EXTRA_PARTNER, partnerName)
            ContextCompat.startForegroundService(context, i)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ScreenShareService::class.java))
        }

        /** Refreshes the notification with the mic state and the latest reaction. */
        fun update(context: Context, mic: Boolean? = null, latestReaction: String? = null) {
            mic?.let { micOn = it }
            latestReaction?.let { reaction = it }
            try {
                (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                    .notify(NOTIFICATION_ID, build(context))
            } catch (_: Exception) {
            }
        }

        private fun micGranted(context: Context) =
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED

        private fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) != null) return
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Watch together", NotificationManager.IMPORTANCE_LOW)
                    .apply { description = "Shown while you share your screen with your partner." }
            )
        }

        private fun build(context: Context): Notification {
            fun action(action: String, code: Int) = PendingIntent.getService(
                context,
                code,
                Intent(context, ScreenShareService::class.java).setAction(action),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val text = reaction?.let { "${partner.replaceFirstChar { c -> c.uppercase() }} reacted $it" }
                ?: "Open any app or video. ${if (micOn) "Your mic is on." else "Your mic is off."}"
            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle("Sharing your screen with $partner")
                .setContentText(text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(open)
                .addAction(0, if (micOn) "Mute mic" else "Unmute mic", action(ACTION_MIC, 1))
                .addAction(0, "Stop sharing", action(ACTION_STOP, 2))
                .build()
        }
    }
}
