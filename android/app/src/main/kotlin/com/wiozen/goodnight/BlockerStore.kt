package com.wiozen.goodnight

import android.content.Context

/** Persists night-mode config and timer state so the service survives restarts. */
class BlockerStore(context: Context) {
    private val p = context.getSharedPreferences("goodnight_blocker", Context.MODE_PRIVATE)

    fun saveConfig(enabled: Boolean, bedtimeMin: Int, wakeMin: Int, graceMin: Int, blockMin: Int) {
        p.edit()
            .putBoolean("enabled", enabled)
            .putInt("bedtimeMin", bedtimeMin)
            .putInt("wakeMin", wakeMin)
            .putInt("graceMin", graceMin)
            .putInt("blockMin", blockMin)
            .apply()
    }

    fun loadConfig() = BlockConfig(
        enabled = p.getBoolean("enabled", false),
        bedtimeMin = p.getInt("bedtimeMin", 0),
        wakeMin = p.getInt("wakeMin", 0),
        graceMs = p.getInt("graceMin", 5) * 60_000L,
        blockMs = p.getInt("blockMin", 10) * 60_000L,
    )

    fun loadState() = BlockState(
        nightKey = p.getString("s.nightKey", "") ?: "",
        usedMs = p.getLong("s.usedMs", 0),
        blockUntil = p.getLong("s.blockUntil", 0),
        blocks = p.getInt("s.blocks", 0),
        totalUsedMs = p.getLong("s.totalUsedMs", 0),
        lastTickAt = p.getLong("s.lastTickAt", 0),
        lastOnTarget = p.getBoolean("s.lastOnTarget", false),
        prevKey = p.getString("s.prevKey", "") ?: "",
        prevBlocks = p.getInt("s.prevBlocks", 0),
        prevUsedMs = p.getLong("s.prevUsedMs", 0),
    )

    fun saveState(s: BlockState) {
        p.edit()
            .putString("s.nightKey", s.nightKey)
            .putLong("s.usedMs", s.usedMs)
            .putLong("s.blockUntil", s.blockUntil)
            .putInt("s.blocks", s.blocks)
            .putLong("s.totalUsedMs", s.totalUsedMs)
            .putLong("s.lastTickAt", s.lastTickAt)
            .putBoolean("s.lastOnTarget", s.lastOnTarget)
            .putString("s.prevKey", s.prevKey)
            .putInt("s.prevBlocks", s.prevBlocks)
            .putLong("s.prevUsedMs", s.prevUsedMs)
            .apply()
    }
}
