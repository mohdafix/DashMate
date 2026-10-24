package com.dashmate.dashmate

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import android.view.KeyEvent
import androidx.core.content.ContextCompat
import com.dashmate.dashmate.deck.CalendarManager
import com.dashmate.dashmate.deck.LocalizationManager
import com.dashmate.dashmate.deck.LyricsFetcher
import com.dashmate.dashmate.deck.ParkingManager
import com.dashmate.dashmate.deck.PrayerTimesManager
import com.dashmate.dashmate.deck.WeatherManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest

class MainActivity : FlutterActivity() {

    private val CHANNEL_LEGACY = "com.dashmate.dashmate/channel"
    private val CH_CAR_BROWSER = "drivedeck/car_browser"
    private val CH_CAR_STATE = "drivedeck/car_state"
    private val CH_NOW_PLAYING = "drivedeck/now_playing"
    private val CH_MEDIA_CONTROL = "drivedeck/media_control"
    private val CH_MEDIA_STORE = "drivedeck/media_store"
    private val CH_CALENDAR = "drivedeck/calendar"
    private val CH_PERMISSIONS = "drivedeck/permissions"
    private val CH_WELCOME = "drivedeck/welcome"

    private val PREFS_BROWSER = "dd_car_browser"

    private val scope = CoroutineScope(Dispatchers.Main)
    private var flutterChannel: MethodChannel? = null
    private var carStateEventSink: EventChannel.EventSink? = null
    private var nowPlayingEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // 1. Legacy DashMate Channel for existing widgets & screens
        val legacyChan = MethodChannel(messenger, CHANNEL_LEGACY)
        flutterChannel = legacyChan

        // 2. AutoDeck Platform Channels
        val browserChan = MethodChannel(messenger, CH_CAR_BROWSER)
        val carStateChan = MethodChannel(messenger, CH_CAR_STATE)
        val mediaControlChan = MethodChannel(messenger, CH_MEDIA_CONTROL)
        val mediaStoreChan = MethodChannel(messenger, CH_MEDIA_STORE)
        val calendarChan = MethodChannel(messenger, CH_CALENDAR)
        val permissionsChan = MethodChannel(messenger, CH_PERMISSIONS)
        val welcomeChan = MethodChannel(messenger, CH_WELCOME)

