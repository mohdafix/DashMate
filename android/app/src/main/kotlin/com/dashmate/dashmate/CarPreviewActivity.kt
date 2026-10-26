package com.dashmate.dashmate

import android.app.Activity
import android.content.Context
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.widget.FrameLayout

/**
 * The car screen on the phone: the same DashMate deck Android Auto shows, fully usable.
 *
 * It works exactly like the car side (DashMateCarScreen): a private virtual display drawn into a
 * surface, with DashMatePresentation on it. The surface keeps the head unit's shape (saved on each
 * drive), and finger touches are scaled into the display's pixels. The red Exit button closes it.
 */
class CarPreviewActivity : Activity(), SurfaceHolder.Callback {

    private lateinit var surfaceView: SurfaceView
    private var virtualDisplay: VirtualDisplay? = null
    private var presentation: DashMatePresentation? = null
    private var carW = DEFAULT_W
    private var carH = DEFAULT_H
    private var carDpi = DEFAULT_DPI
    /** True when the preview shows only the car's visible area (so no extra padding is applied). */
    private var cropped = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // No car connected: the preview follows the phone's light/dark mode. While a car session
        // is live, the car's day/night wins.
        if (!DashMateTheme.carSessionActive) {
            val night = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
            DashMateTheme.set(night == Configuration.UI_MODE_NIGHT_YES)
        }
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        carW = prefs.getInt(KEY_W, DEFAULT_W)
        carH = prefs.getInt(KEY_H, DEFAULT_H)
        carDpi = prefs.getInt(KEY_DPI, DEFAULT_DPI)
        // If the car hides part of its picture behind margins (common on tall screens), show only
        // the part the driver really sees, at that size.
        savedVisibleArea(this, carW, carH)?.let { area ->
            if (area.width() > 0 && area.height() > 0 && (area.width() < carW || area.height() < carH)) {
                carW = area.width()
                carH = area.height()
                cropped = true
            }
        }
        // "Always tall" (Settings › Car layout): the car shows its tall placement on any screen, so the
        // preview opens tall too, as a portrait screen of the same size.
        if (DashMateStateBridge.layoutMode(this) == "tall" && carW > carH) {
            val w = carW
            carW = carH
            carH = w
            cropped = true   // the saved visible area is for the real (wide) screen: don't apply it
        }
        // Same shape as the car: portrait for the Jaecoo J7's tall screen, landscape for a wide one.
        requestedOrientation = if (carH > carW) ActivityInfo.SCREEN_ORIENTATION_SENSOR_PORTRAIT
        else ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE

        surfaceView = SurfaceView(this).apply {
            holder.addCallback(this@CarPreviewActivity)
            setOnTouchListener { v, ev -> forwardTouch(v, ev); true }
        }
        val root = object : FrameLayout(this) {
            // Fit the car's shape inside the phone screen (letterboxed, centred).
            override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
                val w = r - l
                val h = b - t
                val scale = minOf(w.toFloat() / carW, h.toFloat() / carH)
                val sw = (carW * scale).toInt()
                val sh = (carH * scale).toInt()
                val x = (w - sw) / 2
                val y = (h - sh) / 2
                surfaceView.layout(x, y, x + sw, y + sh)
            }

