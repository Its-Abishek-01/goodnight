package com.wiozen.goodnight

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "appVersion" -> result.success(
                        packageManager.getPackageInfo(packageName, 0).versionName ?: ""
                    )
                    "canInstall" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                    )
                    "openInstallSettings" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName"),
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    "install" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("no_path", "No APK path", null)
                        } else {
                            installApk(File(path))
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Hands a downloaded update to the system installer (cache/updates, see update_paths.xml). */
    private fun installApk(apk: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
        startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    companion object {
        const val CHANNEL = "com.wiozen.goodnight/blocker"
        const val UPDATER_CHANNEL = "com.wiozen.goodnight/updater"
    }
}
