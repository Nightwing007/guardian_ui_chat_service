package com.example.myapp

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.Window
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class AiLoopMethodHandler(
    private val activity: Activity,
    private val flutterEngine: FlutterEngine,
) {
    companion object {
        const val CHANNEL = "guardian/ai_loop"
    }

    fun register() {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "captureScreen" -> captureScreen(result)
                    else -> result.notImplemented()
                }
            }
    }

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
