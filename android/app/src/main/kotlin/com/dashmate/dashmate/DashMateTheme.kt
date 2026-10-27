package com.dashmate.dashmate

import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Day / night for the car screen.
 * Mode options:
 * - "auto": Follows car headlights / sunset signals (or phone system mode when no car is connected)
 * - "day": Forced light theme
 * - "night": Forced dark theme
 * Listeners (the Presentation) recolour the deck page and dock without reloading.
 */
object DashMateTheme {

    const val MODE_AUTO = "auto"
    const val MODE_DAY = "day"
    const val MODE_NIGHT = "night"

    private const val PREFS_BROWSER = "dd_car_browser"
    private const val KEY_THEME_MODE = "theme_mode"

    @Volatile
    var themeMode: String = MODE_AUTO

    @Volatile
    var isDark: Boolean = true

    /** True while a DashMateSession is live, so the phone preview does not override the car's value. */
    @Volatile
    var carSessionActive: Boolean = false

    @Volatile
    var lastCarDarkMode: Boolean = true

    private val listeners = CopyOnWriteArrayList<(Boolean) -> Unit>()
    private val main = Handler(Looper.getMainLooper())

    fun init(context: Context) {
        val sp = context.getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
        var mode = sp.getString(KEY_THEME_MODE, null)
        if (mode == null) {
            val legacy = sp.getString("theme", null)
            mode = when (legacy) {
                "light" -> MODE_DAY
                "dark" -> MODE_NIGHT
                else -> MODE_AUTO
            }
        }
        themeMode = mode
        applyCurrentMode(lastCarDarkMode)
    }

    fun mode(): String = if (isDark) "dark" else "light"

    fun getThemeMode(context: Context? = null): String {
        if (context != null && themeMode.isBlank()) {
            init(context)
        }
        return themeMode
    }

    fun setThemeMode(context: Context, mode: String) {
        themeMode = when (mode.lowercase()) {
            MODE_DAY, "light" -> MODE_DAY
            MODE_NIGHT, "dark" -> MODE_NIGHT
            else -> MODE_AUTO
        }
        val sp = context.getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
        sp.edit()
            .putString(KEY_THEME_MODE, themeMode)
            .putString("theme", if (themeMode == MODE_DAY) "light" else "dark")
            .apply()
        applyCurrentMode(lastCarDarkMode)
    }

    /** Car session reports daylight or headlights changed. */
    fun onCarNightModeChanged(carDarkMode: Boolean) {
        lastCarDarkMode = carDarkMode
        applyCurrentMode(carDarkMode)
    }

    /** Updates effective dark/light based on themeMode and the given autoDarkMode. */
    fun applyCurrentMode(autoDarkMode: Boolean) {
        val effectiveDark = when (themeMode) {
            MODE_DAY -> false
            MODE_NIGHT -> true
            else -> autoDarkMode
        }
        set(effectiveDark)
    }

    fun addListener(l: (Boolean) -> Unit) {
        listeners.addIfAbsent(l)
    }

    fun removeListener(l: (Boolean) -> Unit) {
        listeners.remove(l)
    }

    /** Sets day/night; listeners hear about it only when it changes, always on the main thread. */
    fun set(dark: Boolean) {
        if (isDark == dark) return
        isDark = dark
        val notify = Runnable { for (l in listeners) l(dark) }
        if (Looper.myLooper() == Looper.getMainLooper()) notify.run() else main.post(notify)
    }

    // Shared native colours (same values as design tokens), for chrome the Presentation draws.
    fun bg(dark: Boolean = isDark): Int = Color.parseColor(if (dark) "#0F1115" else "#F8FAFC")
    fun surface(dark: Boolean = isDark): Int = Color.parseColor(if (dark) "#181B21" else "#FFFFFF")
    fun border(dark: Boolean = isDark): Int = Color.parseColor(if (dark) "#2A2F37" else "#E2E8F0")
    fun ink(dark: Boolean = isDark): Int = Color.parseColor(if (dark) "#F1F5F9" else "#0F172A")
    fun accent(dark: Boolean = isDark): Int = Color.parseColor(if (dark) "#2DD4BF" else "#0F766E")
}
