package com.wiozen.goodnight

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.os.Build
import androidx.core.content.ContextCompat
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.audio.AudioProcessingAdapter
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Sends the phone's own sound (the video being watched) along with the
 * screen. WebRTC on Android has one audio input, the microphone, so this
 * records what the phone plays (Android 10+, from the same screen-capture
 * permission) and mixes it into the mic audio after WebRTC's voice
 * processing. "Mute mic" silences only the voice part.
 *
 * Apps that forbid capture (Netflix, Prime, Hotstar) are silent here, and
 * their picture is black too.
 */
object ShareSound : AudioProcessingAdapter.ExternalAudioFrameProcessing {
    private const val RATE = 48_000

    /** The sharer's voice. The phone's sound is always sent. */
    @Volatile
    var micOn = false

    private var record: AudioRecord? = null
    private var thread: Thread? = null

    @Volatile
    private var running = false
    private var registered = false

    private val ring = ShortArray(RATE) // one second
    private var readPos = 0.0
    private var writePos = 0
    private var count = 0
    private val lock = Any()

    /** Starts recording the phone's sound. False when it is not possible here. */
    fun start(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) return false
        val controller = try {
            FlutterWebRTCPlugin.sharedSingleton?.audioProcessingController
        } catch (_: Throwable) {
            null
        } ?: return false
        val projection = findProjection() ?: return false
        stopRecording()
        return try {
            val config = AudioPlaybackCaptureConfiguration.Builder(projection)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                .build()
            val format = AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(RATE)
                .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                .build()
            val min = AudioRecord.getMinBufferSize(RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
            val rec = AudioRecord.Builder()
                .setAudioFormat(format)
                .setBufferSizeInBytes(maxOf(min, RATE / 5 * 2))
                .setAudioPlaybackCaptureConfig(config)
                .build()
            rec.startRecording()
            record = rec
            synchronized(lock) {
                readPos = 0.0
                writePos = 0
                count = 0
            }
            running = true
            thread = Thread({ pump(rec) }, "goodnight-share-sound").apply { start() }
            if (!registered) {
                controller.capturePostProcessing.addProcessor(this)
                registered = true
            }
            true
        } catch (_: Throwable) {
            stopRecording()
            false
        }
    }

    fun stop() {
        stopRecording()
        micOn = false
        if (registered) {
            try {
                FlutterWebRTCPlugin.sharedSingleton?.audioProcessingController
                    ?.capturePostProcessing?.removeProcessor(this)
            } catch (_: Throwable) {
            }
            registered = false
        }
    }

    private fun stopRecording() {
        running = false
        thread?.join(500)
        thread = null
        try {
            record?.stop()
        } catch (_: Exception) {
        }
        record?.release()
        record = null
    }

    private fun pump(rec: AudioRecord) {
        val buf = ShortArray(RATE / 100)
        while (running) {
            val n = rec.read(buf, 0, buf.size)
            if (n <= 0) continue
            synchronized(lock) {
                for (i in 0 until n) {
                    ring[writePos] = buf[i]
                    writePos = (writePos + 1) % ring.size
                }
                count = minOf(ring.size, count + n)
                // Keep the delay short: drop the oldest audio beyond 200 ms.
                val keep = RATE / 5
                if (count > keep) {
                    readPos = ((writePos - keep + ring.size) % ring.size).toDouble()
                    count = keep
                }
            }
        }
    }

    override fun initialize(sampleRateHz: Int, numChannels: Int) {}

    override fun reset(newRate: Int) {}

    /**
     * Called by WebRTC for every 10 ms of microphone audio (float samples in
     * the 16-bit range). Mutes the voice if asked, then adds the phone's sound,
     * resampled to WebRTC's rate.
     */
    override fun process(numBands: Int, numFrames: Int, buffer: ByteBuffer) {
        val samples = buffer.order(ByteOrder.nativeOrder()).asFloatBuffer()
        val n = minOf(numFrames, samples.capacity())
        if (n <= 0) return
        val step = RATE.toDouble() / (n * 100)
        synchronized(lock) {
            for (i in 0 until n) {
                val voice = if (micOn) samples.get(i) else 0f
                var sound = 0f
                if (count > 0) {
                    sound = ring[readPos.toInt() % ring.size].toFloat()
                    val before = readPos.toInt()
                    readPos = (readPos + step) % ring.size
                    val used = (readPos.toInt() - before + ring.size) % ring.size
                    count = maxOf(0, count - used)
                }
                samples.put(i, (voice + sound).coerceIn(-32768f, 32767f))
            }
        }
    }

    /**
     * The MediaProjection that flutter_webrtc made for the screen. Android 14
     * allows one projection per permission, so the sound has to share it; the
     * plugin keeps it private (its ProGuard rules keep these names).
     */
    private fun findProjection(): MediaProjection? = try {
        val plugin = FlutterWebRTCPlugin.sharedSingleton
        val handler = plugin?.let { field(it, "methodCallHandler") }
        val media = handler?.let { field(it, "getUserMediaImpl") }
        val capturers = media?.let { field(it, "mVideoCapturers") } as? Map<*, *>
        capturers?.values?.firstNotNullOfOrNull { info ->
            info?.let { field(it, "capturer") }?.let { field(it, "mediaProjection") } as? MediaProjection
        }
    } catch (_: Throwable) {
        null
    }

    private fun field(o: Any, name: String): Any? {
        var c: Class<*>? = o.javaClass
        while (c != null) {
            try {
                val f = c.getDeclaredField(name)
                f.isAccessible = true
                return f.get(o)
            } catch (_: NoSuchFieldException) {
                c = c.superclass
            }
        }
        return null
    }
}
