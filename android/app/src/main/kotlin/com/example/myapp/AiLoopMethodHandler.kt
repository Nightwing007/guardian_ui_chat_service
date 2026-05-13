package com.example.myapp

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.Window
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class AiLoopMethodHandler(
    private val activity: Activity,
    private val flutterEngine: FlutterEngine,
) {
    companion object {
        const val CHANNEL = "guardian/ai_loop"
        const val FOREGROUND_APP_CHANNEL = "guardian/foreground_app"
    }

    // EventChannel sink — set when Flutter starts listening
    private var foregroundAppEventSink: EventChannel.EventSink? = null
    private var foregroundAppReceiver: BroadcastReceiver? = null

    fun register() {
        // ── MethodChannel: captureScreen ──────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "captureScreen" -> captureScreen(result)
                    else -> result.notImplemented()
                }
            }

        // ── EventChannel: foreground app changes ──────────────────────────
        // Listens to broadcasts from GuardianAccessibilityService and forwards
        // the foreground package name to Dart so FeedbackLoopController can
        // call setActiveApp() for adaptive capture-frequency tuning.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_APP_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    foregroundAppEventSink = events
                    startForegroundAppReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    stopForegroundAppReceiver()
                    foregroundAppEventSink = null
                }
            })
    }

    fun destroy() {
        stopForegroundAppReceiver()
        foregroundAppEventSink = null
    }

    // ── Foreground App Receiver ───────────────────────────────────────────

    private fun startForegroundAppReceiver() {
        if (foregroundAppReceiver != null) return

        foregroundAppReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val pkg = intent?.getStringExtra(AppBlockerService.EXTRA_FOREGROUND_PACKAGE)
                    ?: return
                Handler(Looper.getMainLooper()).post {
                    foregroundAppEventSink?.success(pkg)
                }
            }
        }

        val filter = IntentFilter(AppBlockerService.ACTION_APP_FOREGROUND)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(
                foregroundAppReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            @Suppress("DEPRECATION")
            activity.registerReceiver(foregroundAppReceiver, filter)
        }
    }

    private fun stopForegroundAppReceiver() {
        val receiver = foregroundAppReceiver ?: return
        try {
            activity.unregisterReceiver(receiver)
        } catch (_: Exception) {
            // Already unregistered — safe to ignore.
        } finally {
            foregroundAppReceiver = null
        }
    }

    // ── Screen Capture ────────────────────────────────────────────────────

    private fun captureScreen(result: MethodChannel.Result) {
        val window = activity.window
        val view = window.decorView
        val width = view.width
        val height = view.height
        if (width <= 0 || height <= 0) {
            result.error("CAPTURE_FAILED", "View not ready for capture", null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            captureWithPixelCopy(window, width, height, result)
        } else {
            captureWithCanvas(view, width, height, result)
        }
    }

    private fun captureWithCanvas(
        view: android.view.View,
        width: Int,
        height: Int,
        result: MethodChannel.Result,
    ) {
        try {
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            view.draw(canvas)
            val bytes = bitmap.toJpegBytes()
            bitmap.recycle()
            result.success(bytes)
        } catch (e: Exception) {
            result.error("CAPTURE_FAILED", e.message, null)
        }
    }

    private fun captureWithPixelCopy(
        window: Window,
        width: Int,
        height: Int,
        result: MethodChannel.Result,
    ) {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        PixelCopy.request(window, bitmap, { copyResult ->
            if (copyResult == PixelCopy.SUCCESS) {
                try {
                    val bytes = bitmap.toJpegBytes()
                    result.success(bytes)
                } catch (e: Exception) {
                    result.error("CAPTURE_FAILED", e.message, null)
                } finally {
                    bitmap.recycle()
                }
            } else {
                bitmap.recycle()
                result.error("CAPTURE_FAILED", "PixelCopy failed with code $copyResult", null)
            }
        }, Handler(Looper.getMainLooper()))
    }

    private fun Bitmap.toJpegBytes(quality: Int = 85): ByteArray {
        val stream = ByteArrayOutputStream()
        compress(Bitmap.CompressFormat.JPEG, quality, stream)
        return stream.toByteArray()
    }
}
