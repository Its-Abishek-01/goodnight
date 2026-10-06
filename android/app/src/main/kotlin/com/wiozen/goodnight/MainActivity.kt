package com.wiozen.goodnight

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isServiceEnabled" -> result.success(BlockerService.isEnabled(this))
                    "openAccessibilitySettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    "openAppDetails" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName"),
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    "saveConfig" -> {
                        BlockerStore(this).saveConfig(
                            enabled = call.argument<Boolean>("enabled") ?: false,
                            bedtimeMin = call.argument<Int>("bedtimeMin") ?: 0,
                            wakeMin = call.argument<Int>("wakeMin") ?: 0,
                            graceMin = call.argument<Int>("graceMin") ?: 5,
                            blockMin = call.argument<Int>("blockMin") ?: 10,
                        )
                        result.success(null)
                    }
                    "getStats" -> {
                        val s = BlockerStore(this).loadState()
                        result.success(
                            mapOf(
                                "nightKey" to s.nightKey,
                                "blocks" to s.blocks,
                                "usageMinutes" to (s.totalUsedMs / 60_000).toInt(),
                                "prevKey" to s.prevKey,
                                "prevBlocks" to s.prevBlocks,
                                "prevUsageMinutes" to (s.prevUsedMs / 60_000).toInt(),
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        const val CHANNEL = "com.wiozen.goodnight/blocker"
    }
}
