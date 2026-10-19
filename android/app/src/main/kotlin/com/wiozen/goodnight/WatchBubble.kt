package com.wiozen.goodnight

/**
 * How the face on the watch bubble feels, from how much of the grace time
 * before the next pause is used up.
 */
enum class Mood {
    HAPPY, CURIOUS, WORRIED, SLEEPY, GRUMPY;

    companion object {
        fun of(usedMs: Long, graceMs: Long): Mood {
            if (graceMs <= 0) return GRUMPY
            val f = usedMs.toDouble() / graceMs
            return when {
                f < 0.25 -> HAPPY
                f < 0.5 -> CURIOUS
                f < 0.75 -> WORRIED
                f < 0.92 -> SLEEPY
                else -> GRUMPY
            }
        }

        /** Outside bedtime there is no pause to count down to, so the face follows the session length. */
        fun ofSession(watchedMs: Long): Mood {
            val min = watchedMs / 60_000
            return when {
                min < 10 -> HAPPY
                min < 20 -> CURIOUS
                min < 30 -> WORRIED
                min < 45 -> SLEEPY
                else -> GRUMPY
            }
        }
    }
}

/**
 * One sitting on Instagram/Shorts at any time of day. It ends after
 * [WatchSessions.END_GAP_MS] away, so a quick switch to another app does not
 * start the count again.
 */
data class WatchSession(
    var startedAt: Long = 0,
    var lastAt: Long = 0,
    var watchedMs: Long = 0,
    var reels: Int = 0,
    var lastOn: Boolean = false,
)

object WatchSessions {
    const val END_GAP_MS = 5 * 60_000L

    /** Call on every check; [lastAt] stays at the last moment on a target. */
    fun tick(s: WatchSession, nowMs: Long, onTarget: Boolean) {
        if (!onTarget) {
            s.lastOn = false
            return
        }
        if (s.startedAt == 0L || nowMs - s.lastAt > END_GAP_MS) {
            s.startedAt = nowMs
            s.watchedMs = 0
            s.reels = 0
            s.lastOn = false
        }
        if (s.lastOn) s.watchedMs += (nowMs - s.lastAt).coerceIn(0, BlockEngine.MAX_GAP_MS)
        s.lastAt = nowMs
        s.lastOn = true
    }

    fun addReel(s: WatchSession, nowMs: Long) {
        tick(s, nowMs, true)
        s.reels++
    }
}

/** What the reel counter remembers about the last scroll it saw. */
data class ReelTrack(
    var view: String = "",
    var index: Int = -1,
    var lastScrollAt: Long = 0,
    var lastCountAt: Long = 0,
)

/**
 * Counts reels from scroll events of the full-screen reel pager. When the
 * event carries the page index, a new index is a new reel. Without one, a
 * scroll that starts after a quiet gap is a new swipe.
 */
object ReelCounter {
    /** Swipes closer together than this are one swipe (a bounce or a peek). */
    const val MIN_GAP_MS = 400L

    /** Without an index, scroll events closer than this belong to one swipe. */
    const val QUIET_MS = 900L

    /** Returns true when this scroll moved to a new reel. */
    fun onScroll(t: ReelTrack, view: String, index: Int, nowMs: Long): Boolean {
        val quiet = nowMs - t.lastScrollAt
        t.lastScrollAt = nowMs
        val newReel = when {
            // The pager just appeared: the reel on screen is the first one.
            t.view != view -> true
            index >= 0 -> index != t.index
            else -> quiet >= QUIET_MS
        }
        t.view = view
        if (index >= 0) t.index = index
        if (!newReel || nowMs - t.lastCountAt < MIN_GAP_MS) return false
        t.lastCountAt = nowMs
        return true
    }
}

/** When the bubble last slid out, and what it showed then. Empty = never this session. */
data class BubbleMemory(
    val shownAt: Long = 0,
    val mood: Mood? = null,
    val reels: Int = 0,
)

/**
 * The bubble rests tucked into the screen edge with half the face peeking
 * out, and slides out by itself for a few seconds when something changes:
 * a new session, a new mood, every few reels, or after a while.
 */
object BubbleSchedule {
    const val SHOW_MS = 6_000L
    const val EVERY_REELS = 10
    const val EVERY_MS = 3 * 60_000L

    fun shouldShow(m: BubbleMemory, nowMs: Long, mood: Mood, reels: Int): Boolean = when {
        m.mood == null -> true
        mood != m.mood -> true
        reels / EVERY_REELS > m.reels / EVERY_REELS -> true
        else -> nowMs - m.shownAt >= EVERY_MS
    }

    fun shown(nowMs: Long, mood: Mood, reels: Int) = BubbleMemory(nowMs, mood, reels)

    fun visible(m: BubbleMemory, nowMs: Long) = m.mood != null && nowMs - m.shownAt < SHOW_MS

    /** "45s", "4 min", "1 h 05". */
    fun timeLabel(ms: Long): String {
        val s = ms / 1000
        return when {
            s < 60 -> "${s}s"
            s < 3600 -> "${s / 60} min"
            else -> "%d h %02d".format(s / 3600, (s % 3600) / 60)
        }
    }

    fun reelsLabel(n: Int) = if (n == 1) "1 reel" else "$n reels"
}
