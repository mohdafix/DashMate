package com.dashmate.dashmate

import android.graphics.Color
import android.os.Handler
import android.os.Looper
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Day / night for the car screen. The car session sets it from Android Auto's night mode; the
 * phone preview sets it from the phone's dark mode when no car is connected. Listeners (the
 * Presentation) recolour the deck page and dock without reloading.
 */
object DashMateTheme {

    @Volatile
    var isDark: Boolean = true

    /** True while a DashMateSession is live, so the phone preview does not override the car's value. */
    @Volatile
    var carSessionActive: Boolean = false

    private val listeners = CopyOnWriteArrayList<(Boolean) -> Unit>()
    private val main = Handler(Looper.getMainLooper())

    fun mode(): String = if (isDark) "dark" else "light"

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
