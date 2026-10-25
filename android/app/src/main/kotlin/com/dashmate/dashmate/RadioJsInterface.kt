package com.dashmate.dashmate

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface

/** window.DashMateRadio — used by assets/dashmate_radio.html on the car Deck. */
class RadioJsInterface(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())

    /** Runs [action] on the main thread; starts the media service first if it isn't running. */
    private fun withService(action: () -> Unit) {
        main.post {
            if (DashMateMediaCardService.instance != null) {
                action()
            } else {
                try {
                    context.startForegroundService(Intent(context, DashMateMediaCardService::class.java))
                } catch (_: Exception) {
                }
                main.postDelayed({ action() }, 800)
            }
        }
    }

    @JavascriptInterface fun stations(): String = DashMateMediaCardService.radioStationsJson()
    @JavascriptInterface fun state(): String = DashMateMediaCardService.radioStateJson()
    @JavascriptInterface fun play(id: String) = withService { DashMateMediaCardService.radioPlay(id) }
    @JavascriptInterface fun toggle() = withService { DashMateMediaCardService.radioToggle() }
    @JavascriptInterface fun next() = withService { DashMateMediaCardService.radioNext() }
    @JavascriptInterface fun prev() = withService { DashMateMediaCardService.radioPrev() }
    @JavascriptInterface fun stop() = withService { DashMateMediaCardService.radioStop() }
}
