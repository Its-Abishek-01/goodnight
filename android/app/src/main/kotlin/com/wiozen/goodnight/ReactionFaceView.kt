package com.wiozen.goodnight

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.os.SystemClock
import android.view.View
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * The animated face on the watch bubble. Each [Mood] is a set of features
 * (eyes, brows, mouth, cheeks, extras). Changing mood morphs from one set to
 * the next with a little pop, and every mood has its own idle motion:
 * blinking, a sideways glance, a sweat drop, a yawn with floating z's, or a
 * grumpy huff.
 */
class ReactionFaceView(context: Context) : View(context) {
    private var from = looks.getValue(Mood.HAPPY)
    private var to = from
    private var changedAt = 0L
    private val startedAt = SystemClock.uptimeMillis()
    private val cur = FloatArray(N)

    var mood: Mood = Mood.HAPPY
        private set

    /**
     * Idle motion runs only while the bubble is out; tucked away the face
     * holds still so it costs no battery (vivo stops apps that draw a lot in
     * the background, and that also turns night mode off).
     */
    var animating = true
        set(value) {
            if (field == value) return
            field = value
            if (value) invalidate()
        }

    fun setMood(m: Mood) {
        if (m == mood) return
        from = Look(current().skin, cur.copyOf())
        to = looks.getValue(m)
        mood = m
        changedAt = SystemClock.uptimeMillis()
        invalidate()
    }

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        isFakeBoldText = true
        textAlign = Paint.Align.CENTER
    }
    private val path = Path()
    private val oval = RectF()

    /** Blends [from] into [to] and returns the look to draw now. */
    private fun current(): Look {
        val k = ease(((SystemClock.uptimeMillis() - changedAt) / MORPH_MS).coerceIn(0f, 1f))
        for (i in 0 until N) cur[i] = from.v[i] + (to.v[i] - from.v[i]) * k
        return Look(blend(from.skin, to.skin, k), cur)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val look = current()
        val v = look.v
        val now = SystemClock.uptimeMillis()
        val t = (now - startedAt) / 1000f
        val s = min(width, height).toFloat()
        if (s <= 0f) return
        val u = s * 0.4f

        // Idle motion: a slow bob, plus short huffs when grumpy.
        val bob = sin(t * 2f * PI.toFloat() / 2.6f) * s * 0.02f
        val huffOn = (t % 1.6f) < 0.5f
        val huff = if (huffOn) sin(t * 2f * PI.toFloat() * 7f) * v[SHAKE] else 0f
        val sinceChange = (now - changedAt).toFloat()
        val pop = if (sinceChange < POP_MS) 1f + 0.12f * sin(PI.toFloat() * sinceChange / POP_MS) else 1f

        canvas.save()
        canvas.translate(width / 2f + huff * s * 0.025f, height / 2f + bob)
        canvas.rotate(huff * 4f)
        canvas.scale(pop, pop)

        // Face and a soft highlight.
        fill.color = look.skin
        canvas.drawCircle(0f, 0f, u, fill)
        fill.color = Color.argb(60, 255, 255, 255)
        oval.set(-0.62f * u, -0.78f * u, -0.08f * u, -0.46f * u)
        canvas.drawOval(oval, fill)

        // Cheeks.
        if (v[BLUSH] > 0.01f) {
            fill.color = withAlpha(BLUSH_COLOR, 0.55f * v[BLUSH])
            oval.set(-0.76f * u, 0.08f * u, -0.40f * u, 0.30f * u)
            canvas.drawOval(oval, fill)
            oval.set(0.40f * u, 0.08f * u, 0.76f * u, 0.30f * u)
            canvas.drawOval(oval, fill)
        }

        drawEyes(canvas, v, t, u)
        drawBrows(canvas, v, u)
        drawMouth(canvas, v, t, u)
        if (v[SWEAT] > 0.01f) drawSweat(canvas, v[SWEAT], t, u)
        canvas.restore()

        // The z's float outside the face, so they are not scaled or shaken.
        if (v[ZZZ] > 0.01f) drawZzz(canvas, v[ZZZ], t, u)

        // Keep drawing while moving, and until a mood change has finished morphing.
        val morphing = now - changedAt < max(MORPH_MS, POP_MS)
        if (isAttachedToWindow && visibility == VISIBLE && (animating || morphing)) {
            postInvalidateOnAnimation()
        }
    }

    private fun drawEyes(canvas: Canvas, v: FloatArray, t: Float, u: Float) {
        // A quick blink every few seconds.
        val phase = t % 3.4f
        val blink = if (phase < 0.14f) 1f - sin(PI.toFloat() * phase / 0.14f) else 1f
        val open = v[EYE] * blink
        // A sideways glance that holds, then comes back.
        val p = (t % 3f) / 3f
        val g = when {
            p < 0.1f -> ease(p / 0.1f)
            p < 0.5f -> 1f
            p < 0.6f -> 1f - ease((p - 0.5f) / 0.1f)
            else -> 0f
        }
        val dx = v[LOOK] * g * 0.12f * u
        for (side in intArrayOf(-1, 1)) {
            val ex = side * 0.36f * u + dx
            val ey = -0.08f * u
            if (open > 0.2f) {
                val ry = max(0.15f * u * open, 0.03f * u)
                fill.color = INK
                oval.set(ex - 0.11f * u, ey - ry, ex + 0.11f * u, ey + ry)
                canvas.drawOval(oval, fill)
                if (open > 0.5f) {
                    fill.color = Color.WHITE
                    canvas.drawCircle(ex + 0.04f * u, ey - 0.05f * u * open, 0.035f * u, fill)
                }
            } else {
                // Closed, sleepy eyes.
                line.color = INK
                line.strokeWidth = 0.06f * u
                path.reset()
                path.moveTo(ex - 0.12f * u, ey)
                path.quadTo(ex, ey + 0.1f * u, ex + 0.12f * u, ey)
                canvas.drawPath(path, line)
            }
        }
    }

    private fun drawBrows(canvas: Canvas, v: FloatArray, u: Float) {
        if (v[BROW_A] < 0.01f) return
        line.color = withAlpha(INK, v[BROW_A])
        line.strokeWidth = 0.06f * u
        val tilt = v[BROW] * 0.1f * u
        canvas.drawLine(-0.52f * u, -0.40f * u, -0.20f * u, -0.40f * u + tilt, line)
        val lift = v[RAISE] * 0.12f * u
        canvas.drawLine(0.20f * u, -0.40f * u + tilt - lift, 0.52f * u, -0.40f * u - lift * 1.4f, line)
    }

    private fun drawMouth(canvas: Canvas, v: FloatArray, t: Float, u: Float) {
        val my = 0.38f * u
        val smile = v[SMILE]
        val yawn = v[YAWN]
        if (yawn < 0.99f) {
            val keep = 1f - yawn
            val w = 0.26f * u
            val y0 = my - smile * 0.04f * u
            path.reset()
            path.moveTo(-w, y0)
            path.quadTo(0f, my + smile * 0.2f * u, w, y0)
            if (v[OPEN] > 0.03f) {
                // An open smile with a little tongue.
                path.reset()
                path.moveTo(-w, y0)
                path.quadTo(0f, my + smile * 0.06f * u, w, y0)
                path.quadTo(0f, my + smile * 0.2f * u + v[OPEN] * 0.3f * u, -w, y0)
                path.close()
                fill.color = withAlpha(INK, keep)
                canvas.drawPath(path, fill)
                canvas.save()
                canvas.clipPath(path)
                fill.color = withAlpha(TONGUE, keep)
                canvas.drawCircle(0f, my + smile * 0.2f * u + v[OPEN] * 0.24f * u, 0.13f * u, fill)
                canvas.restore()
            } else {
                line.color = withAlpha(INK, keep)
                line.strokeWidth = 0.065f * u
                canvas.drawPath(path, line)
            }
        }
        if (yawn > 0.01f) {
            // A slow yawn that opens and closes.
            val cycle = sin(PI.toFloat() * ((t % 3.2f) / 3.2f))
            val o = 0.35f + 0.65f * cycle * cycle
            val rx = 0.13f * u * (0.6f + 0.4f * o)
            val ry = 0.2f * u * o + 0.03f * u
            fill.color = withAlpha(INK, yawn)
            oval.set(-rx, my + 0.02f * u - ry, rx, my + 0.02f * u + ry)
            canvas.drawOval(oval, fill)
        }
    }

    private fun drawSweat(canvas: Canvas, a: Float, t: Float, u: Float) {
        val p = (t % 1.8f) / 1.8f
        val x = 0.66f * u
        val y = -0.42f * u + p * 0.28f * u
        val fade = if (p > 0.7f) 1f - (p - 0.7f) / 0.3f else 1f
        fill.color = withAlpha(SWEAT_COLOR, a * fade)
        path.reset()
        path.moveTo(x, y - 0.16f * u)
        path.quadTo(x + 0.13f * u, y + 0.02f * u, x, y + 0.09f * u)
        path.quadTo(x - 0.13f * u, y + 0.02f * u, x, y - 0.16f * u)
        path.close()
        canvas.drawPath(path, fill)
    }

    private fun drawZzz(canvas: Canvas, a: Float, t: Float, u: Float) {
        val cx = width / 2f
        val cy = height / 2f
        for (i in 0 until 2) {
            val p = ((t / 2.4f) + i * 0.5f) % 1f
            val fade = sin(PI.toFloat() * p)
            text.textSize = u * (0.28f + 0.12f * p)
            text.color = withAlpha(ZZZ_COLOR, a * fade)
            canvas.drawText("z", cx + (0.62f + 0.3f * p) * u, cy + (-0.5f - 0.55f * p) * u, text)
        }
    }

    private class Look(val skin: Int, val v: FloatArray)

    companion object {
        private const val MORPH_MS = 450f
        private const val POP_MS = 350f

        // Indexes into a look's feature values.
        private const val EYE = 0 // 1 open, 0 closed
        private const val LOOK = 1 // sideways glance
        private const val BROW = 2 // 1 angry, -1 worried
        private const val BROW_A = 3 // brows shown
        private const val RAISE = 4 // one brow raised
        private const val SMILE = 5 // 1 smile, -1 frown
        private const val OPEN = 6 // open smile
        private const val BLUSH = 7
        private const val SWEAT = 8
        private const val ZZZ = 9
        private const val SHAKE = 10
        private const val YAWN = 11
        private const val N = 12

        private const val INK = 0xFF3B2A20.toInt()
        private const val TONGUE = 0xFFFF8A9A.toInt()
        private const val BLUSH_COLOR = 0xFFFF8FA3.toInt()
        private const val SWEAT_COLOR = 0xFF8EC9FF.toInt()
        private const val ZZZ_COLOR = 0xFFE6E0FF.toInt()

        private fun look(skin: Long, vararg v: Float) = Look(skin.toInt(), v)

        private val looks = mapOf(
            //                                eye look brow browA raise smile open blush sweat zzz shake yawn
            Mood.HAPPY to look(0xFFFFD166, 1f, 0f, 0f, 0f, 0f, 1f, 0.35f, 1f, 0f, 0f, 0f, 0f),
            Mood.CURIOUS to look(0xFFFFD166, 0.8f, 1f, 0f, 1f, 1f, 0.1f, 0f, 0.3f, 0f, 0f, 0f, 0f),
            Mood.WORRIED to look(0xFFFFD166, 1f, 0f, -1f, 1f, 0f, -0.45f, 0f, 0f, 1f, 0f, 0f, 0f),
            Mood.SLEEPY to look(0xFFFFE3A3, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0.4f, 0f, 1f, 0f, 1f),
            Mood.GRUMPY to look(0xFFFF9F80, 0.75f, 0f, 1f, 1f, 0f, -1f, 0f, 0f, 0f, 0f, 1f, 0f),
        )

        private fun ease(x: Float) = x * x * (3f - 2f * x)

        private fun withAlpha(c: Int, a: Float) =
            (c and 0x00FFFFFF) or ((a.coerceIn(0f, 1f) * Color.alpha(c)).toInt() shl 24)

        private fun blend(a: Int, b: Int, k: Float): Int {
            fun ch(x: Int, y: Int) = (x + (y - x) * k).toInt()
            return Color.argb(
                ch(Color.alpha(a), Color.alpha(b)),
                ch(Color.red(a), Color.red(b)),
                ch(Color.green(a), Color.green(b)),
                ch(Color.blue(a), Color.blue(b)),
            )
        }
    }
}
