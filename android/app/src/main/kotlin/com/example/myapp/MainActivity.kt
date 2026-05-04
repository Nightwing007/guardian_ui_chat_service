package com.example.myapp

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.text.TextUtils
import androidx.core.graphics.drawable.toBitmap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Calendar

class MainActivity : FlutterActivity() {

    private val CHANNEL = "guardian/monitoring"

    // In-memory state for services that don't have a real background
    // service yet. These survive as long as the Activity process lives.
    private var vpnRunning = false
    private var locationTrackingRunning = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Usage Stats ────────────────────────────────────
                    "hasUsageStatsPermission" -> {
                        result.success(hasUsageStatsPermission())
                    }
                    "openUsageAccessSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "getTodayUsageStats" -> {
                        result.success(getTodayUsageStats())
                    }

                    // ── Overlay ────────────────────────────────────────
                    "hasOverlayPermission" -> {
                        result.success(
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                                Settings.canDrawOverlays(this)
                            else true
                        )
                    }
                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        }
                        result.success(null)
                    }

                    // ── Accessibility ──────────────────────────────────
                    "isAccessibilityEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }

                    // ── VPN ────────────────────────────────────────────
                    "isVpnRunning" -> {
                        result.success(vpnRunning)
                    }
                    "startVpn" -> {
                        vpnRunning = true
                        result.success("started")
                    }
                    "stopVpn" -> {
                        vpnRunning = false
                        result.success(null)
                    }

                    // ── Location Tracking ─────────────────────────────
                    "isLocationTrackingRunning" -> {
                        result.success(locationTrackingRunning)
                    }
                    "startLocationTracking" -> {
                        locationTrackingRunning = true
                        result.success("started")
                    }
                    "stopLocationTracking" -> {
                        locationTrackingRunning = false
                        result.success(null)
                    }

                    // ── Installed Apps ─────────────────────────────────
                    "getAllInstalledApps" -> {
                        result.success(getAllInstalledApps())
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ── Helpers ────────────────────────────────────────────────────────

    /**
     * Checks if this app has been granted usage-stats access via
     * [AppOpsManager].
     */
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Queries UsageStatsManager for today's per-app usage stats.
     * Returns a list of maps with packageName, appName, totalTimeInForeground,
     * and lastTimeUsed for each app that has > 0 foreground time today.
     */
    private fun getTodayUsageStats(): List<Map<String, Any>> {
        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        // Start of today (midnight)
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startTime,
            endTime
        )

        val pm = packageManager
        val resultList = mutableListOf<Map<String, Any>>()

        if (stats != null) {
            for (usageStat in stats) {
                // Skip apps with no foreground time
                if (usageStat.totalTimeInForeground <= 0) continue

                // Try to get a human-readable app name
                val appName = try {
                    val appInfo = pm.getApplicationInfo(
                        usageStat.packageName,
                        PackageManager.GET_META_DATA
                    )
                    pm.getApplicationLabel(appInfo).toString()
                } catch (e: PackageManager.NameNotFoundException) {
                    usageStat.packageName
                }

                resultList.add(
                    mapOf(
                        "packageName" to usageStat.packageName,
                        "appName" to appName,
                        "totalTimeInForeground" to usageStat.totalTimeInForeground,
                        "lastTimeUsed" to usageStat.lastTimeUsed
                    )
                )
            }
        }

        // Sort by foreground time descending (most-used first)
        resultList.sortByDescending { it["totalTimeInForeground"] as Long }

        return resultList
    }

    /**
     * Checks whether the Guardian AI accessibility service is currently
     * enabled in Settings → Accessibility.
     */
    private fun isAccessibilityServiceEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)
        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.startsWith(packageName)) {
                return true
            }
        }
        return false
    }

    /**
     * Returns a list of maps for each installed app (non-system only) with
     * packageName, appName, and iconBytes (PNG encoded).
     */
    private fun getAllInstalledApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val installedApps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val resultList = mutableListOf<Map<String, Any?>>()

        for (appInfo in installedApps) {
            // Skip system apps
            if ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0) continue

            val appName = pm.getApplicationLabel(appInfo).toString()
            val iconBytes = try {
                val icon: Drawable = pm.getApplicationIcon(appInfo.packageName)
                val bitmap = icon.toBitmap(width = 128, height = 128)
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                stream.toByteArray()
            } catch (e: Exception) {
                null
            }

            resultList.add(
                mapOf(
                    "packageName" to appInfo.packageName,
                    "appName" to appName,
                    "iconBytes" to iconBytes
                )
            )
        }

        return resultList
    }
}
