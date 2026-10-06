package com.wiozen.goodnight

import java.time.LocalDateTime

/** Night-mode settings synced from the Flutter app (the approved bedtime). */
data class BlockConfig(
    val enabled: Boolean = false,
    val bedtimeMin: Int = 0,
    val wakeMin: Int = 0,
    val graceMs: Long = 5 * 60_000L,
    val blockMs: Long = 10 * 60_000L,
)

/** Running state of the grace and block timers for the current night. */
data class BlockState(
    var nightKey: String = "",
    var usedMs: Long = 0,
    var blockUntil: Long = 0,
    var blocks: Int = 0,
    var totalUsedMs: Long = 0,
    var lastTickAt: Long = 0,
    var lastOnTarget: Boolean = false,
    // The previous night's totals, kept so the app can still report them.
    var prevKey: String = "",
    var prevBlocks: Int = 0,
    var prevUsedMs: Long = 0,
)

sealed interface Decision {
    data object Allow : Decision
    data class Block(val remainingMs: Long) : Decision
}

/** Same night grouping as the Dart side: shift by 12 hours. */
fun nightKeyOf(now: LocalDateTime): String {
    val d = now.minusHours(12)
    return "%04d-%02d-%02d".format(d.year, d.monthValue, d.dayOfMonth)
}

/**
 * Grace and block rules. While a distracting target (Instagram, Chrome on
 * instagram.com, YouTube Shorts) is on screen at night, usage counts toward a
 * shared grace allowance. When it runs out the target is blocked for a fixed
 * time, after which a fresh grace allowance starts.
 */
object BlockEngine {
    /** Longest gap between ticks that still counts as continuous use. */
    const val MAX_GAP_MS = 30_000L

    fun isNight(c: BlockConfig, minuteOfDay: Int): Boolean {
        if (!c.enabled || c.bedtimeMin == c.wakeMin) return false
        return if (c.bedtimeMin < c.wakeMin) {
            minuteOfDay >= c.bedtimeMin && minuteOfDay < c.wakeMin
        } else {
            minuteOfDay >= c.bedtimeMin || minuteOfDay < c.wakeMin
        }
    }

    fun tick(
        c: BlockConfig,
        s: BlockState,
        nowMs: Long,
        minuteOfDay: Int,
        nightKey: String,
        onTarget: Boolean,
    ): Decision {
        if (s.nightKey != nightKey) {
            if (s.nightKey.isNotEmpty()) {
                s.prevKey = s.nightKey
                s.prevBlocks = s.blocks
                s.prevUsedMs = s.totalUsedMs
            }
            s.nightKey = nightKey
            s.usedMs = 0
            s.blockUntil = 0
            s.blocks = 0
            s.totalUsedMs = 0
        }

        if (!isNight(c, minuteOfDay)) {
            s.lastOnTarget = false
            s.lastTickAt = nowMs
            return Decision.Allow
        }

        if (nowMs < s.blockUntil) {
            s.lastOnTarget = false
            s.lastTickAt = nowMs
            return if (onTarget) Decision.Block(s.blockUntil - nowMs) else Decision.Allow
        }

        if (onTarget) {
            if (s.lastOnTarget && s.lastTickAt > 0) {
                val d = (nowMs - s.lastTickAt).coerceIn(0, MAX_GAP_MS)
                s.usedMs += d
                s.totalUsedMs += d
            }
            if (s.usedMs >= c.graceMs) {
                s.usedMs = 0
                s.blockUntil = nowMs + c.blockMs
                s.blocks++
                s.lastOnTarget = false
                s.lastTickAt = nowMs
                return Decision.Block(c.blockMs)
            }
        }
        s.lastOnTarget = onTarget
        s.lastTickAt = nowMs
        return Decision.Allow
    }
}
