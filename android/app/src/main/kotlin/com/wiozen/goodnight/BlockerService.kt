package com.wiozen.goodnight

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
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

    private val ticker = object : Runnable {
        override fun run() {
            evaluate()
            handler.postDelayed(this, TICK_MS)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        store = BlockerStore(this)
        handler.post(ticker)
    }

    override fun onUnbind(intent: Intent?): Boolean {
        handler.removeCallbacks(ticker)
        removeOverlay()
        return super.onUnbind(intent)
    }

    override fun onInterrupt() {}

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val e = event ?: return
        val pkg = e.packageName?.toString() ?: return
        when (e.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                if (pkg == "com.android.systemui" || Targets.isKeyboard(pkg) || pkg == packageName) {
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
        val onTarget = fgPackage == Targets.INSTAGRAM ||
            (isContentApp(fgPackage) && contentTarget)
        val decision = BlockEngine.tick(
            config,
            state,
            System.currentTimeMillis(),
            now.hour * 60 + now.minute,
            nightKeyOf(now),
            onTarget,
        )
        store.saveState(state)
        if (decision is Decision.Block) {
            fgPackage = ""
            contentTarget = false
            performGlobalAction(GLOBAL_ACTION_HOME)
            showOverlay(decision.remainingMs)
        }
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
        private const val OVERLAY_MS = 8_000L

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
