package com.example.myapp

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent

/**
 * AccessibilityService that monitors foreground app changes and blocks
 * apps that have exceeded their screen time limits by forcing back to home.
 */
class GuardianAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var lastBlockedPackage: String? = null
    private var lastBlockTime: Long = 0
    private val blockedPackages = mutableSetOf<String>()

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
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return

        // Skip system packages and this app
        if (packageName.startsWith("com.android.") ||
            packageName.startsWith("android.") ||
            packageName.startsWith("com.google.android.") ||
            packageName == this.packageName ||
            packageName == "com.example.myapp") {
            return
        }

        // Check if this package is blocked
        if (blockedPackages.contains(packageName)) {
            // Prevent rapid repeated blocking (debounce 2 seconds)
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
                // Force go to home screen - this effectively blocks the app
                performGlobalAction(GLOBAL_ACTION_HOME)
                
                // Also try to go back to stop the app
                for (i in 0..2) {
                    performGlobalAction(GLOBAL_ACTION_BACK)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onInterrupt() {
        // Required override
    }

    companion object {
        private var instance: GuardianAccessibilityService? = null

        fun updateBlockedPackages(packages: Set<String>) {
            instance?.let { service ->
                service.blockedPackages.clear()
                service.blockedPackages.addAll(packages)
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