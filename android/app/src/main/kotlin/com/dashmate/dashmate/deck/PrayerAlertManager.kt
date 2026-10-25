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
import java.util.Locale
import java.util.TimeZone
import kotlin.coroutines.resume

/**
 * Solat on the road.
 *  - Reminder N minutes before each fard prayer.
 *  - Alert at the prayer time.
 * In the car both are spoken through the car speakers (music ducks, then resumes);
 * on the phone alone they are normal notifications. Every alert has a
 * "Nearest masjid" button.
 */
object PrayerAlertManager {
    private const val TAG = "PrayerAlert"
    private const val PREFS = "DashMatePrefs"
    private const val KEY_AZAN = "solat_alert_azan"
    private const val KEY_REMIND = "solat_alert_remind"
    private const val KEY_MINUTES = "solat_alert_minutes"
    private const val CHANNEL_ID = "dashmate_solat"
    private const val NOTIF_ID = 3201
    const val ACTION_FIRE = "com.dashmate.dashmate.SOLAT_ALERT"
    const val ACTION_MASJID = "com.dashmate.dashmate.NEAREST_MASJID"
    private val FARD = setOf("Subuh", "Zohor", "Asar", "Maghrib", "Isyak")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    data class Settings(val azan: Boolean, val remind: Boolean, val minutes: Int)

    fun settings(ctx: Context): Settings {
        val sp = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return Settings(sp.getBoolean(KEY_AZAN, true), sp.getBoolean(KEY_REMIND, true), sp.getInt(KEY_MINUTES, 10))
    }

    fun saveSettings(ctx: Context, azan: Boolean, remind: Boolean, minutes: Int) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_AZAN, azan).putBoolean(KEY_REMIND, remind)
            .putInt(KEY_MINUTES, minutes.coerceIn(1, 60)).apply()
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
        if (!s.azan && !s.remind) return

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
                if (s.remind) add(at - s.minutes * 60_000L to "remind")
                if (s.azan) add(at to "azan")
            }
            for ((t, kind) in candidates) {
                if (t > now + 5_000 && (best == null || t < best.first)) best = Triple(t, name, kind)
            }
        }
        val target = best ?: run {
            // Nothing left today: wake shortly after midnight to load tomorrow's times.
            val cal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kuala_Lumpur")).apply {
                add(Calendar.DAY_OF_YEAR, 1); set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 5); set(Calendar.SECOND, 0)
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
            Log.i(TAG, "Next solat alert: ${target.third} ${target.second} at ${java.util.Date(target.first)}")
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.first, fire)
        }
    }

    private fun firePendingIntent(ctx: Context, t: Triple<Long, String, String>?): PendingIntent {
        val i = Intent(ctx, PrayerAlertReceiver::class.java).setAction(ACTION_FIRE)
        if (t != null) i.putExtra("epoch", t.first).putExtra("name", t.second).putExtra("kind", t.third)
        return PendingIntent.getBroadcast(ctx, 0, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    suspend fun fire(ctx: Context, name: String, kind: String) {
        if (kind == "reschedule" || name.isBlank()) return
        val s = settings(ctx)
        val malay = try { LocalizationManager.getLanguage(ctx).startsWith("ms") } catch (e: Throwable) { false }
        val text = when (kind) {
            "remind" -> if (malay) "Waktu $name dalam ${s.minutes} minit." else "$name in ${s.minutes} minutes."
            else -> if (malay) "Telah masuk waktu $name." else "It is now time for $name prayer."
        }
        showNotification(ctx, name, text)
        if (isCarConnected(ctx)) {
            withTimeoutOrNull(25_000L) {
                suspendCancellableCoroutine<Unit> { cont ->
                    Handler(Looper.getMainLooper()).post {
                        speakInCar(ctx, text, chime = kind == "azan") { if (cont.isActive) cont.resume(Unit) }
                    }
                }
            }
        }
    }

    private suspend fun isCarConnected(ctx: Context): Boolean = withContext(Dispatchers.Main) {
        withTimeoutOrNull(3_000L) {
            suspendCancellableCoroutine { cont ->
                val live = CarConnection(ctx).type
                lateinit var obs: Observer<Int>
                obs = Observer { type ->
                    live.removeObserver(obs)
                    if (cont.isActive) cont.resume(type != CarConnection.CONNECTION_TYPE_NOT_CONNECTED)
                }
                live.observeForever(obs)
                cont.invokeOnCancellation { Handler(Looper.getMainLooper()).post { live.removeObserver(obs) } }
            }
        } ?: false
    }

    private fun showNotification(ctx: Context, name: String, text: String) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Prayer alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Reminders before and at each prayer time"
                }
            )
        }
        val masjid = PendingIntent.getBroadcast(
            ctx, 7, Intent(ctx, PrayerAlertReceiver::class.java).setAction(ACTION_MASJID),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val n = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(name)
            .setContentText(text)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .addAction(0, "Nearest masjid", masjid)
            .build()
        try { nm.notify(NOTIF_ID, n) } catch (e: SecurityException) { Log.w(TAG, "No notification permission") }
    }

    private var tts: TextToSpeech? = null

    /** Chime (optional) + spoken text on the navigation-guidance stream, ducking the music. */
    private fun speakInCar(ctx: Context, text: String, chime: Boolean, onFinished: () -> Unit) {
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        val focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            .setAudioAttributes(attrs).build()
        am.requestAudioFocus(focus)
        val release = {
            try { am.abandonAudioFocusRequest(focus) } catch (_: Exception) {}
            onFinished()
        }

        fun speak() {
            val engine = tts
            if (engine == null) {
                tts = TextToSpeech(ctx.applicationContext) { status ->
                    if (status == TextToSpeech.SUCCESS) speak() else release()
                }
                return
            }
            val ms = Locale("ms", "MY")
            val malay = text.startsWith("Waktu") || text.startsWith("Telah")
            engine.language = if (malay && engine.isLanguageAvailable(ms) >= TextToSpeech.LANG_AVAILABLE) ms else Locale.UK
            engine.setAudioAttributes(attrs)
            engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(id: String?) {}
                override fun onDone(id: String?) { release() }
                @Deprecated("Deprecated in Java")
                override fun onError(id: String?) { release() }
            })
            engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "solat")
        }

        if (!chime) { speak(); return }
        try {
            val afd = ctx.assets.openFd("dd_welcome_chime.wav")
            MediaPlayer().apply {
                setAudioAttributes(attrs)
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                setOnCompletionListener { it.release(); speak() }
                setOnErrorListener { mp, _, _ -> mp.release(); speak(); true }
                prepare()
                start()
            }
        } catch (e: Exception) {
            speak()
        }
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
                PrayerAlertManager.fire(app, intent.getStringExtra("name") ?: "", intent.getStringExtra("kind") ?: "")
                PrayerAlertManager.schedule(app)
            } catch (e: Throwable) {
                Log.w("PrayerAlert", "Alert failed: ${e.message}")
            } finally {
                pending.finish()
            }
        }
    }
}
