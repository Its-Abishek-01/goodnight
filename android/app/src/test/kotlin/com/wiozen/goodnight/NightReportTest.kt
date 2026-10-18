package com.wiozen.goodnight

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NightReportTest {
    private val key = "2026-10-19"

    @Test
    fun nothingToShowIsNotSent() {
        assertFalse(NightReport.shouldReport(Reported(), key, 0, 0))
    }

    @Test
    fun firstMinuteOfANightIsSent() {
        assertTrue(NightReport.shouldReport(Reported(), key, 1, 0))
        assertTrue(NightReport.shouldReport(Reported("2026-10-18", 40, 3), key, 1, 0))
    }

    @Test
    fun onlyGrowthIsSentAgain() {
        val last = Reported(key, 4, 0)
        assertFalse(NightReport.shouldReport(last, key, 4, 0))
        assertTrue(NightReport.shouldReport(last, key, 5, 0))
        assertTrue(NightReport.shouldReport(last, key, 4, 1))
    }
}
