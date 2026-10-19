package com.wiozen.goodnight

import android.accessibilityservice.AccessibilityService
import android.app.KeyguardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import java.time.LocalDateTime

/**
 * Watches which app (or website) is in front. It only looks at the package
 * name, the browser address bar and whether the YouTube Shorts player is
 * showing, and only does anything during the user's approved night hours.
 */
class BlockerService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var store: BlockerStore

    private var fgPackage = ""
    private var contentTarget = false
    private var lastContentCheck = 0L
    private var overlay: View? = null
    private lateinit var bubble: WatchBubbleOverlay
    private val reelTrack = ReelTrack()
    private var session = WatchSession()

    private val ticker = object : Runnable {
        override fun run() {
            evaluate()
            handler.postDelayed(this, TICK_MS)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        store = BlockerStore(this)
        bubble = WatchBubbleOverlay(this, store)
        session = store.loadSession()
        instance = this
        handler.post(ticker)
    }

    override fun onUnbind(intent: Intent?): Boolean {
        if (instance === this) instance = null
        handler.removeCallbacks(ticker)
        removeOverlay()
        if (::bubble.isInitialized) bubble.remove()
        return super.onUnbind(intent)
    }

    override fun onInterrupt() {}

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val e = event ?: return
        val pkg = e.packageName?.toString() ?: return
        when (e.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                if (pkg == "com.android.systemui" || Targets.isKeyboard(pkg)) return
                if (pkg == packageName) {
                    // Our own overlays (the watch bubble, the pause screen) are not an app
                    // in front; only GoodNight's own screen is.
                    if (!isOwnActivity(e.className?.toString())) return
                    // GoodNight itself: not a target, not phone use.
                    fgPackage = pkg
                    contentTarget = false
                    return
                }
                if (pkg != fgPackage) {
                    fgPackage = pkg
                    contentTarget = false
                }
                refreshContent(pkg, force = true)
                evaluate()
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                if (pkg == fgPackage && isContentApp(pkg) && refreshContent(pkg, force = false)) {
                    evaluate()
                }
            }
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> onScrolled(e, pkg)
        }
    }

    /**
     * A reaction from the partner watching your screen floats up over
     * whatever app you are in (Watch together).
     */
    fun showReaction(emoji: String) {
        if (emoji.isEmpty()) return
        val dp = resources.displayMetrics.density
        val h = (resources.displayMetrics.heightPixels * 0.6f).toInt()
        val root = android.widget.FrameLayout(this)
        val face = TextView(this).apply {
            text = emoji
            textSize = 44f
        }
        root.addView(face, android.widget.FrameLayout.LayoutParams(
            android.widget.FrameLayout.LayoutParams.WRAP_CONTENT,
            android.widget.FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
        ))
        val lp = WindowManager.LayoutParams(
            (96 * dp).toInt(),
            h,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.END
            x = ((8 + (0..56).random()) * dp).toInt()
            y = (120 * dp).toInt()
        }
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        try {
            wm.addView(root, lp)
        } catch (_: Exception) {
            return
        }
        face.animate()
            .translationY(-(h - 60 * dp))
            .alpha(0f)
            .scaleX(1.3f)
            .scaleY(1.3f)
            .setDuration(2_400)
            .withEndAction {
                try {
                    wm.removeView(root)
                } catch (_: Exception) {
                }
            }
            .start()
    }

    /** "Preview" on the Us tab. */
    fun previewBubble(): Boolean = ::bubble.isInitialized && bubble.preview()

    /** A swipe in the Reels or Shorts pager is one more reel (and one more tonight, at night). */
    private fun onScrolled(e: AccessibilityEvent, pkg: String) {
        if (!::store.isInitialized || pkg != fgPackage) return
        val ids = Targets.REEL_PAGER_IDS[pkg] ?: return
        val id = try {
            e.source?.viewIdResourceName
        } catch (_: Exception) {
            null
        }
        val isPager = if (id != null) {
            ids.any { id.endsWith(":id/$it") }
        } else {
            // No id on the scrolled view: check the screen for the pager.
            val root = rootInActiveWindow
            root != null && ids.any { root.findAccessibilityNodeInfosByViewId("$pkg:id/$it").isNotEmpty() }
        }
        if (!isPager) return
        val nowMs = System.currentTimeMillis()
        if (!ReelCounter.onScroll(reelTrack, id ?: pkg, e.fromIndex, nowMs)) return
        WatchSessions.addReel(session, nowMs)
        store.saveSession(session)
        val now = LocalDateTime.now()
        val config = store.loadConfig()
        val state = store.loadState()
        val night = BlockEngine.isNight(config, now.hour * 60 + now.minute) &&
            state.nightKey == nightKeyOf(now)
        if (night) {
            if (nowMs < state.blockUntil) return
            state.reels++
            store.saveState(state)
        }
        if (config.bubble && !bubble.previewing) showBubble(config, state, night)
    }

    /** Tonight's numbers and the countdown to the pause at night; this sitting's otherwise. */
    private fun showBubble(config: BlockConfig, state: BlockState, night: Boolean) {
        if (night) {
            bubble.update(state.totalUsedMs, state.reels, Mood.of(state.usedMs, config.graceMs))
        } else {
            bubble.update(session.watchedMs, session.reels, Mood.ofSession(session.watchedMs))
        }
    }

    private val ownActivities = mutableMapOf<String, Boolean>()

    private fun isOwnActivity(className: String?): Boolean {
        if (className.isNullOrEmpty()) return false
        return ownActivities.getOrPut(className) {
            try {
                packageManager.getActivityInfo(ComponentName(packageName, className), 0)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun isContentApp(pkg: String) =
        pkg == Targets.YOUTUBE || Targets.BROWSER_URL_IDS.containsKey(pkg)

    /** Re-reads the screen for YouTube and browsers. Returns true if it ran. */
    private fun refreshContent(pkg: String, force: Boolean): Boolean {
        if (!isContentApp(pkg)) return false
        val now = System.currentTimeMillis()
        if (!force && now - lastContentCheck < CONTENT_THROTTLE_MS) return false
        lastContentCheck = now
        val root = rootInActiveWindow ?: return false
        if (root.packageName?.toString() != pkg) return false
        contentTarget = try {
            when {
                pkg == Targets.YOUTUBE -> shortsVisible(root)
                else -> urlBlocked(root, Targets.BROWSER_URL_IDS[pkg].orEmpty())
            }
        } catch (_: Exception) {
            false
        }
        return true
    }

    private fun shortsVisible(root: AccessibilityNodeInfo): Boolean =
        Targets.SHORTS_VIEW_IDS.any {
            root.findAccessibilityNodeInfosByViewId("${Targets.YOUTUBE}:id/$it").isNotEmpty()
        }

    private fun urlBlocked(root: AccessibilityNodeInfo, ids: List<String>): Boolean {
        for (id in ids) {
            val text = root.findAccessibilityNodeInfosByViewId(id).firstOrNull()?.text?.toString()
            if (text != null) return Targets.isBlockedUrl(text)
        }
        return false
    }

    private fun evaluate() {
        if (!::store.isInitialized) return
        val config = store.loadConfig()
        val state = store.loadState()
        val now = LocalDateTime.now()
        // The last app stays "in front" while the screen is off or locked; that is not use.
        val inUse = screenInUse()
        val onTarget = inUse && (
            fgPackage == Targets.INSTAGRAM || (isContentApp(fgPackage) && contentTarget)
            )
        val onPhone = inUse && fgPackage.isNotEmpty() && fgPackage != packageName &&
            fgPackage != homePackage() && !Targets.isNotPhoneUse(fgPackage)
        WatchSessions.tick(session, System.currentTimeMillis(), onTarget)
        store.saveSession(session)
        val decision = BlockEngine.tick(
            config,
            state,
            System.currentTimeMillis(),
            now.hour * 60 + now.minute,
            nightKeyOf(now),
            onTarget,
            onPhone,
        )
        store.saveState(state)
        NightReporter.report(
            store,
            state.nightKey,
            (state.totalUsedMs / 60_000).toInt(),
            state.blocks,
            (state.phoneMs / 60_000).toInt(),
        )
        TimeRequests.poll(store) { approved, minutes ->
            handler.post { onAnswer(approved, minutes) }
        }
        if (decision is Decision.Block) {
            bubble.remove()
            fgPackage = ""
            contentTarget = false
            performGlobalAction(GLOBAL_ACTION_HOME)
            showOverlay(decision.remainingMs)
            return
        }
        if (bubble.previewing) return
        val night = BlockEngine.isNight(config, now.hour * 60 + now.minute)
        if (config.bubble && onTarget && System.currentTimeMillis() >= state.blockUntil) {
            showBubble(config, state, night)
        } else {
            bubble.remove()
        }
    }

    /** The partner answered a request for extra minutes. */
    private fun onAnswer(approved: Boolean, minutes: Int) {
        val name = store.partnerName()
        if (approved) {
            val state = store.loadState()
            BlockEngine.grantExtra(store.loadConfig(), state, minutes)
            store.saveState(state)
            removeOverlay()
            toast("${name.replaceFirstChar { it.uppercase() }} gave you $minutes more minutes 💛")
        } else {
            toast("${name.replaceFirstChar { it.uppercase() }} says it's time to sleep 🌙")
        }
    }

    private fun toast(text: String) = Toast.makeText(this, text, Toast.LENGTH_LONG).show()

    private fun screenInUse(): Boolean {
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return power.isInteractive && !keyguard.isKeyguardLocked
    }

    private var home: String? = null

    /** The launcher's package: being on the home screen is not phone use. */
    private fun homePackage(): String {
        home?.let { return it }
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val pkg = packageManager.resolveActivity(intent, 0)?.activityInfo?.packageName ?: ""
        home = pkg
        return pkg
    }

    private fun showOverlay(remainingMs: Long) {
        removeOverlay()
        val minutes = ((remainingMs + 59_999) / 60_000).coerceAtLeast(1)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(0xF2101028.toInt())
            setPadding(64, 64, 64, 64)
        }
        root.addView(TextView(this).apply {
            text = "It's past bedtime ❤️"
            textSize = 26f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
        })
        root.addView(TextView(this).apply {
            text = "Instagram and Shorts are paused for $minutes more min.\nSleep well."
            textSize = 16f
            setTextColor(0xFFCCCCFF.toInt())
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 48)
        })
        root.addView(Button(this).apply {
            text = "Okay, going to sleep"
            setOnClickListener { removeOverlay() }
        })
        addAskForTime(root)
        root.addView(Button(this).apply {
            text = "Open GoodNight"
            setOnClickListener {
                removeOverlay()
                startActivity(
                    Intent(this@BlockerService, MainActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }
        })
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager).addView(root, lp)
            overlay = root
            handler.postDelayed({ removeOverlay() }, OVERLAY_MS)
        } catch (_: Exception) {
            overlay = null
        }
    }

    /** "Need a bit longer? Ask {partner}" with +5/+10/+15, or the pending request. */
    private fun addAskForTime(root: LinearLayout) {
        val name = store.partnerName()
        val state = store.loadState()
        val req = store.loadRequest()
        val now = System.currentTimeMillis()
        val hint = TextView(this).apply {
            textSize = 14f
            setTextColor(0xFFCCCCFF.toInt())
            gravity = Gravity.CENTER
            setPadding(0, 40, 0, 8)
        }
        root.addView(hint)
        if (TimeRequest.pending(req, now)) {
            hint.text = "Asked $name for ${req.minutes} more min. It unlocks as soon as they say yes."
            return
        }
        if (!TimeRequest.canAsk(req, state.nightKey, now)) {
            hint.text = "No more asking for time tonight."
            return
        }
        hint.text = "Need a bit longer? Ask $name"
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        for (m in TimeRequest.CHOICES) {
            row.addView(Button(this).apply {
                text = "+$m min"
                setOnClickListener {
                    hint.text = "Asking $name…"
                    row.visibility = View.GONE
                    TimeRequests.ask(store, state.nightKey, m) { sent ->
                        handler.post {
                            hint.text = if (sent) {
                                "Asked $name for $m more min. It unlocks as soon as they say yes."
                            } else {
                                "Couldn't send that. Check your connection."
                            }
                            if (!sent) row.visibility = View.VISIBLE
                        }
                    }
                }
            })
        }
        root.addView(row)
    }

    private fun removeOverlay() {
        val v = overlay ?: return
        overlay = null
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(v)
        } catch (_: Exception) {
        }
    }

    companion object {
        private const val TICK_MS = 5_000L
        private const val CONTENT_THROTTLE_MS = 600L
        private const val OVERLAY_MS = 20_000L

        /** The running service, for the preview button. */
        var instance: BlockerService? = null
            private set

        /** True when the user has switched the accessibility service on. */
        fun isEnabled(context: Context): Boolean {
            val me = ComponentName(context, BlockerService::class.java).flattenToString()
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            return enabled.split(':').any { it.equals(me, ignoreCase = true) }
        }
    }
}
