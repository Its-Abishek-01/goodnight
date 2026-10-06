package com.wiozen.goodnight

import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BlockEngineTest {
    private val config = BlockConfig(
        enabled = true,
        bedtimeMin = 23 * 60,
        wakeMin = 6 * 60 + 30,
        graceMs = 5 * 60_000L,
        blockMs = 10 * 60_000L,
    )
    private val night = 23 * 60 + 30
    private val key = "2026-10-06"

    private fun tick(s: BlockState, nowMs: Long, onTarget: Boolean, minute: Int = night) =
        BlockEngine.tick(config, s, nowMs, minute, key, onTarget)

    @Test
    fun nightWindowCrossesMidnight() {
        assertTrue(BlockEngine.isNight(config, 23 * 60 + 1))
        assertTrue(BlockEngine.isNight(config, 2 * 60))
        assertFalse(BlockEngine.isNight(config, 6 * 60 + 30))
        assertFalse(BlockEngine.isNight(config, 12 * 60))
        assertFalse(BlockEngine.isNight(config.copy(enabled = false), 2 * 60))
    }

    @Test
    fun blocksAfterFiveMinutesOfUse() {
        val s = BlockState()
        var t = 1_000_000L
        assertEquals(Decision.Allow, tick(s, t, true))
        var blocked: Decision = Decision.Allow
        // Tick every 5 seconds for just over 5 minutes.
        repeat(61) {
            t += 5_000
            blocked = tick(s, t, true)
            if (blocked is Decision.Block) return@repeat
        }
        assertTrue(blocked is Decision.Block)
        assertEquals(1, s.blocks)
    }

    @Test
    fun staysBlockedForTenMinutesThenGetsNewGrace() {
        val s = BlockState(nightKey = key, blockUntil = 1_000_000L + 10 * 60_000L, blocks = 1)
        val start = 1_000_000L
        assertTrue(tick(s, start + 60_000, true) is Decision.Block)
        assertEquals(Decision.Allow, tick(s, start + 60_000, false))
        // After the block expires, use is allowed again and counts from zero.
        val after = start + 10 * 60_000L + 1_000
        assertEquals(Decision.Allow, tick(s, after, true))
        assertEquals(0L, s.usedMs)
        assertEquals(Decision.Allow, tick(s, after + 5_000, true))
        assertEquals(5_000L, s.usedMs)
    }

    @Test
    fun usageOffTargetOrByDayIsNotCounted() {
        val s = BlockState()
        tick(s, 1_000_000L, false)
        tick(s, 1_005_000L, false)
        assertEquals(0L, s.usedMs)
        tick(s, 1_010_000L, true, minute = 12 * 60)
        tick(s, 1_015_000L, true, minute = 12 * 60)
        assertEquals(0L, s.usedMs)
    }

    @Test
    fun longGapsAreCapped() {
        val s = BlockState()
        tick(s, 1_000_000L, true)
        tick(s, 1_000_000L + 10 * 60_000L, true)
        assertEquals(BlockEngine.MAX_GAP_MS, s.usedMs)
    }

    @Test
    fun newNightResetsCountersAndKeepsPreviousTotals() {
        val s = BlockState(nightKey = "2026-10-05", blocks = 2, totalUsedMs = 9 * 60_000L)
        BlockEngine.tick(config, s, 1_000_000L, night, "2026-10-06", false)
        assertEquals(0, s.blocks)
        assertEquals("2026-10-05", s.prevKey)
        assertEquals(2, s.prevBlocks)
        assertEquals(9 * 60_000L, s.prevUsedMs)
    }

    @Test
    fun nightKeyMatchesDartGrouping() {
        assertEquals("2026-10-06", nightKeyOf(LocalDateTime.of(2026, 10, 6, 23, 0)))
        assertEquals("2026-10-06", nightKeyOf(LocalDateTime.of(2026, 10, 7, 2, 0)))
        assertEquals("2026-10-07", nightKeyOf(LocalDateTime.of(2026, 10, 7, 13, 0)))
    }

    @Test
    fun urlDetection() {
        assertTrue(Targets.isBlockedUrl("instagram.com/reels"))
        assertTrue(Targets.isBlockedUrl("https://www.instagram.com"))
        assertTrue(Targets.isBlockedUrl("m.youtube.com/shorts/abc"))
        assertFalse(Targets.isBlockedUrl("youtube.com/watch?v=1"))
        assertFalse(Targets.isBlockedUrl(null))
    }
}