        // EventChannels
        EventChannel(messenger, CH_CAR_STATE + "/stream").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                carStateEventSink = events
                events?.success(mapOf(
                    "connected" to true,
                    "connectionType" to "android_auto",
                    "carApiLevel" to 7,
                    "scr_w" to 1190,
                    "scr_h" to 480,
                    "scr_dpi" to 160
                ))
            }
            override fun onCancel(arguments: Any?) {
                carStateEventSink = null
            }
        })

        EventChannel(messenger, CH_NOW_PLAYING).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                nowPlayingEventSink = events
                events?.success(mapOf(
                    "title" to DashMateStateBridge.songTitle,
                    "artist" to DashMateStateBridge.songArtist,
                    "playing" to DashMateStateBridge.isPlaying
                ))
            }
            override fun onCancel(arguments: Any?) {
                nowPlayingEventSink = null
            }
        })

        DashMateStateBridge.addListener(object : DashMateStateBridge.StateListener {
            override fun onStateUpdated(stateJson: String) {
                runOnUiThread {
                    flutterChannel?.invokeMethod("onStateUpdate", stateJson)
                    nowPlayingEventSink?.success(mapOf(
                        "title" to DashMateStateBridge.songTitle,
                        "artist" to DashMateStateBridge.songArtist,
                        "playing" to DashMateStateBridge.isPlaying
                    ))
                }
            }
            override fun onSwitchPage(page: String) {}
            override fun onExecuteScript(script: String) {}
        })

        // Handler for drivedeck/car_browser
        browserChan.setMethodCallHandler { call, result ->
            val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
            when (call.method) {
                "setTheme" -> {
                    val mode = call.argument<String>("mode") ?: "dark"
                    sp.edit().putString("theme", mode).apply()
                    result.success(true)
                }
                "setCarTemplate" -> {
                    val tmpl = call.argument<String>("template") ?: "nav"
                    sp.edit().putString("car_template", tmpl).apply()
                    result.success(true)
                }
                "setShowPrayer" -> {
                    val show = call.argument<Boolean>("show_prayer") ?: true
                    sp.edit().putBoolean("show_prayer", show).apply()
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "setMenuItems" -> {
                    val items = call.argument<List<String>>("items") ?: listOf("home", "lyrics", "prayer", "browse", "parking")
                    sp.edit().putString("menu_items", JSONArray(items).toString()).apply()
                    result.success(true)
                }
                "setNavStyle" -> {
                    val opacity = call.argument<Double>("opacity") ?: 1.0
                    val color = call.argument<String>("color") ?: "#5EF2D6"
                    sp.edit().putFloat("nav_opacity", opacity.toFloat()).putString("nav_color", color).apply()
                    result.success(true)
                }
                "setNavScale" -> {
                    val scale = call.argument<Double>("scale") ?: 1.0
                    sp.edit().putFloat("nav_scale", scale.toFloat()).apply()
                    result.success(true)
                }
                "getBookmarks" -> {
                    val bm = sp.getString("bookmarks", "[]")
                    result.success(bm)
                }
                "setBookmarks" -> {
                    val bm = call.argument<String>("bookmarks") ?: "[]"
                    sp.edit().putString("bookmarks", bm).apply()
                    result.success(true)
                }
                "clearBrowserData" -> {
                    android.webkit.WebStorage.getInstance().deleteAllData()
                    android.webkit.CookieManager.getInstance().removeAllCookies(null)
                    result.success(true)
                }
                "deviceId" -> {
                    val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "dashmate"
                    val sha = MessageDigest.getInstance("SHA-256").digest(androidId.toByteArray())
                    val hex = sha.joinToString("") { "%02x".format(it) }
                    result.success("autodeck-trial:$hex")
                }
                "carInfo" -> {
                    result.success(mapOf(
                        "scr_name" to "Google Desktop Head Unit",
                        "scr_w" to 1190,
                        "scr_h" to 480,
                        "scr_dpi" to 160
                    ))
                }
                "sendToCar" -> {
                    val url = call.argument<String>("url") ?: ""
                    if (url.isNotBlank()) {
                        DashMateStateBridge.setPage("browse")
                        DashMateStateBridge.executeScript("window.location.href = '$url';")
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Handler for drivedeck/media_control
        mediaControlChan.setMethodCallHandler { call, result ->
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            when (call.method) {
                "playPause", "toggle" -> {
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
                    DashMateStateBridge.isPlaying = !DashMateStateBridge.isPlaying
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "next" -> {
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_NEXT))
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_NEXT))
                    result.success(true)
                }
                "previous" -> {
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Handler for drivedeck/calendar
        calendarChan.setMethodCallHandler { call, result ->
            when (call.method) {
                "getEvents" -> {
                    val calObj = CalendarManager.getUpcomingEvents(this)
                    result.success(calObj.toString())
                }
                else -> result.notImplemented()
            }
        }

        // Handler for drivedeck/permissions
        permissionsChan.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkNotifications" -> {
                    val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")?.contains(packageName) == true
                    result.success(enabled)
                }
                "openNotificationSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
                }
                "checkCalendar" -> {
                    val granted = ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                else -> result.notImplemented()
            }
        }

        // Handler for drivedeck/welcome
        welcomeChan.setMethodCallHandler { call, result ->
            when (call.method) {
                "playChime" -> {
                    DashMateStateBridge.playWelcomeChime(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Handler for com.dashmate.dashmate/channel (Legacy Flutter Methods)
        legacyChan.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateSpeed" -> {
                    val speed = call.argument<Double>("speed") ?: 0.0
                    DashMateStateBridge.currentSpeed = speed.toFloat()
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "setPrayerZone" -> {
                    val zone = call.argument<String>("zone") ?: "WLY01"
                    PrayerTimesManager.setSelectedZone(this, zone)
                    scope.launch {
                        val prayerObj = PrayerTimesManager.getPrayerData(this@MainActivity)
                        val weatherObj = WeatherManager.getWeatherData(this@MainActivity)
                        DashMateStateBridge.notifyStateChanged(this@MainActivity)
                        result.success(prayerObj.toString())
                    }
                }
                "getPrayerData" -> {
                    scope.launch {
                        val prayerObj = PrayerTimesManager.getPrayerData(this@MainActivity)
                        result.success(prayerObj.toString())
                    }
                }
                "getWeatherData" -> {
                    scope.launch {
                        val weatherObj = WeatherManager.getWeatherData(this@MainActivity)
                        result.success(weatherObj.toString())
                    }
                }
                "getAirQuality" -> {
                    scope.launch {
                        val airObj = WeatherManager.getAirQuality(this@MainActivity)
                        result.success(airObj.toString())
                    }
                }
                "getRainRadar" -> {
                    scope.launch {
                        val radarObj = WeatherManager.getRainRadar(this@MainActivity)
                        result.success(radarObj?.toString())
                    }
                }
                "getCalendarEvents" -> {
                    val calObj = CalendarManager.getUpcomingEvents(this)
                    result.success(calObj.toString())
                }
                "saveParkingSpot" -> {
                    val lat = call.argument<Double>("lat") ?: 3.1390
                    val lng = call.argument<Double>("lng") ?: 101.6869
                    val bay = call.argument<String>("bay") ?: ""
                    val level = call.argument<String>("level") ?: ""
                    val notes = call.argument<String>("notes") ?: ""
                    ParkingManager.saveSpot(this, lat, lng, bay, level, notes)
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "getParkingSpot" -> {
                    val spot = ParkingManager.getSpot(this)
                    if (spot != null) {
                        val map = mapOf(
                            "lat" to spot.lat,
                            "lng" to spot.lng,
                            "bay" to spot.bay,
                            "level" to spot.level,
                            "notes" to spot.notes,
                            "timestamp" to spot.timestamp
                        )
                        result.success(JSONObject(map).toString())
                    } else {
                        result.success(null)
                    }
                }
                "clearParkingSpot" -> {
                    ParkingManager.clearSpot(this)
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "navigateParking" -> {
                    val spot = ParkingManager.getSpot(this)
                    if (spot != null) {
                        ParkingManager.navigateBack(this)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "fetchLyrics" -> {
                    val title = call.argument<String>("title") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    scope.launch {
                        val lrc = LyricsFetcher.fetchLyrics(artist, title, this@MainActivity)
                        val lrcText = lrc.joinToString("\n") { "[${it.timeMs}] ${it.text}" }
                        result.success(lrcText)
                    }
                }
                "setLanguage" -> {
                    val lang = call.argument<String>("lang") ?: "en"
                    LocalizationManager.setLanguage(this, lang)
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "getLanguage" -> {
                    result.success(LocalizationManager.getLanguage(this))
                }
                "setPage" -> {
                    val page = call.argument<String>("page") ?: "home"
                    DashMateStateBridge.setPage(page)
                    result.success(true)
                }
                "setFont" -> {
                    val font = call.argument<String>("font") ?: "orbitron"
                    DashMateStateBridge.activeFont = font
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "setBgMode" -> {
                    val mode = call.argument<String>("mode") ?: "cover"
                    val url = call.argument<String>("url") ?: ""
                    DashMateStateBridge.bgMode = mode
                    DashMateStateBridge.bgUrl = url
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "updateMusic" -> {
                    val title = call.argument<String>("title") ?: "Unknown"
                    val artist = call.argument<String>("artist") ?: "Unknown"
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    DashMateStateBridge.updateMediaInfo(this, title, artist, isPlaying)
                    result.success(true)
                }
                "mediaPlayPause" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
                    DashMateStateBridge.isPlaying = !DashMateStateBridge.isPlaying
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "mediaNext" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_NEXT))
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_NEXT))
                    result.success(true)
                }
                "mediaPrevious" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
                    result.success(true)
                }
                "loadYoutube" -> {
                    val videoId = call.argument<String>("videoId") ?: ""
                    DashMateStateBridge.currentYoutubeId = videoId
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "openNotificationSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
                }
                "saveLayoutSettings" -> {
                    val layoutStr = call.argument<String>("layout")
                        ?: call.argument<String>("layoutJson")
                        ?: ""
                    if (layoutStr.isNotBlank()) {
                        getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                            .edit()
                            .putString("dashmate_layout", layoutStr)
                            .apply()
                        DashMateStateBridge.applyLayoutLive(layoutStr)
                        DashMateStateBridge.notifyStateChanged(this)
                    }
                    result.success(true)
                }
                "getLayoutSettings" -> {
                    val layoutStr = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                        .getString("dashmate_layout", null)
                    result.success(layoutStr)
                }
                "highlightWidget" -> {
                    val id = call.argument<String>("id") ?: ""
                    DashMateStateBridge.highlightWidget(id)
                    result.success(true)
                }
                "getState" -> {
                    result.success(DashMateStateBridge.buildStateJson(this))
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
