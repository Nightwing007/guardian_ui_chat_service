package com.example.myapp

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
import java.util.Calendar

/**
 * Wraps UsageStatsManager to query per-app foreground usage time.
 *
 * Uses queryEvents() to compute foreground time from raw
 * MOVE_TO_FOREGROUND / MOVE_TO_BACKGROUND event pairs.
 * This is the most accurate method and matches Digital Wellbeing's numbers.
 */
class AppUsageTracker(private val context: Context) {

    companion object {
        const val TAG = "AppUsageTracker"
    }

    private val usageStatsManager: UsageStatsManager
        get() = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

    private val packageManager: PackageManager
        get() = context.packageManager

    private val launchableCache = mutableMapOf<String, Boolean>()

    fun hasUsageStatsPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        }
        val granted = mode == AppOpsManager.MODE_ALLOWED
        Log.d(TAG, "hasUsageStatsPermission: $granted")
        return granted
    }

    fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    fun getAppUsageStats(startTime: Long, endTime: Long): ArrayList<HashMap<String, Any>> {
        if (!hasUsageStatsPermission()) {
            Log.w(TAG, "Usage stats permission not granted")
            return arrayListOf()
        }

        Log.d(TAG, "getAppUsageStats: querying events from $startTime to $endTime")

        val usageEvents: UsageEvents
        try {
            usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        } catch (e: Exception) {
            Log.e(TAG, "queryEvents failed: ${e.message}", e)
            return arrayListOf()
        }

        val event = UsageEvents.Event()
        val totalUsage = mutableMapOf<String, Long>()
        val lastUsed = mutableMapOf<String, Long>()

        var currentForegroundApp: String? = null
        var sessionStartTime: Long = 0L

        fun closeActiveSession(timestamp: Long) {
            if (currentForegroundApp != null) {
                val duration = timestamp - sessionStartTime
                if (duration > 0) {
                    totalUsage[currentForegroundApp!!] =
                        (totalUsage[currentForegroundApp!!] ?: 0L) + duration
                }
                currentForegroundApp = null
            }
        }

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val pkg = event.packageName ?: continue
            val ts = event.timeStamp

            when (event.eventType) {
                1 -> {
                    if (currentForegroundApp != null && currentForegroundApp != pkg) {
                        closeActiveSession(ts)
                    }
                    if (currentForegroundApp == null) {
                        currentForegroundApp = pkg
                        sessionStartTime = ts
                    }
                    lastUsed[pkg] = ts
                }
                2 -> {
                    if (currentForegroundApp == pkg) {
                        closeActiveSession(ts)
                    }
                }
                16, 26 -> {
                    closeActiveSession(ts)
                }
            }
        }

        closeActiveSession(endTime)

        val result = arrayListOf<HashMap<String, Any>>()

        for ((pkg, time) in totalUsage) {
            if (time <= 0) continue
            if (!isLaunchableApp(pkg)) continue

            val map = HashMap<String, Any>()
            map["packageName"] = pkg
            map["appName"] = getAppName(pkg)
            map["totalTimeInForeground"] = time
            map["lastTimeUsed"] = lastUsed[pkg] ?: 0L
            result.add(map)
        }

        result.sortByDescending { it["totalTimeInForeground"] as Long }

        Log.d(TAG, "Final state-machine result: ${result.size} apps")
        for (stat in result.take(15)) {
            val mins = (stat["totalTimeInForeground"] as Long) / 60000
            Log.d(TAG, "  ${stat["appName"]}: ${mins}m (${stat["packageName"]})")
        }

        return result
    }

    fun getTodayUsageStats(): ArrayList<HashMap<String, Any>> {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val now = System.currentTimeMillis()
        Log.d(TAG, "getTodayUsageStats: midnight=${cal.timeInMillis}, now=$now")
        return getAppUsageStats(cal.timeInMillis, now)
    }

    fun getWeeklyUsageStats(): ArrayList<HashMap<String, Any>> {
        val cal = Calendar.getInstance()
        val endTime = cal.timeInMillis
        cal.add(Calendar.DAY_OF_YEAR, -7)
        return getAppUsageStats(cal.timeInMillis, endTime)
    }

    fun getWeeklyDailyBreakdown(): ArrayList<HashMap<String, Any>> {
        val result = arrayListOf<HashMap<String, Any>>()

        for (i in 6 downTo 0) {
            val dayCal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, -i)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val dayStart = dayCal.timeInMillis
            dayCal.add(Calendar.DAY_OF_YEAR, 1)
            val dayEnd = minOf(dayCal.timeInMillis, System.currentTimeMillis())

            val dayStats = getAppUsageStats(dayStart, dayEnd)
            val totalTime = dayStats.sumOf { (it["totalTimeInForeground"] as? Long) ?: 0L }

            val dayMap = HashMap<String, Any>()
            dayMap["date"] = dayStart
            dayMap["totalTime"] = totalTime
            result.add(dayMap)
        }
        return result
    }

    /**
     * Best-effort foreground app detection from recent usage events.
     * Works as a fallback when accessibility foreground broadcasts are missing.
     */
    fun getCurrentForegroundPackage(lookbackMs: Long = 60_000L): String? {
        if (!hasUsageStatsPermission()) return null
        val end = System.currentTimeMillis()
        val start = (end - lookbackMs).coerceAtLeast(0L)
        val events = try {
            usageStatsManager.queryEvents(start, end)
        } catch (e: Exception) {
            Log.w(TAG, "getCurrentForegroundPackage query failed: ${e.message}")
            return null
        }

        val event = UsageEvents.Event()
        var current: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            when (event.eventType) {
                1 -> current = pkg // ACTIVITY_RESUMED
                2 -> if (current == pkg) current = null // ACTIVITY_PAUSED
                16, 26 -> current = null // screen off / shutdown
            }
        }
        if (current == null) return null
        if (current == context.packageName) return null
        if (!isLaunchableApp(current)) return null
        return current
    }

    private fun getAppName(packageName: String): String {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            packageName.substringAfterLast(".")
        }
    }

    private fun isLaunchableApp(packageName: String): Boolean {
        if (packageName == context.packageName) return false

        return launchableCache.getOrPut(packageName) {
            try {
                val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                val result = launchIntent != null
                if (!result) {
                    Log.v(TAG, "  filtered out (no launcher): $packageName")
                }
                result
            } catch (_: Exception) {
                false
            }
        }
    }
}