            override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
                super.onMeasure(widthMeasureSpec, heightMeasureSpec)
                val scale = minOf(measuredWidth.toFloat() / carW, measuredHeight.toFloat() / carH)
                surfaceView.measure(
                    View.MeasureSpec.makeMeasureSpec((carW * scale).toInt(), View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec((carH * scale).toInt(), View.MeasureSpec.EXACTLY),
                )
            }
        }.apply {
            setBackgroundColor(Color.BLACK)
            addView(surfaceView, FrameLayout.LayoutParams(carW, carH, Gravity.CENTER))
        }
        setContentView(root)
        hideSystemBars()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) hideSystemBars()
    }

    private fun hideSystemBars() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let {
                it.hide(WindowInsets.Type.systemBars())
                it.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
        }
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        // Render at the car's real resolution; the view scales it to the phone.
        holder.setFixedSize(carW, carH)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        if (virtualDisplay != null) return
        try {
            val dm = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
            virtualDisplay = dm.createVirtualDisplay(
                "DashMatePreview", carW, carH, carDpi, holder.surface,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_PRESENTATION,
            )
            val display = virtualDisplay?.display ?: return
            presentation = DashMatePresentation(this, display).apply {
                onExit = { finish() }
                show()
                // Same usable area as the car (the part not hidden by the screen's frame).
                if (!cropped) savedVisibleArea(this@CarPreviewActivity, carW, carH)?.let { onVisibleAreaChanged(it) }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Could not start the car screen preview", e)
            finish()
        }
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) = release()

    override fun onDestroy() {
        release()
        super.onDestroy()
    }

    private fun release() {
        try {
            presentation?.dismiss()
        } catch (_: Exception) {
        }
        presentation = null
        virtualDisplay?.release()
        virtualDisplay = null
    }

    /** Scales a finger touch on the (scaled) preview into the car display's pixels. */
    private fun forwardTouch(v: View, ev: MotionEvent) {
        val p = presentation ?: return
        if (v.width == 0 || v.height == 0) return
        val copy = MotionEvent.obtain(ev)
        copy.setLocation(ev.x * carW / v.width, ev.y * carH / v.height)
        p.dispatchPhoneTouch(copy)
        copy.recycle()
    }

    companion object {
        private const val TAG = "CarPreviewActivity"
        private const val PREFS = "dd_car_browser"
        private const val KEY_W = "car_screen_w"
        private const val KEY_H = "car_screen_h"
        private const val KEY_DPI = "car_screen_dpi"
        private const val KEY_AREA = "car_screen_visible_area"
        // Before the first drive: an estimate of the Jaecoo J7 14.8" portrait screen. Replaced by
        // the car's own numbers as soon as DashMate opens in the car.
        private const val DEFAULT_W = 1080
        private const val DEFAULT_H = 1920
        private const val DEFAULT_DPI = 240

        /**
         * Called by the car each time its screen is ready. Keeps the largest size seen (the
         * full-screen app view, not the smaller home-screen panel), so the preview matches the car.
         */
        fun rememberCarScreen(context: Context, width: Int, height: Int, dpi: Int) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val savedArea = prefs.getInt(KEY_W, 0) * prefs.getInt(KEY_H, 0)
            if (width * height >= savedArea) {
                val changed = width != prefs.getInt(KEY_W, 0) || height != prefs.getInt(KEY_H, 0)
                prefs.edit().putInt(KEY_W, width).putInt(KEY_H, height).putInt(KEY_DPI, dpi).apply {
                    if (changed) remove(KEY_AREA)
                }.apply()
            }
        }

        /** Saves the car's usable area, but only for the full-size screen we keep. */
        fun rememberVisibleArea(context: Context, width: Int, height: Int, area: Rect) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (width != prefs.getInt(KEY_W, 0) || height != prefs.getInt(KEY_H, 0)) return
            prefs.edit().putString(KEY_AREA, area.flattenToString()).apply()
        }

        private fun savedVisibleArea(context: Context, width: Int, height: Int): Rect? {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (width != prefs.getInt(KEY_W, 0) || height != prefs.getInt(KEY_H, 0)) return null
            return prefs.getString(KEY_AREA, null)?.let { Rect.unflattenFromString(it) }
        }

        /** "1920 × 720" for the app's settings page, or null before the first drive. */
        fun savedSize(context: Context): String? {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            var w = prefs.getInt(KEY_W, 0)
            var h = prefs.getInt(KEY_H, 0)
            if (w <= 0 || h <= 0) return null
            // Report what the driver sees (the visible part), like the preview does.
            savedVisibleArea(context, w, h)?.let { if (it.width() > 0 && it.height() > 0) { w = it.width(); h = it.height() } }
            return "$w × $h " + if (h > w) "(portrait)" else "(landscape)"
        }
    }
}
