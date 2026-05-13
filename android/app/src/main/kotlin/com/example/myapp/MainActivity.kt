package com.example.myapp

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.Process
import android.graphics.pdf.PdfRenderer
import android.provider.Settings
import android.text.TextUtils
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import androidx.core.graphics.drawable.toBitmap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class MainActivity : FlutterActivity() {

    private lateinit var aiLoopMethodHandler: AiLoopMethodHandler

    private val CHANNEL = "guardian/monitoring"

    // In-memory state for services that don't have a real background
    // service yet. These survive as long as the Activity process lives.
    private var vpnRunning = false
    private var locationTrackingRunning = false
    private val blockedApps = mutableSetOf<String>()
    private var monitoringChannel: MethodChannel? = null
    private var packageChangeReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        monitoringChannel = channel
        channel.setMethodCallHandler { call, result ->
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
                    "getInstalledApp" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            result.success(getInstalledApp(packageName))
                        } else {
                            result.error("INVALID_ARGUMENT", "packageName is required", null)
                        }
                    }
                    "startInstalledAppsWatcher" -> {
                        startInstalledAppsWatcher()
                        result.success(true)
                    }
                    "stopInstalledAppsWatcher" -> {
                        stopInstalledAppsWatcher()
                        result.success(true)
                    }

                    // ── App Blocking ─────────────────────────────────────
                    "blockApp" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            blockedApps.add(packageName)
                            GuardianAccessibilityService.updateBlockedPackages(blockedApps)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "packageName is required", null)
                        }
                    }
                    "unblockApp" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            blockedApps.remove(packageName)
                            GuardianAccessibilityService.updateBlockedPackages(blockedApps)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "packageName is required", null)
                        }
                    }
                    "isAppBlocked" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            result.success(blockedApps.contains(packageName))
                        } else {
                            result.error("INVALID_ARGUMENT", "packageName is required", null)
                        }
                    }
                    "getBlockedApps" -> {
                        result.success(blockedApps.toList())
                    }
                    "syncBlockedApps" -> {
                        GuardianAccessibilityService.updateBlockedPackages(blockedApps)
                        result.success(true)
                    }
                    "syncEnforcedBlocklist" -> {
                        val list = call.argument<List<Any>>("packages")
                        if (list != null) {
                            val pkgs = list.mapNotNull { it as? String }.toSet()
                            blockedApps.clear()
                            blockedApps.addAll(pkgs)
                            GuardianAccessibilityService.updateBlockedPackages(blockedApps)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "packages list required", null)
                        }
                    }

                    // ── App limits & foreground blocker (Guardian-AI-4 parity) ──
                    "setAppLimit" -> {
                        val pkg = call.argument<String>("packageName")
                        val limitMs = call.argument<Number>("limitMs")?.toLong()
                        if (pkg != null && limitMs != null) {
                            AppBlockerService.setLimit(this, pkg, limitMs)
                            val startIntent = Intent(this, AppBlockerService::class.java)
                                .setAction(AppBlockerService.ACTION_START)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(startIntent)
                            } else {
                                startService(startIntent)
                            }
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGS", "packageName and limitMs required", null)
                        }
                    }
                    "removeAppLimit" -> {
                        val pkg = call.argument<String>("packageName")
                        if (pkg != null) {
                            AppBlockerService.removeLimit(this, pkg)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGS", "packageName required", null)
                        }
                    }
                    "getAppLimits" -> {
                        val limits = AppBlockerService.getLimits(this)
                        result.success(HashMap(limits))
                    }
                    "startBlocker" -> {
                        val startIntent = Intent(this, AppBlockerService::class.java)
                            .setAction(AppBlockerService.ACTION_START)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(startIntent)
                        } else {
                            startService(startIntent)
                        }
                        result.success(null)
                    }
                    "stopBlocker" -> {
                        startService(
                            Intent(this, AppBlockerService::class.java)
                                .setAction(AppBlockerService.ACTION_STOP)
                        )
                        result.success(null)
                    }
                    "isBlockerRunning" -> {
                        result.success(AppBlockerService.isRunning)
                    }

                    // ── Parent Document Vault ─────────────────────────────
                    "renderPdfPages" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "filePath is required", null)
                        } else {
                            try {
                                result.success(renderPdfPages(filePath))
                            } catch (e: Exception) {
                                result.error("PDF_RENDER_FAILED", e.message, null)
                            }
                        }
                    }
                    "shareFile" -> {
                        val filePath = call.argument<String>("filePath")
                        val fileName = call.argument<String>("fileName")
                        if (filePath.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "filePath is required", null)
                        } else {
                            try {
                                shareFile(filePath, fileName)
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("SHARE_FAILED", e.message, null)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        aiLoopMethodHandler = AiLoopMethodHandler(this, flutterEngine)
        aiLoopMethodHandler.register()
    }

    // ── Helpers ────────────────────────────────────────────────────────

    override fun onDestroy() {
        aiLoopMethodHandler.destroy()
        stopInstalledAppsWatcher()
        super.onDestroy()
    }

    private fun startInstalledAppsWatcher() {
        if (packageChangeReceiver != null) return

        packageChangeReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                val packageName = intent.data?.schemeSpecificPart ?: return
                val replacing = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)

                val changeType = when (action) {
                    Intent.ACTION_PACKAGE_REMOVED -> if (replacing) "updated" else "removed"
                    Intent.ACTION_PACKAGE_ADDED -> if (replacing) "updated" else "added"
                    Intent.ACTION_PACKAGE_CHANGED -> "changed"
                    else -> "changed"
                }

                monitoringChannel?.invokeMethod(
                    "installedAppsChanged",
                    mapOf(
                        "packageName" to packageName,
                        "changeType" to changeType
                    )
                )
            }
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_CHANGED)
            addDataScheme("package")
        }

        val receiver = packageChangeReceiver ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
    }

    private fun stopInstalledAppsWatcher() {
        val receiver = packageChangeReceiver ?: return
        try {
            unregisterReceiver(receiver)
        } catch (_: Exception) {
            // Receiver was already unregistered.
        } finally {
            packageChangeReceiver = null
        }
    }

    private fun renderPdfPages(filePath: String): List<String> {
        val source = File(filePath)
        if (!source.exists()) return emptyList()

        val outputDir = File(cacheDir, "document_vault_pdf_previews").apply {
            deleteRecursively()
            mkdirs()
        }
        val outputPaths = mutableListOf<String>()

        ParcelFileDescriptor.open(source, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
            PdfRenderer(descriptor).use { renderer ->
                for (index in 0 until renderer.pageCount) {
                    renderer.openPage(index).use { page ->
                        val maxWidth = 1400
                        val scale = maxOf(1f, maxWidth.toFloat() / page.width.toFloat())
                        val width = (page.width * scale).toInt()
                        val height = (page.height * scale).toInt()
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        Canvas(bitmap).drawColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)

                        val output = File(outputDir, "${source.nameWithoutExtension}_page_${index + 1}.png")
                        FileOutputStream(output).use { stream ->
                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                        }
                        bitmap.recycle()
                        outputPaths.add(output.absolutePath)
                    }
                }
            }
        }

        return outputPaths
    }

    private fun shareFile(filePath: String, fileName: String?) {
        val sourceFile = File(filePath)
        if (!sourceFile.exists()) {
            throw IllegalArgumentException("File does not exist")
        }

        val shareDir = File(cacheDir, "document_vault_shares").apply {
            mkdirs()
        }
        val shareFileName = fileName?.takeIf { it.isNotBlank() } ?: sourceFile.name
        val shareFile = File(shareDir, shareFileName)
        sourceFile.copyTo(shareFile, overwrite = true)

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            shareFile
        )
        val mimeType = mimeTypeFor(shareFile)
        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TITLE, shareFileName)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val chooser = Intent.createChooser(shareIntent, "Share $shareFileName").apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(chooser)
    }

    private fun mimeTypeFor(file: File): String {
        val extension = file.extension.lowercase(Locale.US)
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "application/octet-stream"
    }

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
     * Queries UsageStatsManager for today's per-app usage stats using
     * UsageEvents for accurate foreground time tracking.
     */
    private fun getTodayUsageStats(): List<Map<String, Any>> {
        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        val events = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()

        val accumulatedTime = mutableMapOf<String, Long>()
        var currentPackage: String? = null
        var currentResumedTime: Long = 0L

        while (events.hasNextEvent()) {
            events.getNextEvent(event)

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    val newPkg = event.packageName
                    val time = event.timeStamp

                    if (currentPackage != null && currentPackage != newPkg) {
                        val duration = time - currentResumedTime
                        if (duration > 0) {
                            accumulatedTime[currentPackage!!] =
                                accumulatedTime.getOrDefault(currentPackage!!, 0L) + duration
                        }
                    }

                    currentPackage = newPkg
                    currentResumedTime = time
                }

                UsageEvents.Event.ACTIVITY_PAUSED -> {
                    val pausedPkg = event.packageName
                    if (pausedPkg == currentPackage) {
                        val time = event.timeStamp
                        val duration = time - currentResumedTime
                        if (duration > 0) {
                            accumulatedTime[pausedPkg] =
                                accumulatedTime.getOrDefault(pausedPkg, 0L) + duration
                        }
                        currentPackage = null
                    }
                }
            }
        }

        // Handle still-active package at endTime
        if (currentPackage != null) {
            val duration = endTime - currentResumedTime
            if (duration > 0) {
                accumulatedTime[currentPackage!!] =
                    accumulatedTime.getOrDefault(currentPackage!!, 0L) + duration
            }
        }

        // Convert to result list
        val pm = packageManager
        val systemPrefixes = listOf(
            "com.android.",
            "android.",
            "com.google.android.gms",
            "com.google.android.gsf",
            "com.google.android.webview",
            "com.google.android.partnersetup",
            "com.qualcomm.",
            "com.motorola.",
            "com.motorola.launcher",
        )

        val resultList = mutableListOf<Map<String, Any>>()

        for ((pkg, totalTime) in accumulatedTime) {
            if (totalTime <= 0) continue
            if (systemPrefixes.any { pkg.startsWith(it) }) continue

            val appName = try {
                val appInfo = pm.getApplicationInfo(pkg, PackageManager.GET_META_DATA)
                pm.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                continue
            }

            resultList.add(
                mapOf(
                    "packageName" to pkg,
                    "appName" to appName,
                    "totalTimeInForeground" to totalTime,
                    "lastTimeUsed" to endTime
                )
            )
        }

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
     * Returns a list of maps for each installed app with
     * packageName, appName, category, created, and iconBytes (PNG encoded).
     * Includes user apps only, skipping pure system apps.
     */
    private fun getAllInstalledApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val installedApps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val resultList = mutableListOf<Map<String, Any?>>()

        for (appInfo in installedApps) {
            getInstalledAppMap(appInfo)?.let { resultList.add(it) }
        }

        return resultList
    }

    private fun getInstalledApp(packageName: String): Map<String, Any?>? {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            getInstalledAppMap(appInfo)
        } catch (e: Exception) {
            null
        }
    }

    private fun getInstalledAppMap(appInfo: ApplicationInfo): Map<String, Any?>? {
        val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
        val isUpdatedSystemApp = (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
        if (isSystemApp && !isUpdatedSystemApp) return null

        val pm = packageManager
        val appName = try {
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            appInfo.packageName
        }

        val iconBytes = try {
            val icon = pm.getApplicationIcon(appInfo)
            val bitmap = icon.toBitmap(width = 96, height = 96)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        }

        return mapOf(
            "packageName" to appInfo.packageName,
            "appName" to appName,
            "category" to getAppCategory(appInfo),
            "created" to getInstallTime(appInfo.packageName),
            "iconBytes" to iconBytes
        )
    }

    private fun getAppCategory(appInfo: ApplicationInfo): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return "not available"

        return when (appInfo.category) {
            ApplicationInfo.CATEGORY_GAME -> "game"
            ApplicationInfo.CATEGORY_AUDIO -> "audio"
            ApplicationInfo.CATEGORY_VIDEO -> "video"
            ApplicationInfo.CATEGORY_IMAGE -> "image"
            ApplicationInfo.CATEGORY_SOCIAL -> "social"
            ApplicationInfo.CATEGORY_NEWS -> "news"
            ApplicationInfo.CATEGORY_MAPS -> "maps"
            ApplicationInfo.CATEGORY_PRODUCTIVITY -> "productivity"
            else -> "not available"
        }
    }

    private fun getInstallTime(packageName: String): String {
        return try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            val installTime = packageInfo.firstInstallTime
            if (installTime <= 0L) {
                "not available"
            } else {
                val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US)
                formatter.timeZone = TimeZone.getDefault()
                formatter.format(Date(installTime))
            }
        } catch (e: Exception) {
            "not available"
        }
    }
}
