package com.example.myapp

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Full-screen overlay activity shown when a time-limited app exceeds its limit.
 *
 * Soft-block: lets the user add 5 more minutes or go back home.
 */
class BlockerOverlayActivity : Activity() {

    private var packageNameBlocked = ""
    private var usedMs = 0L
    private var limitMs = 0L
    private var appName = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        packageNameBlocked = intent.getStringExtra("packageName") ?: ""
        usedMs = intent.getLongExtra("usedMs", 0L)
        limitMs = intent.getLongExtra("limitMs", 0L)
        appName = intent.getStringExtra("appName") ?: packageNameBlocked

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_FULLSCREEN
            )
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.parseColor("#0F0F1A")

        buildUI()
    }

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onBackPressed() {
        goHome()
    }

    private fun goHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }

    private fun addFiveMinutes() {
        val newLimit = limitMs + 5 * 60 * 1000L
        AppBlockerService.setLimit(this, packageNameBlocked, newLimit)
        finish()
    }

    private fun buildUI() {
        val dp = { value: Int ->
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                value.toFloat(),
                resources.displayMetrics
            ).toInt()
        }

        val bgColor = Color.parseColor("#0F0F1A")
        val surfaceColor = Color.parseColor("#1A1A2E")
        val purpleColor = Color.parseColor("#6C63FF")
        val tealColor = Color.parseColor("#03DAC6")
        val redColor = Color.parseColor("#FF4D6D")

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(bgColor)
            setPadding(dp(32), dp(48), dp(32), dp(48))
        }

        val iconContainer = LinearLayout(this).apply {
            gravity = Gravity.CENTER
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                colors = intArrayOf(purpleColor, Color.parseColor("#3D5AFE"))
                setSize(dp(80), dp(80))
            }
            background = bg
            setPadding(dp(20), dp(20), dp(20), dp(20))
        }
        val icon = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_lock_idle_alarm)
            setColorFilter(Color.WHITE)
            layoutParams = LinearLayout.LayoutParams(dp(40), dp(40))
        }
        iconContainer.addView(icon)
        root.addView(iconContainer, LinearLayout.LayoutParams(dp(80), dp(80)).apply {
            gravity = Gravity.CENTER_HORIZONTAL
            bottomMargin = dp(24)
        })

        root.addView(TextView(this).apply {
            text = "Time's Up!"
            setTextColor(Color.WHITE)
            textSize = 28f
            gravity = Gravity.CENTER
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = dp(8) })

        root.addView(TextView(this).apply {
            text = appName
            setTextColor(purpleColor)
            textSize = 20f
            gravity = Gravity.CENTER
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = dp(24) })

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            val bg = GradientDrawable().apply {
                setColor(surfaceColor)
                cornerRadius = dp(16).toFloat()
                setStroke(1, Color.parseColor("#1F1F3A"))
            }
            background = bg
            setPadding(dp(24), dp(20), dp(24), dp(20))
        }

        val usedStr = formatDuration(usedMs)
        val limitStr = formatDuration(limitMs)

        card.addView(TextView(this).apply {
            text = "You've used this app for"
            setTextColor(Color.parseColor("#FFFFFF99"))
            textSize = 14f
            gravity = Gravity.CENTER
        })
        card.addView(TextView(this).apply {
            text = usedStr
            setTextColor(redColor)
            textSize = 32f
            gravity = Gravity.CENTER
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(4)
            bottomMargin = dp(4)
        })
        card.addView(TextView(this).apply {
            text = "Your daily limit: $limitStr"
            setTextColor(Color.parseColor("#FFFFFF66"))
            textSize = 13f
            gravity = Gravity.CENTER
        })

        root.addView(card, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = dp(32) })

        root.addView(TextView(this).apply {
            text = "Take a break! You've reached your daily screen time limit for this app."
            setTextColor(Color.parseColor("#FFFFFF88"))
            textSize = 14f
            gravity = Gravity.CENTER
            setLineSpacing(dp(4).toFloat(), 1f)
        }, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = dp(32) })

        root.addView(Button(this).apply {
            text = "Go Home"
            setTextColor(Color.WHITE)
            textSize = 16f
            isAllCaps = false
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            val bg = GradientDrawable().apply {
                colors = intArrayOf(purpleColor, Color.parseColor("#3D5AFE"))
                cornerRadius = dp(12).toFloat()
                orientation = GradientDrawable.Orientation.LEFT_RIGHT
            }
            background = bg
            setPadding(dp(24), dp(14), dp(24), dp(14))
            setOnClickListener { goHome() }
        }, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = dp(12) })

        root.addView(Button(this).apply {
            text = "+5 More Minutes"
            setTextColor(tealColor)
            textSize = 14f
            isAllCaps = false
            val bg = GradientDrawable().apply {
                setColor(Color.TRANSPARENT)
                cornerRadius = dp(12).toFloat()
                setStroke(dp(1), Color.parseColor("#03DAC644"))
            }
            background = bg
            setPadding(dp(24), dp(12), dp(24), dp(12))
            setOnClickListener { addFiveMinutes() }
        }, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        setContentView(root)
    }

    private fun formatDuration(ms: Long): String {
        val totalMinutes = ms / 60_000
        val hours = totalMinutes / 60
        val minutes = totalMinutes % 60
        return when {
            hours > 0 -> "${hours}h ${minutes}m"
            else -> "${minutes}m"
        }
    }
}
