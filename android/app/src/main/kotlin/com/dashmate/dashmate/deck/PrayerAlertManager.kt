package com.dashmate.dashmate.deck

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import androidx.car.app.connection.CarConnection
import androidx.core.app.NotificationCompat
import androidx.lifecycle.Observer
import com.dashmate.dashmate.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.coroutines.resume

/**
 * Solat on the road & phone.
 *  - Reminder N minutes before each fard prayer.
 *  - Alert at the prayer time (Azan / TTS announcement).
 * In the car both are spoken through the car speakers (music ducks, then resumes);
 * on the phone alone they trigger sound, vibration, and notification.
 */
object PrayerAlertManager {
    private const val TAG = "PrayerAlert"
    private const val PREFS = "DashMatePrefs"
    private const val KEY_SHOW = "show_prayer"
    private const val KEY_AZAN_PRAYERS = "solat_azan_prayers"
    private const val KEY_MINUTES = "solat_alert_minutes"
    private const val CHANNEL_ID = "dashmate_solat"
    private const val NOTIF_ID = 3201

    const val ACTION_FIRE = "com.dashmate.dashmate.SOLAT_ALERT"
    const val ACTION_MASJID = "com.dashmate.dashmate.NEAREST_MASJID"

    val FARD = listOf("Subuh", "Zohor", "Asar", "Maghrib", "Isyak")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    data class Settings(
        val showPrayer: Boolean,
        val azanPrayers: Set<String>,
        val remindMinutes: Int // 0 means Off
    )

    fun settings(ctx: Context): Settings {
        val sp = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val show = sp.getBoolean(KEY_SHOW, true)
        val defaultPrayers = FARD.toSet()
        val azanPrayers = sp.getStringSet(KEY_AZAN_PRAYERS, null) ?: defaultPrayers
        val minutes = sp.getInt(KEY_MINUTES, 0)
        return Settings(show, azanPrayers, minutes)
    }

