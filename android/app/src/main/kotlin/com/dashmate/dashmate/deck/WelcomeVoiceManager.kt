package com.dashmate.dashmate.deck

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

object WelcomeVoiceManager {
    private const val TAG = "WelcomeVoiceManager"
    private var tts: TextToSpeech? = null
    private var isTtsReady = false
    private val pendingSpeechQueue = mutableListOf<() -> Unit>()

    fun init(context: Context) {
        getOrCreateTts(context) {}
    }

    private fun getOrCreateTts(context: Context, onReady: (TextToSpeech) -> Unit) {
        if (tts != null && isTtsReady) {
            onReady(tts!!)
            return
        }

        pendingSpeechQueue.add {
            tts?.let { onReady(it) }
        }

        if (tts != null) {
            // Already initializing
            return
        }

        try {
            Log.d(TAG, "Initializing TextToSpeech engine...")
            tts = TextToSpeech(context) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    isTtsReady = true
                    Log.d(TAG, "TextToSpeech initialized successfully.")
                    try {
                        val defaultLocale = Locale.getDefault()
                        val res = tts?.setLanguage(defaultLocale)
                        if (res == TextToSpeech.LANG_MISSING_DATA || res == TextToSpeech.LANG_NOT_SUPPORTED) {
                            Log.w(TAG, "Default locale $defaultLocale not supported or missing data, falling back to US English.")
                            tts?.setLanguage(Locale.US)
                        } else {
                            Log.d(TAG, "TTS language set to: $defaultLocale")
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed setting TTS language: ${e.message}, falling back to US English.")
                        try { tts?.setLanguage(Locale.US) } catch (_: Exception) {}
                    }

                    // Flush pending speech
                    val queue = ArrayList(pendingSpeechQueue)
                    pendingSpeechQueue.clear()
                    for (action in queue) {
                        try { action() } catch (_: Exception) {}
                    }
                } else {
                    Log.e(TAG, "TextToSpeech initialization failed with status: $status")
                    isTtsReady = false
                    pendingSpeechQueue.clear()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception creating TextToSpeech: ${e.message}")
            isTtsReady = false
            pendingSpeechQueue.clear()
        }
    }

    fun buildGreetingText(context: Context, rawTemplate: String): String {
        val sp = context.getSharedPreferences("dd_car_browser", Context.MODE_PRIVATE)
        val spPrefs = context.getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE)

        val rawDriver = sp.getString("driver_name", null)?.trim()
            ?: spPrefs.getString("driver_name", null)?.trim()
        val driverName = if (!rawDriver.isNullOrBlank()) rawDriver else "Driver"

        val template = if (rawTemplate.isNotBlank()) rawTemplate else "Welcome back {name}. Have a safe drive."

        // Resolve current time
        val now = Calendar.getInstance()
        val is24 = android.text.format.DateFormat.is24HourFormat(context)
        val timeFormat = SimpleDateFormat(if (is24) "HH:mm" else "h:mm a", Locale.getDefault())
        val timeStr = timeFormat.format(now.time)

        // Resolve upcoming prayer info
        var prayerName = com.dashmate.dashmate.DashMateStateBridge.nextPrayerName.trim()
        if (prayerName.isBlank()) prayerName = "Subuh"
        var prayerTime = com.dashmate.dashmate.DashMateStateBridge.nextPrayerTime.trim()
        if (prayerTime.isBlank()) prayerTime = "05:49"

        try {
            val prayerData = PrayerTimesManager.getEnrichedPrayerData(context)
            val nextObj = prayerData.optJSONObject("next")
            if (nextObj != null) {
                val pName = nextObj.optString("name", "").trim()
                if (pName.isNotBlank()) prayerName = pName
                val pTime = nextObj.optString("time", "").trim()
                if (pTime.isNotBlank()) prayerTime = pTime
            }
        } catch (_: Exception) {}

        // Resolve rain alert from cached weather
        var rainStr = "No rain expected"
        try {
            val prefs = context.getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE)
            val cachedWeather = prefs.getString("dashmate_weather_cache", null)
            if (!cachedWeather.isNullOrBlank()) {
                val obj = org.json.JSONObject(cachedWeather)
                val rain = obj.optString("rain", "").trim()
                if (rain.isNotBlank() && rain != "null") {
                    rainStr = rain
                }
            }
        } catch (_: Exception) {}

        var resultText = template
            .replace("{name}", driverName)
            .replace("{prayer_name}", prayerName)
            .replace("{prayer_time}", prayerTime)
            .replace("{time}", timeStr)
            .replace("{rain}", rainStr)
            .replace(Regex("\\s+"), " ")
            .trim()

        if (resultText.isBlank()) {
            resultText = "Welcome back $driverName. Have a safe drive."
        }

        Log.d(TAG, "Built greeting text: '$resultText' (template was: '$rawTemplate')")
        return resultText
    }

    fun playGreeting(
        context: Context,
        rawTemplate: String,
        speed: Float = 1.0f,
        pitch: Float = 1.0f,
        volume: Float = 0.8f,
        isTestOnPhone: Boolean = false,
        onDone: (() -> Unit)? = null
    ) {
        val text = buildGreetingText(context, rawTemplate)

        getOrCreateTts(context) { engine ->
            try {
                engine.setSpeechRate(speed.coerceIn(0.5f, 2.0f))
                engine.setPitch(pitch.coerceIn(0.5f, 2.0f))

                if (!isTestOnPhone && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    val attrs = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                    engine.setAudioAttributes(attrs)
                }

                val safeVol = volume.coerceIn(0.1f, 1.0f)
                val params = Bundle().apply {
                    putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, safeVol)
                }

                Log.d(TAG, "Speaking greeting: '$text' (vol=$safeVol, speed=$speed, phone=$isTestOnPhone)")
                val speakRes = engine.speak(text, TextToSpeech.QUEUE_FLUSH, params, "welcome_greeting")
                if (speakRes != TextToSpeech.SUCCESS) {
                    Log.w(TAG, "tts.speak returned error code $speakRes, trying fallback with null params")
                    engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "welcome_fallback")
                }
                onDone?.invoke()
            } catch (e: Exception) {
                Log.e(TAG, "Error during TTS speak: ${e.message}")
                onDone?.invoke()
            }
        }
    }

    fun shutdown() {
        try {
            tts?.stop()
            tts?.shutdown()
            tts = null
            isTtsReady = false
            pendingSpeechQueue.clear()
        } catch (_: Exception) {}
    }
}
