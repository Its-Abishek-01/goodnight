package com.wiozen.goodnight

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TimeRequestTest {
    private val key = "2026-10-19"
    private val now = 10_000_000L

    @Test
    fun oneRequestAtATime() {
        val r = TimeRequest.asked(TimeRequest(), "a", 10, key, now)
        assertTrue(TimeRequest.pending(r, now + 60_000))
        assertFalse(TimeRequest.canAsk(r, key, now + 60_000))
        // Answered (id cleared): asking again is fine.
        assertTrue(TimeRequest.canAsk(r.copy(id = ""), key, now + 60_000))
    }

    @Test
    fun anUnansweredRequestExpires() {
        val r = TimeRequest.asked(TimeRequest(), "a", 10, key, now)
        assertFalse(TimeRequest.expired(r, now + TimeRequest.EXPIRE_MS))
        assertTrue(TimeRequest.expired(r, now + TimeRequest.EXPIRE_MS + 1))
        assertTrue(TimeRequest.canAsk(r, key, now + TimeRequest.EXPIRE_MS + 1))
    }

    @Test
    fun atMostThreeANightAndCountResetsNextNight() {
        var r = TimeRequest()
        repeat(TimeRequest.MAX_PER_NIGHT) {
            assertTrue(TimeRequest.canAsk(r, key, now))
            r = TimeRequest.asked(r, "id$it", 5, key, now).copy(id = "")
        }
        assertEquals(3, r.count)
        assertFalse(TimeRequest.canAsk(r, key, now))
        assertTrue(TimeRequest.canAsk(r, "2026-10-20", now))
        assertEquals(1, TimeRequest.asked(r, "x", 5, "2026-10-20", now).count)
    }

    @Test
    fun grantingLiftsThePauseAndGivesExactlyThatManyMinutes() {
        val c = BlockConfig(enabled = true, bedtimeMin = 23 * 60, wakeMin = 7 * 60, graceMs = 5 * 60_000L, blockMs = 10 * 60_000L)
        val s = BlockState(nightKey = key, blockUntil = now + 600_000, blocks = 1)
        BlockEngine.grantExtra(c, s, 10)
        var t = now
        assertEquals(Decision.Allow, BlockEngine.tick(c, s, t, 23 * 60 + 30, key, true))
        var blockedAt = 0L
        while (blockedAt == 0L && t < now + 20 * 60_000) {
            t += 5_000
            if (BlockEngine.tick(c, s, t, 23 * 60 + 30, key, true) is Decision.Block) blockedAt = t
        }
        assertEquals(10 * 60_000L, blockedAt - now)
    }
}