    fun saveSettings(ctx: Context, showPrayer: Boolean, azanPrayers: Set<String>, minutes: Int) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_SHOW, showPrayer)
            .putStringSet(KEY_AZAN_PRAYERS, azanPrayers)
            .putInt(KEY_MINUTES, minutes.coerceIn(0, 60))
            .apply()
        scheduleAsync(ctx)
    }

    fun scheduleAsync(ctx: Context) {
        val app = ctx.applicationContext
        scope.launch { schedule(app) }
    }

    /** Schedules the single next alert; the receiver reschedules after it fires. */
    suspend fun schedule(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = firePendingIntent(ctx, null)
        am.cancel(pi)

        val s = settings(ctx)
        if (!s.showPrayer || (s.azanPrayers.isEmpty() && s.remindMinutes <= 0)) {
            Log.i(TAG, "Prayer alerts disabled or no prayers selected.")
            return
        }

        val data = try { PrayerTimesManager.getPrayerData(ctx) } catch (e: Throwable) { null } ?: return
        val times = data.optJSONArray("times") ?: return
        val now = System.currentTimeMillis()
        var best: Triple<Long, String, String>? = null // epoch, name, kind

        for (i in 0 until times.length()) {
            val p = times.optJSONObject(i) ?: continue
            val name = p.optString("name")
            if (name !in FARD) continue
            val at = p.optLong("epochMs")

            val candidates = buildList {
                if (s.remindMinutes > 0) add(at - (s.remindMinutes * 60_000L) to "remind")
                if (name in s.azanPrayers) add(at to "azan")
            }

            for ((t, kind) in candidates) {
                if (t > now + 3_000 && (best == null || t < best.first)) {
                    best = Triple(t, name, kind)
                }
            }
        }

        val target = best ?: run {
            // Nothing left today: wake shortly after midnight to load tomorrow's times.
            val cal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kuala_Lumpur")).apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 5)
                set(Calendar.SECOND, 0)
            }
            Triple(cal.timeInMillis, "", "reschedule")
        }

        val fire = firePendingIntent(ctx, target)
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.first, fire)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.first, fire)
            }
            Log.i(TAG, "Next solat alert scheduled: ${target.third} ${target.second} at ${Date(target.first)}")
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.first, fire)
        }
    }

    private fun firePendingIntent(ctx: Context, t: Triple<Long, String, String>?): PendingIntent {
        val i = Intent(ctx, PrayerAlertReceiver::class.java).setAction(ACTION_FIRE)
        if (t != null) {
            i.putExtra("epoch", t.first).putExtra("name", t.second).putExtra("kind", t.third)
        }
        return PendingIntent.getBroadcast(ctx, 0, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    suspend fun fire(ctx: Context, name: String, kind: String) {
        if (kind == "reschedule" || name.isBlank()) return
        val s = settings(ctx)
        val malay = try { LocalizationManager.getLanguage(ctx).startsWith("ms") } catch (e: Throwable) { true }
        val text = when (kind) {
            "remind" -> if (malay) "Waktu $name dalam ${s.remindMinutes} minit." else "$name in ${s.remindMinutes} minutes."
            else -> if (malay) "Telah masuk waktu $name." else "It is now time for $name prayer."
        }

        showNotification(ctx, name, text)

        val connected = isCarConnected(ctx)
        withContext(Dispatchers.Main) {
            speakAlert(ctx, text, isCar = connected, isAzan = (kind == "azan"))
        }
    }

    private suspend fun isCarConnected(ctx: Context): Boolean = withContext(Dispatchers.Main) {
        withTimeoutOrNull(2_000L) {
            suspendCancellableCoroutine { cont ->
                try {
                    val live = CarConnection(ctx).type
                    lateinit var obs: Observer<Int>
                    obs = Observer { type ->
                        try { live.removeObserver(obs) } catch (_: Exception) {}
                        if (cont.isActive) cont.resume(type != CarConnection.CONNECTION_TYPE_NOT_CONNECTED)
                    }
                    live.observeForever(obs)
                    cont.invokeOnCancellation {
                        Handler(Looper.getMainLooper()).post {
                            try { live.removeObserver(obs) } catch (_: Exception) {}
                        }
                    }
                } catch (_: Exception) {
                    if (cont.isActive) cont.resume(false)
                }
            }
        } ?: false
    }

    private fun showNotification(ctx: Context, name: String, text: String) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .build()

            val channel = NotificationChannel(CHANNEL_ID, "Prayer Alerts & Azan", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Reminders before and at each prayer time"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 400, 200, 400)
                setSound(soundUri, audioAttributes)
            }
            nm.createNotificationChannel(channel)
        }

        val masjid = PendingIntent.getBroadcast(
            ctx, 7, Intent(ctx, PrayerAlertReceiver::class.java).setAction(ACTION_MASJID),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val n = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("🕌 $name")
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setSound(soundUri)
            .setVibrate(longArrayOf(0, 400, 200, 400))
            .setAutoCancel(true)
            .addAction(0, "Nearest Masjid", masjid)
            .build()

        try {
            nm.notify(NOTIF_ID, n)
        } catch (e: SecurityException) {
            Log.w(TAG, "Notification permission not granted: ${e.message}")
        }
    }

    private var tts: TextToSpeech? = null

    /** Spoken alert on audio stream: ducks music if in car, plays chime + TTS. */
    private fun speakAlert(ctx: Context, text: String, isCar: Boolean, isAzan: Boolean) {
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val usage = if (isCar) AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE else AudioAttributes.USAGE_NOTIFICATION
        val attrs = AudioAttributes.Builder()
            .setUsage(usage)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()

        val focusReq = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attrs)
                .build()
        } else null

        if (focusReq != null) {
            am.requestAudioFocus(focusReq)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(null, AudioManager.STREAM_NOTIFICATION, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        }

        val release: () -> Unit = {
            try {
                if (focusReq != null) {
                    am.abandonAudioFocusRequest(focusReq)
                } else {
                    @Suppress("DEPRECATION")
                    am.abandonAudioFocus(null)
                }
            } catch (_: Exception) {}
        }

        fun playTts() {
            if (tts == null) {
                tts = TextToSpeech(ctx.applicationContext) { status ->
                    if (status == TextToSpeech.SUCCESS) {
                        doSpeak(ctx, text, attrs, release)
                    } else {
                        release()
                    }
                }
            } else {
                doSpeak(ctx, text, attrs, release)
            }
        }

        if (isAzan) {
            try {
                val afd = ctx.assets.openFd("dd_welcome_chime.wav")
                MediaPlayer().apply {
                    setAudioAttributes(attrs)
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                    setOnCompletionListener {
                        it.release()
                        playTts()
                    }
                    setOnErrorListener { mp, _, _ ->
                        mp.release()
                        playTts()
                        true
                    }
                    prepare()
                    start()
                }
            } catch (_: Exception) {
                playTts()
            }
        } else {
            playTts()
        }
    }

    private fun doSpeak(ctx: Context, text: String, attrs: AudioAttributes, onFinished: () -> Unit) {
        val engine = tts ?: return onFinished()
        val ms = Locale("ms", "MY")
        val malay = text.startsWith("Waktu") || text.startsWith("Telah")
        engine.language = if (malay && engine.isLanguageAvailable(ms) >= TextToSpeech.LANG_AVAILABLE) ms else Locale.UK
        engine.setAudioAttributes(attrs)
        engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) {}
            override fun onDone(id: String?) { onFinished() }
            @Deprecated("Deprecated in Java")
            override fun onError(id: String?) { onFinished() }
        })
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "solat_alert")
    }
}

class PrayerAlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        when (intent.action) {
            PrayerAlertManager.ACTION_MASJID -> {
                (app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(3201)
                com.dashmate.dashmate.CarNav.toNearest(app, NearbyFinder.Kind.MASJID)
                return
            }
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_TIME_CHANGED -> {
                PrayerAlertManager.scheduleAsync(app)
                return
            }
        }
        val pending = goAsync()
        CoroutineScope(Dispatchers.Default).launch {
            try {
                val name = intent.getStringExtra("name") ?: ""
                val kind = intent.getStringExtra("kind") ?: ""
                PrayerAlertManager.fire(app, name, kind)
                PrayerAlertManager.schedule(app)
            } catch (e: Throwable) {
                Log.w("PrayerAlert", "Alert failed: ${e.message}")
            } finally {
                pending.finish()
            }
        }
    }
}
