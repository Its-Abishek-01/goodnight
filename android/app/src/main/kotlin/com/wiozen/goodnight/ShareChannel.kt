package com.wiozen.goodnight

import android.app.Activity
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The native side of "Watch together" (`com.wiozen.goodnight/share`): the
 * foreground service, the phone's sound, and reactions shown over other apps.
 * The WebRTC call itself runs in Dart (flutter_webrtc).
 */
class ShareChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler { call, result ->
            val ctx = activity.applicationContext
            when (call.method) {
                "startService" -> {
                    ScreenShareService.start(ctx, call.argument<String>("partner") ?: "your partner")
                    result.success(null)
                }
                "stopService" -> {
                    ShareSound.stop()
                    ScreenShareService.stop(ctx)
                    result.success(null)
                }
                "startSound" -> result.success(ShareSound.start(ctx))
                "setMic" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    ShareSound.micOn = on
                    ScreenShareService.update(ctx, mic = on)
                    result.success(null)
                }
                "reaction" -> {
                    val emoji = call.argument<String>("emoji") ?: ""
                    BlockerService.instance?.showReaction(emoji)
                    ScreenShareService.update(ctx, latestReaction = emoji)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        // The notification's Mute and Stop buttons.
        ScreenShareService.onAction = { action ->
            main.post { channel.invokeMethod("action", action) }
        }
    }

    companion object {
        const val CHANNEL = "com.wiozen.goodnight/share"
    }
}
