package com.wiozen.goodnight

import android.accessibilityservice.AccessibilityService
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

/**
 * The watch bubble: a small pill docked to the right edge over Instagram and
 * Shorts at night, with the reaction face, tonight's time and reels. It rests
 * tucked away with half the face peeking out and slides out by itself when
 * [BubbleSchedule] says so, or when tapped. It can be dragged up and down.
 */
class WatchBubbleOverlay(
    private val service: AccessibilityService,
    private val store: BlockerStore,
) {
    private val wm = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private val dp = service.resources.displayMetrics.density

    private var root: LinearLayout? = null
    private var lp: WindowManager.LayoutParams? = null
    private lateinit var face: ReactionFaceView
    private lateinit var time: TextView
    private lateinit var reels: TextView

    private var memory = BubbleMemory()
    private var out = false
    private var anim: ValueAnimator? = null

    private val tuck = Runnable { slide(false) }

    /** True while [preview] runs; the service leaves the bubble alone meanwhile. */
    var previewing = false
        private set

    /** Shows or refreshes the bubble with tonight's numbers. */
    fun update(usedMs: Long, reelCount: Int, mood: Mood) {
        if (root == null && !attach()) return
        time.text = BubbleSchedule.timeLabel(usedMs)
        reels.text = BubbleSchedule.reelsLabel(reelCount)
        face.setMood(mood)
        val now = System.currentTimeMillis()
        if (BubbleSchedule.shouldShow(memory, now, mood, reelCount)) {
            memory = BubbleSchedule.shown(now, mood, reelCount)
            peekOut()
        }
    }

    /**
     * Shows the bubble over whatever is on screen for a few seconds, going
     * through every mood with made-up numbers, then tucks it away and removes it.
     */
    fun preview(): Boolean {
        remove()
        if (!attach()) return false
        previewing = true
        val steps = listOf(
            Triple(Mood.HAPPY, 45_000L, 3),
            Triple(Mood.CURIOUS, 4 * 60_000L, 17),
            Triple(Mood.WORRIED, 9 * 60_000L, 34),
            Triple(Mood.SLEEPY, 14 * 60_000L, 52),
            Triple(Mood.GRUMPY, 21 * 60_000L, 76),
        )
        steps.forEachIndexed { i, (mood, ms, n) ->
            handler.postDelayed({
                time.text = BubbleSchedule.timeLabel(ms)
                reels.text = BubbleSchedule.reelsLabel(n)
                face.setMood(mood)
                if (i == 0) slide(true)
            }, i * PREVIEW_STEP_MS)
        }
        val end = steps.size * PREVIEW_STEP_MS
        handler.postDelayed({ slide(false) }, end)
        handler.postDelayed({ remove() }, end + 2_500)
        return true
    }

    fun remove() {
        previewing = false
        // Clears the tuck timer and any preview steps.
        handler.removeCallbacksAndMessages(null)
        anim?.cancel()
        anim = null
        memory = BubbleMemory()
        out = false
        val v = root ?: return
        root = null
        lp = null
        try {
            wm.removeView(v)
        } catch (_: Exception) {
        }
    }

    private fun peekOut() {
        slide(true)
        handler.removeCallbacks(tuck)
        handler.postDelayed(tuck, BubbleSchedule.SHOW_MS)
    }

    private fun onTap() {
        if (out) {
            handler.removeCallbacks(tuck)
            slide(false)
        } else {
            memory = memory.copy(shownAt = System.currentTimeMillis())
            peekOut()
        }
    }

    private fun attach(): Boolean {
        face = ReactionFaceView(service)
        time = TextView(service).apply {
            textSize = 15f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(0xFFFFFFFF.toInt())
            includeFontPadding = false
        }
        reels = TextView(service).apply {
            textSize = 12f
            setTextColor(0xFFCFCBF6.toInt())
            includeFontPadding = false
            setPadding(0, (3 * dp).toInt(), 0, 0)
        }
        val texts = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            addView(time)
            addView(reels)
        }
        val radius = 30 * dp
        val pill = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = GradientDrawable().apply {
                setColor(0xE61C1A3A.toInt())
                setStroke(dp.toInt().coerceAtLeast(1), 0x33FFFFFF)
                // Rounded on the left, flush with the screen edge on the right.
                cornerRadii = floatArrayOf(radius, radius, 0f, 0f, 0f, 0f, radius, radius)
            }
            setPadding((6 * dp).toInt(), (6 * dp).toInt(), (18 * dp).toInt(), (6 * dp).toInt())
            alpha = TUCKED_ALPHA
            val size = (FACE_DP * dp).toInt()
            addView(face, LinearLayout.LayoutParams(size, size))
            addView(texts, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { marginStart = (10 * dp).toInt() })
            minimumWidth = (140 * dp).toInt()
        }
        val screenH = service.resources.displayMetrics.heightPixels
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            y = (store.bubbleY() * screenH).toInt()
            // Start fully off the edge; the first slide brings it in.
            x = -(400 * dp).toInt()
        }
        pill.setOnTouchListener(DragOrTap(params, screenH))
        return try {
            wm.addView(pill, params)
            root = pill
            lp = params
            true
        } catch (_: Exception) {
            false
        }
    }

    /** Slides the pill out (fully visible) or tucks it back with half the face showing. */
    private fun slide(show: Boolean) {
        val v = root ?: return
        val params = lp ?: return
        if (v.width == 0) {
            v.post { slide(show) }
            return
        }
        out = show
        face.animating = show
        val peek = ((6 + FACE_DP / 2 + 2) * dp).toInt()
        val target = if (show) 0 else -(v.width - peek)
        val fromX = params.x
        val fromAlpha = v.alpha
        // Tucked away it is see-through, so it does not get in the way.
        val toAlpha = if (show) 1f else TUCKED_ALPHA
        anim?.cancel()
        anim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = if (show) 420 else 360
            interpolator = if (show) OvershootInterpolator(1.2f) else DecelerateInterpolator()
            addUpdateListener {
                if (root !== v) return@addUpdateListener
                val k = it.animatedValue as Float
                params.x = fromX + ((target - fromX) * k).toInt()
                v.alpha = fromAlpha + (toAlpha - fromAlpha) * k.coerceIn(0f, 1f)
                try {
                    wm.updateViewLayout(v, params)
                } catch (_: Exception) {
                }
            }
            start()
        }
    }

    /** Drag to move the bubble up or down; a tap without moving slides it out or in. */
    private inner class DragOrTap(
        private val params: WindowManager.LayoutParams,
        private val screenH: Int,
    ) : android.view.View.OnTouchListener {
        private val slop = ViewConfiguration.get(service).scaledTouchSlop
        private var downY = 0f
        private var startY = 0
        private var dragging = false

        override fun onTouch(v: android.view.View, e: MotionEvent): Boolean {
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downY = e.rawY
                    startY = params.y
                    dragging = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = e.rawY - downY
                    if (!dragging && abs(dy) > slop) dragging = true
                    if (dragging) {
                        params.y = (startY + dy).toInt().coerceIn(0, (screenH - v.height).coerceAtLeast(0))
                        try {
                            wm.updateViewLayout(v, params)
                        } catch (_: Exception) {
                        }
                    }
                }
                MotionEvent.ACTION_UP -> {
                    if (dragging) {
                        store.saveBubbleY(params.y.toFloat() / screenH)
                    } else {
                        v.performClick()
                        onTap()
                    }
                }
            }
            return true
        }
    }

    companion object {
        private const val FACE_DP = 44
        private const val TUCKED_ALPHA = 0.4f
        private const val PREVIEW_STEP_MS = 2_200L
    }
}
