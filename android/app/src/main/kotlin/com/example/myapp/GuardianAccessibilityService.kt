package com.example.myapp

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent

/**
 * AccessibilityService that monitors foreground app changes and blocks
 * apps in the enforced blocklist (over daily limit) by sending HOME + BACK.
 */
class GuardianAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var lastBlockedPackage: String? = null
    private var lastBlockTime: Long = 0
    private val blockedPackages = mutableSetOf<String>()
    private var lastForegroundPackage: String = ""

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }
        serviceInfo = info
        applyPendingBlockedPackages(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return

        if (packageName != lastForegroundPackage && packageName != this.packageName) {
            lastForegroundPackage = packageName
            val intent = Intent(AppBlockerService.ACTION_APP_FOREGROUND).apply {
                setPackage(this@GuardianAccessibilityService.packageName)
                putExtra(AppBlockerService.EXTRA_FOREGROUND_PACKAGE, packageName)
            }
            sendBroadcast(intent)
        }

        // Only skip our own app and system UI — do NOT skip com.google.android.* or
        // parents cannot block YouTube, Chrome, etc.
        if (packageName == this.packageName ||
            packageName == "com.example.myapp" ||
            packageName == "com.android.systemui"
        ) {
            return
        }

        if (blockedPackages.contains(packageName)) {
            val currentTime = System.currentTimeMillis()
            if (packageName != lastBlockedPackage || (currentTime - lastBlockTime) > 2000) {
                lastBlockedPackage = packageName
                lastBlockTime = currentTime
                blockApp()
            }
        }
    }

    private fun blockApp() {
        handler.post {
            try {
                performGlobalAction(GLOBAL_ACTION_HOME)
                for (i in 0..2) {
                    performGlobalAction(GLOBAL_ACTION_BACK)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onInterrupt() {
    }

    override fun onDestroy() {
        if (instance == this) {
            instance = null
        }
        super.onDestroy()
    }

    companion object {
        private var instance: GuardianAccessibilityService? = null
        private val pendingBlockedPackages = mutableSetOf<String>()

        /**
         * Replaces the in-memory blocklist. If the service is not connected yet,
         * stores a pending copy applied in [onServiceConnected].
         */
        fun updateBlockedPackages(packages: Set<String>) {
            synchronized(pendingBlockedPackages) {
                pendingBlockedPackages.clear()
                pendingBlockedPackages.addAll(packages)
            }
            instance?.let { svc ->
                synchronized(svc.blockedPackages) {
                    svc.blockedPackages.clear()
                    svc.blockedPackages.addAll(packages)
                }
            }
        }

        private fun applyPendingBlockedPackages(service: GuardianAccessibilityService) {
            synchronized(pendingBlockedPackages) {
                service.blockedPackages.clear()
                service.blockedPackages.addAll(pendingBlockedPackages)
            }
        }

        fun setInstance(service: GuardianAccessibilityService) {
            instance = service
        }

        fun isServiceRunning(): Boolean = instance != null
    }

    init {
        setInstance(this)
    }
}
