package com.wiozen.goodnight

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WatchBubbleTest {
    private val grace = 5 * 60_000L

    @Test
    fun moodFollowsTheGraceTime() {
        assertEquals(Mood.HAPPY, Mood.of(0, grace))
        assertEquals(Mood.CURIOUS, Mood.of(90_000, grace))
        assertEquals(Mood.WORRIED, Mood.of(160_000, grace))
        assertEquals(Mood.SLEEPY, Mood.of(240_000, grace))
        assertEquals(Mood.GRUMPY, Mood.of(290_000, grace))
        assertEquals(Mood.GRUMPY, Mood.of(0, 0))
    }

    @Test
    fun aNewIndexIsANewReel() {
        val t = ReelTrack()
        assertTrue(ReelCounter.onScroll(t, "pager", 0, 1_000))
        assertFalse(ReelCounter.onScroll(t, "pager", 0, 1_200))
        assertTrue(ReelCounter.onScroll(t, "pager", 1, 3_000))
        assertFalse(ReelCounter.onScroll(t, "pager", 1, 3_100))
        assertTrue(ReelCounter.onScroll(t, "pager", 2, 9_000))
    }

    @Test
    fun aBounceIsNotTwoReels() {
        val t = ReelTrack()
        ReelCounter.onScroll(t, "pager", 4, 1_000)
        assertTrue(ReelCounter.onScroll(t, "pager", 5, 5_000))
        assertFalse(ReelCounter.onScroll(t, "pager", 4, 5_200))
    }

    @Test
    fun withoutAnIndexASwipeAfterAQuietGapCounts() {
        val t = ReelTrack()
        assertTrue(ReelCounter.onScroll(t, "pager", -1, 1_000))
        // The same swipe keeps sending events.
        assertFalse(ReelCounter.onScroll(t, "pager", -1, 1_100))
        assertFalse(ReelCounter.onScroll(t, "pager", -1, 1_500))
        assertTrue(ReelCounter.onScroll(t, "pager", -1, 6_000))
    }

    @Test
    fun theBubbleShowsOnStartMoodChangeReelsAndTime() {
        val start = BubbleMemory()
        assertTrue(BubbleSchedule.shouldShow(start, 0, Mood.HAPPY, 0))
        val m = BubbleSchedule.shown(1_000, Mood.HAPPY, 3)
        assertFalse(BubbleSchedule.shouldShow(m, 30_000, Mood.HAPPY, 9))
        assertTrue(BubbleSchedule.shouldShow(m, 30_000, Mood.HAPPY, 10))
        assertTrue(BubbleSchedule.shouldShow(m, 30_000, Mood.CURIOUS, 3))
        assertTrue(BubbleSchedule.shouldShow(m, 1_000 + BubbleSchedule.EVERY_MS, Mood.HAPPY, 3))
    }

    @Test
    fun theBubbleTucksAwayAfterAFewSeconds() {
        val m = BubbleSchedule.shown(1_000, Mood.HAPPY, 0)
        assertTrue(BubbleSchedule.visible(m, 5_000))
        assertFalse(BubbleSchedule.visible(m, 1_000 + BubbleSchedule.SHOW_MS))
        assertFalse(BubbleSchedule.visible(BubbleMemory(), 0))
    }

    @Test
    fun labels() {
        assertEquals("45s", BubbleSchedule.timeLabel(45_000))
        assertEquals("4 min", BubbleSchedule.timeLabel(4 * 60_000 + 30_000))
        assertEquals("1 h 05", BubbleSchedule.timeLabel(65 * 60_000))
        assertEquals("1 reel", BubbleSchedule.reelsLabel(1))
        assertEquals("12 reels", BubbleSchedule.reelsLabel(12))
    }
}
