package com.wiozen.goodnight

import android.app.Activity
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Wake-up sounds (lib/features/alarm/wake_sound.dart): previewing a sound,
 * recording a voice note for the partner, and picking one of the phone's own
 * alarm sounds, which is copied into the app so the alarm can play it.
 */
class SoundChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private var player: MediaPlayer? = null
    private var recorder: MediaRecorder? = null
    private var recordingPath: String? = null
    private var pickResult: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "preview" -> {
                        val asset = call.argument<String>("asset")
                        val path = call.argument<String>("path") ?: asset?.let { assetToFile(it) }
                        if (path == null) result.success(false) else {
                            play(path)
                            result.success(true)
                        }
                    }
                    "stopPreview" -> {
                        stopPlayer()
                        result.success(null)
                    }
                    "startRecording" -> result.success(startRecording(call.argument<String>("path")!!))
                    "stopRecording" -> result.success(stopRecording())
                    "pickPhoneSound" -> {
                        pickResult?.success(null)
                        pickResult = result
                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
                            .putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                            .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                            .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                            .putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Wake-up sound")
                        activity.startActivityForResult(intent, PICK_REQUEST)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("sound", e.message, null)
            }
        }
    }

    /** From MainActivity.onActivityResult. Returns true when it was ours. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_REQUEST) return false
        val result = pickResult ?: return true
        pickResult = null
        @Suppress("DEPRECATION")
        val uri: Uri? = if (resultCode == Activity.RESULT_OK) {
            data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        } else {
            null
        }
        if (uri == null) {
            result.success(null)
            return true
        }
        try {
            val title = RingtoneManager.getRingtone(activity, uri)?.getTitle(activity) ?: "Phone sound"
            // A copy inside the app, so the alarm can play it without storage permission.
            val file = File(activity.filesDir, "wake_phone_sound")
            activity.contentResolver.openInputStream(uri)?.use { input ->
                file.outputStream().use { input.copyTo(it) }
            } ?: throw IllegalStateException("Could not read that sound")
            result.success(mapOf("path" to file.absolutePath, "title" to title))
        } catch (e: Exception) {
            result.error("sound", e.message, null)
        }
        return true
    }

    /** Flutter assets are inside the APK; MediaPlayer needs a real file. */
    private fun assetToFile(asset: String): String {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        val file = File(activity.cacheDir, "preview_" + asset.substringAfterLast('/'))
        if (!file.exists()) {
            activity.assets.open(key).use { input -> file.outputStream().use { input.copyTo(it) } }
        }
        return file.absolutePath
    }

    private fun play(path: String) {
        stopPlayer()
        player = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            setDataSource(path)
            setOnCompletionListener { stopPlayer() }
            prepare()
            start()
        }
    }

    private fun stopPlayer() {
        player?.let {
            try {
                it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        player = null
    }

    private fun startRecording(path: String): Boolean {
        stopPlayer()
        stopRecording()
        val r = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) MediaRecorder(activity) else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        r.setAudioSource(MediaRecorder.AudioSource.MIC)
        r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        r.setAudioChannels(1)
        r.setAudioSamplingRate(44_100)
        r.setAudioEncodingBitRate(64_000)
        r.setMaxDuration(MAX_RECORD_MS)
        r.setOutputFile(path)
        r.prepare()
        r.start()
        recorder = r
        recordingPath = path
        return true
    }

    /** Stops the recording; returns its path, or null if nothing was recorded. */
    private fun stopRecording(): String? {
        val r = recorder ?: return null
        recorder = null
        return try {
            r.stop()
            recordingPath
        } catch (_: Exception) {
            null // stopped before any audio was captured
        } finally {
            r.release()
        }
    }

    fun dispose() {
        stopPlayer()
        stopRecording()
    }

    companion object {
        const val CHANNEL = "com.wiozen.goodnight/sound"
        const val MAX_RECORD_MS = 15_000
        private const val PICK_REQUEST = 4201
    }
}
