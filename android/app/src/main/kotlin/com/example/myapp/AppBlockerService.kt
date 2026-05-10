package com.example.myapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.util.Log
import java.util.Timer
import java.util.TimerTask

/**
 * Foreground service that manages app time limits.
 *
 * - Loads per-app daily limits from SharedPreferences
 * - Periodically refreshes actual usage from UsageStatsManager
 * - When the AccessibilityService broadcasts a foreground app change,
 *   checks if that app has exceeded its limit and launches the blocker overlay.
 */
class AppBlockerService : Service() {

    companion object {
        const val TAG = "AppBlockerService"
        const val ACTION_START = "com.example.myapp.ACTION_START_BLOCKER"
        const val ACTION_STOP = "com.example.myapp.ACTION_STOP_BLOCKER"
        const val ACTION_APP_FOREGROUND = "com.example.myapp.APP_FOREGROUND"
        const val EXTRA_FOREGROUND_PACKAGE = "extra_foreground_package"
        const val PREFS_NAME = "app_limits"
        const val CHANNEL_ID = "blocker_channel"

        @Volatile
        var isRunning = false
            private set

        /** Read limits from SharedPreferences → Map<packageName, limitMs> */
        fun getLimits(context: Context): Map<String, Long> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val all = prefs.all
            return all.mapNotNull { (key, value) ->
                if (key.startsWith("limit_") && value is Long) {
                    key.removePrefix("limit_") to value
                } else null
            }.toMap()
        }

        fun setLimit(context: Context, packageName: String, limitMs: Long) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putLong("limit_$packageName", limitMs)
                .apply()
        }

        fun removeLimit(context: Context, packageName: String) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .remove("limit_$packageName")
                .apply()
        }
    }

    private lateinit var tracker: AppUsageTracker
    private var usageCache = mutableMapOf<String, Long>()
    private var limits = mutableMapOf<String, Long>()
    private var sessionBaseUsed = mutableMapOf<String, Long>()
    private var currentForegroundPackage: String? = null
    private var currentForegroundStartMs: Long = 0L
    private var enforcementTick: Int = 0
    private val lastBlockAt = mutableMapOf<String, Long>()
    private val blockedUntilForegroundChange = mutableSetOf<String>()
    private var refreshTimer: Timer? = null

    private val foregroundReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            val pkg = intent.getStringExtra(EXTRA_FOREGROUND_PACKAGE) ?: return
            if (pkg == packageName) return

            refreshLimits()
            refreshUsageCache()
            updateForegroundPackage(pkg)

            checkAndBlock(pkg)
        }
    }

    override fun onCreate() {
        super.onCreate()
        tracker = AppUsageTracker(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startBlocker()
            ACTION_STOP -> stopBlocker()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startBlocker() {
        if (isRunning) {
            refreshLimits()
            refreshUsageCache()
            Log.i(TAG, "AppBlockerService already running; state refreshed")
            return
        }
        isRunning = true

        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Guardian AI")
            .setContentText("App limits active")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setOngoing(true)
            .build()

        startForeground(2002, notification)

        refreshLimits()
        refreshUsageCache()
        updateForegroundFromUsageEvents()

        refreshTimer = Timer().apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    enforcementTick++
                    refreshLimits()

                    if (enforcementTick % 6 == 0) {
                        refreshUsageCache()
                    }

                    // Fallback for devices where accessibility foreground
                    // broadcasts are delayed/missing.
                    updateForegroundFromUsageEvents()
                    currentForegroundPackage?.let { checkAndBlock(it) }
                }
            }, 5_000L, 5_000L)
        }

        registerReceiverCompat(
            foregroundReceiver,
            IntentFilter(ACTION_APP_FOREGROUND)
        )

        Log.i(TAG, "AppBlockerService started with ${limits.size} limits")
    }

    private fun stopBlocker() {
        isRunning = false
        refreshTimer?.cancel()
        refreshTimer = null
        try {
            unregisterReceiver(foregroundReceiver)
        } catch (_: Exception) {
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.i(TAG, "AppBlockerService stopped")
    }

    override fun onDestroy() {
        stopBlocker()
        super.onDestroy()
    }

    private fun refreshUsageCache() {
        try {
            val todayStats = tracker.getTodayUsageStats()
            usageCache.clear()
            for (stat in todayStats) {
                val pkg = stat["packageName"] as? String ?: continue
                val time = stat["totalTimeInForeground"] as? Long ?: continue
                usageCache[pkg] = time
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to refresh usage cache", e)
        }
    }

    private fun refreshLimits() {
        limits.clear()
        limits.putAll(getLimits(this))
    }

    private fun updateForegroundFromUsageEvents() {
        val pkg = tracker.getCurrentForegroundPackage() ?: return
        if (pkg == currentForegroundPackage) return
        updateForegroundPackage(pkg)
        Log.d(TAG, "Foreground fallback detected: $pkg")
    }

    private fun updateForegroundPackage(newPkg: String) {
        val previous = currentForegroundPackage
        if (previous != null && previous != newPkg) {
            blockedUntilForegroundChange.remove(previous)
        }
        currentForegroundPackage = newPkg
        currentForegroundStartMs = System.currentTimeMillis()
        sessionBaseUsed[newPkg] = usageCache[newPkg] ?: 0L
    }

    private fun checkAndBlock(packageName: String) {
        val limit = limits[packageName] ?: return
        if (blockedUntilForegroundChange.contains(packageName)) return
        val used = currentUsedMs(packageName)
        val now = System.currentTimeMillis()

        val blockedRecently = (lastBlockAt[packageName] ?: 0L) > now - 15_000L
        if (blockedRecently) return

        if (used >= limit) {
            Log.i(TAG, "BLOCKING $packageName — used ${used / 1000}s, limit ${limit / 1000}s")
            lastBlockAt[packageName] = now
            blockedUntilForegroundChange.add(packageName)

            sendToHomeScreen()
            launchBlockerOverlay(packageName, used, limit)
        }
    }

    private fun currentUsedMs(packageName: String): Long {
        val base = sessionBaseUsed[packageName] ?: usageCache[packageName] ?: 0L
        val liveExtra = if (packageName == currentForegroundPackage && currentForegroundStartMs > 0L) {
            (System.currentTimeMillis() - currentForegroundStartMs).coerceAtLeast(0L)
        } else {
            0L
        }
        return base + liveExtra
    }

    private fun launchBlockerOverlay(packageName: String, usedMs: Long, limitMs: Long) {
        val intent = Intent(this, BlockerOverlayActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("packageName", packageName)
            putExtra("usedMs", usedMs)
            putExtra("limitMs", limitMs)
            putExtra("appName", getAppLabel(packageName))
        }
        try {
            startActivity(intent)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to launch blocker overlay: ${e.message}")
        }
    }

    private fun sendToHomeScreen() {
        try {
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(homeIntent)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to send app to home: ${e.message}")
        }
    }

    private fun getAppLabel(packageName: String): String {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (_: Exception) {
            packageName.substringAfterLast(".")
        }
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "App Blocker",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Shows while app limits are active"
        }
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(channel)
    }

    private fun registerReceiverCompat(receiver: BroadcastReceiver, filter: IntentFilter) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
    }
}
