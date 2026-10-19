package com.wiozen.goodnight

import java.time.LocalDateTime

/** Night-mode settings synced from the Flutter app (the approved bedtime). */
data class BlockConfig(
    val enabled: Boolean = false,
    val bedtimeMin: Int = 0,
    val wakeMin: Int = 0,
    val graceMs: Long = 5 * 60_000L,
    val blockMs: Long = 10 * 60_000L,
    /** Show the watch bubble (time and reels) over Instagram and Shorts. */
    val bubble: Boolean = true,
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
    // Any phone use at night (screen on and unlocked, not the home screen or
    // GoodNight), for the partner's "still on their phone" alert.
    var phoneMs: Long = 0,
    var lastOnPhone: Boolean = false,
    var prevPhoneMs: Long = 0,
    // Reels and Shorts swiped through tonight, for the watch bubble.
    var reels: Int = 0,
)

sealed interface Decision {
    data object Allow : Decision
    data class Block(val remainingMs: Long) : Decision
}

/** Which pair and person the night log belongs to (pushed by the Flutter app). */
data class PairRef(val pairId: String, val uid: String)

/** What was last sent to the shared night log. */
data class Reported(
    val nightKey: String = "",
    val usageMinutes: Int = 0,
    val blocks: Int = 0,
    val phoneMinutes: Int = 0,
)

object NightReport {
    /**
     * Send tonight's numbers when there is something to show and it has grown
     * since the last send (a new minute of use or a new block).
     */
    fun shouldReport(
        last: Reported,
        nightKey: String,
        usageMinutes: Int,
        blocks: Int,
        phoneMinutes: Int = 0,
    ): Boolean {
        if (usageMinutes <= 0 && blocks <= 0 && phoneMinutes <= 0) return false
        if (last.nightKey != nightKey) return true
        return usageMinutes > last.usageMinutes || blocks > last.blocks ||
            phoneMinutes > last.phoneMinutes
    }
}

/**
 * The last request for extra minutes sent from the block screen. [id] is
 * empty when none is waiting for an answer; [count] is how many were sent on
 * the night [countKey].
 */
data class TimeRequest(
    val id: String = "",
    val minutes: Int = 0,
    val nightKey: String = "",
    val askedAt: Long = 0,
    val countKey: String = "",
    val count: Int = 0,
) {
    companion object {
        val CHOICES = listOf(5, 10, 15)
        const val MAX_PER_NIGHT = 3
        const val EXPIRE_MS = 20 * 60_000L

        fun expired(r: TimeRequest, nowMs: Long) = r.id.isNotEmpty() && nowMs - r.askedAt > EXPIRE_MS

        fun pending(r: TimeRequest, nowMs: Long) = r.id.isNotEmpty() && !expired(r, nowMs)

        fun sentTonight(r: TimeRequest, nightKey: String) = if (r.countKey == nightKey) r.count else 0

        /** One request at a time, and at most [MAX_PER_NIGHT] a night. */
        fun canAsk(r: TimeRequest, nightKey: String, nowMs: Long) =
            !pending(r, nowMs) && sentTonight(r, nightKey) < MAX_PER_NIGHT

        fun asked(r: TimeRequest, id: String, minutes: Int, nightKey: String, nowMs: Long) =
            TimeRequest(id, minutes, nightKey, nowMs, nightKey, sentTonight(r, nightKey) + 1)
    }
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
        onPhone: Boolean = onTarget,
    ): Decision {
        if (s.nightKey != nightKey) {
            if (s.nightKey.isNotEmpty()) {
                s.prevKey = s.nightKey
                s.prevBlocks = s.blocks
                s.prevUsedMs = s.totalUsedMs
                s.prevPhoneMs = s.phoneMs
            }
            s.nightKey = nightKey
            s.usedMs = 0
            s.blockUntil = 0
            s.blocks = 0
            s.totalUsedMs = 0
            s.phoneMs = 0
            s.lastOnPhone = false
            s.reels = 0
        }

        if (!isNight(c, minuteOfDay)) {
            s.lastOnTarget = false
            s.lastOnPhone = false
            s.lastTickAt = nowMs
            return Decision.Allow
        }

        // Phone use counts whether or not the app in front is a target.
        if (onPhone && s.lastOnPhone && s.lastTickAt > 0) {
            s.phoneMs += (nowMs - s.lastTickAt).coerceIn(0, MAX_GAP_MS)
        }
        s.lastOnPhone = onPhone

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

    /**
     * The partner gave [minutes] more: lift any pause, and the next pause
     * comes after exactly [minutes] more of Instagram/Shorts.
     */
    fun grantExtra(c: BlockConfig, s: BlockState, minutes: Int) {
        s.blockUntil = 0
        s.usedMs = c.graceMs - minutes * 60_000L
        s.lastOnTarget = false
    }
}
