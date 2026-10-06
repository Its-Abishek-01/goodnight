package com.wiozen.goodnight

/** What counts as a distraction at night, and how to recognise it. */
object Targets {
    const val INSTAGRAM = "com.instagram.android"
    const val YOUTUBE = "com.google.android.youtube"

    /** Browser package to the view ids that hold the address bar text. */
    val BROWSER_URL_IDS: Map<String, List<String>> = mapOf(
        "com.android.chrome" to listOf("com.android.chrome:id/url_bar"),
        "com.sec.android.app.sbrowser" to listOf("com.sec.android.app.sbrowser:id/location_bar_edit_text"),
        "org.mozilla.firefox" to listOf(
            "org.mozilla.firefox:id/mozac_browser_toolbar_url_view",
            "org.mozilla.firefox:id/url_bar_title",
        ),
        "com.brave.browser" to listOf("com.brave.browser:id/url_bar"),
        "com.microsoft.emmx" to listOf("com.microsoft.emmx:id/url_bar"),
        "com.opera.browser" to listOf("com.opera.browser:id/url_field"),
    )

    /** View ids that only exist while the YouTube Shorts player is on screen. */
    val SHORTS_VIEW_IDS = listOf(
        "reel_recycler",
        "reel_player_page_container",
        "reel_watch_fragment_root",
        "shorts_player_container",
    )

    fun isBlockedUrl(raw: String?): Boolean {
        val url = raw?.lowercase() ?: return false
        return url.contains("instagram.com") || url.contains("youtube.com/shorts")
    }

    fun isKeyboard(pkg: String): Boolean =
        pkg.contains("inputmethod") || pkg.contains("keyboard") || pkg.contains("swiftkey")
}
