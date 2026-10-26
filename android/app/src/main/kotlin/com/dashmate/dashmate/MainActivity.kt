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
import com.dashmate.dashmate.deck.FuelManager
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
    private var tts: android.speech.tts.TextToSpeech? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DashMateTheme.init(this)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // 1. Legacy DashMate Channel for existing widgets & screens
        val legacyChan = MethodChannel(messenger, CHANNEL_LEGACY)
        flutterChannel = legacyChan

        try {
            tts = android.speech.tts.TextToSpeech(this) { status ->
                if (status == android.speech.tts.TextToSpeech.SUCCESS) {
                    tts?.language = java.util.Locale.getDefault()
                }
            }
        } catch (_: Exception) {}

        // Start DashMateMediaCardService for Android Auto Coolwalk side-by-side card
        try {
            val cardIntent = Intent(this, DashMateMediaCardService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(cardIntent)
            } else {
                startService(cardIntent)
            }
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "Failed starting DashMateMediaCardService: ${e.message}")
        }

        // Sync live fuel prices from data.gov.my
        scope.launch {
            try {
                FuelManager.syncFuelPrices(this@MainActivity)
            } catch (_: Exception) {}
        }

        // Schedule prayer times & azan alerts
        try {
            com.dashmate.dashmate.deck.PrayerAlertManager.scheduleAsync(this)
        } catch (_: Exception) {}

        // 2. Platform Channels
        val browserChan = MethodChannel(messenger, CH_CAR_BROWSER)
        val carStateChan = MethodChannel(messenger, CH_CAR_STATE)
        carStateChan.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateFuel" -> {
                    val fuelMap = call.argument<Map<String, Any>>("fuel")
                    if (fuelMap != null) {
                        FuelManager.cachedFuelObj = JSONObject(fuelMap)
                        DashMateStateBridge.notifyStateChanged(this)
                    }
                    result.success(true)
                }
                "updateWeather" -> {
                    result.success(true)
                }
                "updateForecast" -> {
                    val fMap = call.argument<Map<String, Any>>("forecast")
                    if (fMap != null) {
                        val days = fMap["days"] as? List<Map<String, Any>>
                        if (days != null) {
                            DashMateStateBridge.customForecastArr = JSONArray(days.map { JSONObject(it) })
                            DashMateStateBridge.notifyStateChanged(this)
                        }
                    }
                    result.success(true)
                }
                "updateAir" -> {
                    val aMap = call.argument<Map<String, Any>>("air")
                    if (aMap != null) {
                        DashMateStateBridge.customAirObj = JSONObject(aMap)
                        DashMateStateBridge.notifyStateChanged(this)
                    }
                    result.success(true)
                }
                "updateRadar" -> {
                    val rMap = call.argument<Map<String, Any>>("radar")
                    if (rMap != null) {
                        DashMateStateBridge.customRadarObj = JSONObject(rMap)
                        DashMateStateBridge.notifyStateChanged(this)
                    }
                    result.success(true)
                }
                "updateEv" -> {
                    val evMap = call.argument<Map<String, Any>>("ev")
                    if (evMap != null) {
                        val lat = (evMap["lat"] as? Number)?.toDouble() ?: 3.1390
                        val lng = (evMap["lng"] as? Number)?.toDouble() ?: 101.6869
                        val items = evMap["items"] as? List<Map<String, Any>> ?: emptyList()
                        val evObj = JSONObject().apply {
                            put("lat", lat)
                            put("lng", lng)
                            val arr = JSONArray()
                            for (item in items) {
                                val itObj = JSONObject().apply {
                                    put("name", item["title"] ?: item["name"] ?: "EV Station")
                                    val plugs = item["plugs"]
                                    if (plugs is List<*>) {
                                        put("plugs", plugs.joinToString(", "))
                                    } else {
                                        put("plugs", plugs?.toString() ?: "Type 2")
                                    }
                                    put("lat", (item["lat"] as? Number)?.toDouble() ?: lat)
                                    put("lng", (item["lng"] as? Number)?.toDouble() ?: lng)
                                    put("status", "up")
                                }
                                arr.put(itObj)
                            }
                            put("items", arr)
                        }
                        DashMateStateBridge.customEvObj = evObj
                        DashMateStateBridge.notifyStateChanged(this)
                    }
                    result.success(true)
                }
                "updateScores" -> {
                    val sMap = call.argument<Map<String, Any>>("scores")
                    if (sMap != null) {
                        val matches = sMap["matches"] as? List<Map<String, Any>>
                        if (matches != null) {
                            val arr = JSONArray()
                            for (m in matches) {
                                val obj = JSONObject().apply {
                                    put("home", m["home"] ?: "")
                                    put("away", m["away"] ?: "")
                                    put("score", "${m["homeScore"] ?: 0} - ${m["awayScore"] ?: 0}")
                                    put("time", m["status"] ?: "")
                                    put("status", m["status"] ?: "")
                                    put("state", if (m["status"] == "IN_PLAY") "in" else "post")
                                }
                                arr.put(obj)
                            }
                            DashMateStateBridge.customScoresArr = arr
                            DashMateStateBridge.notifyStateChanged(this)
                        }
                    }
                    result.success(true)
                }
                "updateLayout" -> {
                    val layout = call.argument<String>("layout") ?: ""
                    if (layout.isNotBlank()) {
                        getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE).edit().putString("dashmate_layout", layout).putString("car_layouts_current", layout).apply()
                        getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE).edit().putString("dashmate_layout", layout).putString("car_layouts_current", layout).apply()
                        DashMateStateBridge.cachedLayoutJson = layout
                        DashMateStateBridge.applyLayoutLive(layout)
                        DashMateStateBridge.notifyStateChanged(this)
                    }
                    result.success(true)
                }
                "setCustomPageMode" -> {
                    val mode = call.argument<String>("mode") ?: "weather"
                    DashMateStateBridge.customPageMode = mode
                    getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE).edit().putString("customPage", mode).apply()
                    getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE).edit().putString("customPage", mode).apply()
                    DashMateStateBridge.setPage("custom:$mode")
                    result.success(true)
                }
                "getThemeMode" -> {
                    result.success(DashMateTheme.getThemeMode(this))
                }
                "requestCalendarPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        requestPermissions(arrayOf(android.Manifest.permission.READ_CALENDAR), 101)
                    }
                    result.success(true)
                }
                "checkCalendar" -> {
                    val granted = ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "setThemeMode" -> {
                    val mode = call.argument<String>("mode") ?: DashMateTheme.MODE_AUTO
                    DashMateTheme.setThemeMode(this, mode)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        val nowPlayingChan = MethodChannel(messenger, CH_NOW_PLAYING)
        nowPlayingChan.setMethodCallHandler { call, result ->
            when (call.method) {
                "getState" -> {
                    result.success(mapOf(
                        "title" to DashMateStateBridge.songTitle,
                        "artist" to DashMateStateBridge.songArtist,
                        "album" to DashMateStateBridge.songArtist,
                        "coverUrl" to DashMateStateBridge.songCoverUrl,
                        "playing" to DashMateStateBridge.isPlaying,
                        "durationMs" to DashMateStateBridge.playbackDurationMs,
                        "positionMs" to DashMateStateBridge.playbackPositionMs,
                        "speed" to 1.0,
                        "app" to DashMateStateBridge.songApp,
                        "currentLyric" to DashMateStateBridge.getCurrentLyricLine()
                    ))
                }
                "play" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY))
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PLAY))
                    DashMateStateBridge.isPlaying = true
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "pause" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE))
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PAUSE))
                    DashMateStateBridge.isPlaying = false
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "skipNext" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_NEXT))
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_NEXT))
                    result.success(true)
                }
                "skipPrevious" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
                    am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
                    result.success(true)
                }
                "isNotificationAccessGranted" -> {
                    val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")?.contains(packageName) == true
                    result.success(enabled)
                }
                "openNotificationAccessSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
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
                    val mapped = if (mode == "light") DashMateTheme.MODE_DAY else DashMateTheme.MODE_NIGHT
                    DashMateTheme.setThemeMode(this, mapped)
                    result.success(true)
                }
                "getThemeMode" -> {
                    result.success(DashMateTheme.getThemeMode(this))
                }
                "requestCalendarPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        requestPermissions(arrayOf(android.Manifest.permission.READ_CALENDAR), 101)
                    }
                    result.success(true)
                }
                "checkCalendar" -> {
                    val granted = ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "setThemeMode" -> {
                    val mode = call.argument<String>("mode") ?: DashMateTheme.MODE_AUTO
                    DashMateTheme.setThemeMode(this, mode)
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
                    val items = call.argument<List<String>>("items") ?: listOf("home", "lyrics", "prayer", "radio", "custom", "web")
                    val json = JSONArray(items).toString()
                    sp.edit().putString("menu_items", json).apply()
                    getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE).edit().putString("menu_items", json).apply()
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "getMenuItems" -> {
                    val json = sp.getString("menu_items", null)
                        ?: getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE).getString("menu_items", null)
                        ?: "[\"home\",\"lyrics\",\"prayer\",\"radio\",\"custom\",\"web\"]"
                    try {
                        val arr = JSONArray(json)
                        val list = mutableListOf<String>()
                        for (i in 0 until arr.length()) {
                            list.add(arr.getString(i))
                        }
                        result.success(list)
                    } catch (_: Exception) {
                        result.success(listOf("home", "lyrics", "prayer", "radio", "custom", "web"))
                    }
                }
                "setNavStyle" -> {
                    val opacity = call.argument<Double>("opacity") ?: 1.0
                    val color = call.argument<String>("color") ?: "#5EF2D6"
                    sp.edit().putFloat("nav_opacity", opacity.toFloat()).putString("nav_color", color).apply()
                    result.success(true)
                }
                "setNavScale" -> {
                    val scale = call.argument<Any>("scale")?.toString()?.toFloatOrNull() ?: 1.0f
                    val opacity = call.argument<Any>("opacity")?.toString()?.toFloatOrNull() ?: 0.92f
                    val colorIdx = call.argument<Int>("colorIndex") ?: 0
                    val position = call.argument<String>("position") ?: "top_left"
                    val autoCollapse = call.argument<Boolean>("autoCollapse") ?: true
                    sp.edit()
                        .putFloat("nav_scale", scale)
                        .putFloat("nav_opacity", opacity)
                        .putInt("nav_color_idx", colorIdx)
                        .putString("dock_position", position)
                        .putBoolean("dock_auto_collapse", autoCollapse)
                        .apply()
                    DashMateStateBridge.notifyStateChanged(this)
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
                    result.success("dashmate-pro:$hex")
                }
                "carInfo" -> {
                    result.success(mapOf(
                        "scr_name" to "Google Desktop Head Unit",
                        "scr_w" to 1190,
                        "scr_h" to 480,
                        "scr_dpi" to 160
                    ))
                }
                "sendToCar", "openUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    if (url.isNotBlank()) {
                        DashMateStateBridge.setPage("browse")
                        DashMateStateBridge.executeScript("window.location.href = '$url';")
                    }
                    result.success(true)
                }
                "setPage" -> {
                    val page = call.argument<String>("page") ?: "home"
                    DashMateStateBridge.setPage(page)
                    result.success(true)
                }
                "getCarCardMode" -> {
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    result.success(mapOf(
                        "show" to sp.getBoolean("car_card_show", true),
                        "mode" to sp.getString("car_card_mode", "Auto")
                    ))
                }
                "setCarCardMode" -> {
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    val show = call.argument<Boolean>("show") ?: true
                    val mode = call.argument<String>("mode") ?: "Auto"
                    sp.edit()
                        .putBoolean("car_card_show", show)
                        .putString("car_card_mode", mode)
                        .apply()
                    DashMateStateBridge.carCardMode = mode
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "setLayoutMode" -> {
                    val mode = call.argument<String>("mode") ?: "auto"
                    sp.edit().putString(DashMateStateBridge.LAYOUT_MODE_KEY, mode).apply()
                    getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE)
                        .edit().putString(DashMateStateBridge.LAYOUT_MODE_KEY, mode).apply()
                    DashMateStateBridge.notifyStateChanged(this)
                    DashMateStateBridge.executeScript("if (window.ddSetLayoutMode) window.ddSetLayoutMode('$mode');")
                    result.success(true)
                }
                "getLayoutMode" -> {
                    result.success(DashMateStateBridge.layoutMode(this))
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
                "getThemeMode" -> {
                    result.success(DashMateTheme.getThemeMode(this))
                }
                "requestCalendarPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        requestPermissions(arrayOf(android.Manifest.permission.READ_CALENDAR), 101)
                    }
                    result.success(true)
                }
                "checkCalendar" -> {
                    val granted = ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "setThemeMode" -> {
                    val mode = call.argument<String>("mode") ?: DashMateTheme.MODE_AUTO
                    DashMateTheme.setThemeMode(this, mode)
                    result.success(true)
                }
                "setPrayerZone" -> {
                    val zone = call.argument<String>("zone") ?: "WLY01"
                    PrayerTimesManager.setSelectedZone(this, zone)
                    com.dashmate.dashmate.deck.PrayerAlertManager.scheduleAsync(this)
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
                "getPrayerAlerts" -> {
                    val s = com.dashmate.dashmate.deck.PrayerAlertManager.settings(this)
                    result.success(mapOf(
                        "showPrayer" to s.showPrayer,
                        "azanPrayers" to s.azanPrayers.toList(),
                        "remindMinutes" to s.remindMinutes
                    ))
                }
                "setPrayerAlerts" -> {
                    val show = call.argument<Boolean>("showPrayer") ?: true
                    val azanList = call.argument<List<String>>("azanPrayers") ?: listOf("Subuh", "Zohor", "Asar", "Maghrib", "Isyak")
                    val minutes = call.argument<Int>("remindMinutes") ?: 0
                    com.dashmate.dashmate.deck.PrayerAlertManager.saveSettings(this, show, azanList.toSet(), minutes)
                    result.success(true)
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
                "updateFuel" -> {
                    val fuelMap = call.argument<Map<String, Any>>("fuel")
                    if (fuelMap != null) {
                        FuelManager.cachedFuelObj = JSONObject(fuelMap)
                        DashMateStateBridge.notifyStateChanged(this)
                    }
                    result.success(true)
                }
                "getFuelData" -> {
                    scope.launch {
                        val fuel = FuelManager.syncFuelPrices(this@MainActivity)
                        result.success(fuel.toString())
                    }
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
                "setPage", "setCarPage" -> {
                    val page = call.argument<String>("page") ?: "home"
                    DashMateStateBridge.setPage(page)
                    result.success(true)
                }
                "setCustomPageMode" -> {
                    val mode = call.argument<String>("mode")
                        ?: call.argument<String>("page")
                        ?: "weather"
                    DashMateStateBridge.customPageMode = mode
                    getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                        .edit().putString("customPage", mode).apply()
                    getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE)
                        .edit().putString("customPage", mode).apply()
                    DashMateStateBridge.setPage("custom:$mode")
                    result.success(true)
                }
                "getThemeMode" -> {
                    result.success(DashMateTheme.getThemeMode(this))
                }
                "requestCalendarPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        requestPermissions(arrayOf(android.Manifest.permission.READ_CALENDAR), 101)
                    }
                    result.success(true)
                }
                "checkCalendar" -> {
                    val granted = ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "setThemeMode" -> {
                    val mode = call.argument<String>("mode") ?: DashMateTheme.MODE_AUTO
                    DashMateTheme.setThemeMode(this, mode)
                    result.success(true)
                }
                "getCustomPageMode" -> {
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    val mode = sp.getString("customPage", null)
                        ?: getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE).getString("customPage", null)
                        ?: DashMateStateBridge.customPageMode
                    result.success(mode)
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
                    val tall = call.argument<Boolean>("tall") ?: (DashMateStateBridge.layoutMode(this) == "tall")
                    val key = if (tall) "dashmate_layout_portrait" else "dashmate_layout"
                    if (layoutStr.isNotBlank()) {
                        getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                            .edit()
                            .putString(key, layoutStr)
                            .putString("dashmate_layout", layoutStr)
                            .putString("car_layouts_current", layoutStr)
                            .apply()
                        getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE)
                            .edit()
                            .putString(key, layoutStr)
                            .putString("dashmate_layout", layoutStr)
                            .putString("car_layouts_current", layoutStr)
                            .apply()
                        DashMateStateBridge.cachedLayoutJson = layoutStr
                        DashMateStateBridge.applyLayoutLive(layoutStr)
                        DashMateStateBridge.notifyStateChanged(this)
                    }
                    result.success(true)
                }
                "getLayoutSettings" -> {
                    val tall = call.argument<Boolean>("tall") ?: (DashMateStateBridge.layoutMode(this) == "tall")
                    val key = if (tall) "dashmate_layout_portrait" else "dashmate_layout"
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    val prefKey = getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE)
                    val layoutStr = sp.getString(key, null)
                        ?: prefKey.getString(key, null)
                        ?: if (!tall) {
                            sp.getString("dashmate_layout", null)
                                ?: sp.getString("car_layouts_current", null)
                                ?: prefKey.getString("dashmate_layout", null)
                                ?: DashMateStateBridge.cachedLayoutJson
                        } else null
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
                "isCarConnected" -> {
                    result.success(DashMateStateBridge.isCarConnected(this))
                }
                "getButtonPrefs" -> {
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    val scale = sp.getFloat("nav_scale", 1.0f) * 100
                    val opacity = sp.getFloat("nav_opacity", 0.92f) * 100
                    val colorIdx = sp.getInt("nav_color_idx", 0)
                    val position = sp.getString("dock_position", "top_left") ?: "top_left"
                    val autoCollapse = sp.getBoolean("dock_auto_collapse", true)
                    result.success(mapOf(
                        "size" to scale.toDouble(),
                        "opacity" to opacity.toDouble(),
                        "colorIndex" to colorIdx,
                        "position" to position,
                        "autoCollapse" to autoCollapse
                    ))
                }
                "setNavScale" -> {
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    val scale = call.argument<Any>("scale")?.toString()?.toFloatOrNull() ?: 1.0f
                    val opacity = call.argument<Any>("opacity")?.toString()?.toFloatOrNull() ?: 0.92f
                    val colorIdx = call.argument<Int>("colorIndex") ?: 0
                    val position = call.argument<String>("position") ?: "top_left"
                    val autoCollapse = call.argument<Boolean>("autoCollapse") ?: true
                    sp.edit()
                        .putFloat("nav_scale", scale)
                        .putFloat("nav_opacity", opacity)
                        .putInt("nav_color_idx", colorIdx)
                        .putString("dock_position", position)
                        .putBoolean("dock_auto_collapse", autoCollapse)
                        .apply()
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "getWelcomePrefs" -> {
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    result.success(mapOf(
                        "mode" to sp.getInt("welcome_mode", 1),
                        "voiceGreeting" to sp.getBoolean("welcome_voice", true),
                        "customText" to sp.getString("welcome_text", ""),
                        "speed" to sp.getFloat("welcome_speed", 1.0f).toDouble(),
                        "pitch" to sp.getFloat("welcome_pitch", 1.0f).toDouble(),
                        "volume" to sp.getFloat("welcome_volume", 0.8f).toDouble()
                    ))
                }
                "setWelcomePrefs" -> {
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    val mode = call.argument<Int>("mode") ?: 1
                    val voice = call.argument<Boolean>("voiceGreeting") ?: true
                    val text = call.argument<String>("customText") ?: ""
                    val speed = call.argument<Double>("speed")?.toFloat() ?: 1.0f
                    val pitch = call.argument<Double>("pitch")?.toFloat() ?: 1.0f
                    val vol = call.argument<Double>("volume")?.toFloat() ?: 0.8f
                    sp.edit()
                        .putInt("welcome_mode", mode)
                        .putBoolean("welcome_voice", voice)
                        .putString("welcome_text", text)
                        .putFloat("welcome_speed", speed)
                        .putFloat("welcome_pitch", pitch)
                        .putFloat("welcome_volume", vol)
                        .apply()
                    result.success(true)
                }
                "testVoiceGreeting" -> {
                    val rawText = call.argument<String>("text") ?: ""
                    val speed = call.argument<Double>("speed")?.toFloat() ?: 1.0f
                    val pitch = call.argument<Double>("pitch")?.toFloat() ?: 1.0f
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    val spPrefs = getSharedPreferences("dashmate_prefs", Context.MODE_PRIVATE)
                    val driverName = sp.getString("driver_name", null)
                        ?: spPrefs.getString("driver_name", null)
                        ?: "Mohamad Afix"
                    val text = if (rawText.isBlank()) "Welcome back, $driverName" else rawText
                        .replace("{name}", driverName)
                        .replace("{prayer_name}", "Maghrib")
                        .replace("{prayer_time}", "6:59 PM")
                        .replace("{time}", "7:15 PM")
                        .replace("{rain}", "No rain expected")
                    tts?.setSpeechRate(speed)
                    tts?.setPitch(pitch)
                    tts?.speak(text, android.speech.tts.TextToSpeech.QUEUE_FLUSH, null, "greeting_test")
                    result.success(true)
                }
                "getMenuItems" -> {
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    val json = sp.getString("menu_items", "[\"home\",\"lyrics\",\"prayer\",\"radio\",\"custom\",\"web\"]")
                    try {
                        val arr = org.json.JSONArray(json)
                        val list = mutableListOf<String>()
                        for (i in 0 until arr.length()) {
                            list.add(arr.getString(i))
                        }
                        result.success(list)
                    } catch (_: Exception) {
                        result.success(listOf("home", "lyrics", "prayer", "radio", "custom", "web"))
                    }
                }
                "setMenuItems" -> {
                    val items = call.argument<List<String>>("items") ?: listOf("home", "lyrics", "prayer", "radio", "custom", "web")
                    val json = org.json.JSONArray(items).toString()
                    getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                        .edit()
                        .putString("menu_items", json)
                        .apply()
                    getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE)
                        .edit()
                        .putString("menu_items", json)
                        .apply()
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "getCarCardMode" -> {
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    result.success(mapOf(
                        "show" to sp.getBoolean("car_card_show", true),
                        "mode" to sp.getString("car_card_mode", "Auto")
                    ))
                }
                "setCarCardMode" -> {
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    val show = call.argument<Boolean>("show") ?: true
                    val mode = call.argument<String>("mode") ?: "Auto"
                    sp.edit()
                        .putBoolean("car_card_show", show)
                        .putString("car_card_mode", mode)
                        .apply()
                    DashMateStateBridge.carCardMode = mode
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "getBgPrefs" -> {
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    result.success(mapOf(
                        "mode" to (DashMateStateBridge.bgMode.ifBlank { sp.getString("bg_mode", "cover") }),
                        "url" to (DashMateStateBridge.bgUrl.ifBlank { sp.getString("bg_url", "") })
                    ))
                }
                "getFootballPrefs" -> {
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    val compsJson = sp.getString("football_comps", "[\"PL\", \"CL\"]")
                    val teamsJson = sp.getString("football_teams", "[\"Arsenal\", \"Liverpool\"]")
                    val key = sp.getString("football_api_key", "")
                    val compsList = mutableListOf<String>()
                    val teamsList = mutableListOf<String>()
                    try {
                        val arr1 = org.json.JSONArray(compsJson)
                        for (i in 0 until arr1.length()) compsList.add(arr1.getString(i))
                        val arr2 = org.json.JSONArray(teamsJson)
                        for (i in 0 until arr2.length()) teamsList.add(arr2.getString(i))
                    } catch (_: Exception) {}
                    result.success(mapOf(
                        "competitions" to compsList,
                        "favouriteTeams" to teamsList,
                        "apiKey" to key
                    ))
                }
                "setFootballPrefs" -> {
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    val comps = call.argument<List<String>>("competitions") ?: listOf("PL", "CL")
                    val teams = call.argument<List<String>>("favouriteTeams") ?: listOf("Arsenal", "Liverpool")
                    val key = call.argument<String>("apiKey") ?: ""
                    sp.edit()
                        .putString("football_comps", org.json.JSONArray(comps).toString())
                        .putString("football_teams", org.json.JSONArray(teams).toString())
                        .putString("football_api_key", key)
                        .apply()
                    result.success(true)
                }
                "setAutoStart" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    getSharedPreferences("dashmate_prefs", Context.MODE_PRIVATE)
                        .edit().putBoolean("pref_auto_start", enabled).apply()
                    result.success(true)
                }
                "getAutoStart" -> {
                    val enabled = getSharedPreferences("dashmate_prefs", Context.MODE_PRIVATE)
                        .getBoolean("pref_auto_start", true)
                    result.success(enabled)
                }
                "getDriverName" -> {
                    val sp = getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE)
                    val spPrefs = getSharedPreferences("dashmate_prefs", Context.MODE_PRIVATE)
                    val name = sp.getString("driver_name", null)
                        ?: spPrefs.getString("driver_name", null)
                        ?: "Mohamad Afix"
                    result.success(name)
                }
                "setDriverName" -> {
                    val name = call.argument<String>("name") ?: "Mohamad Afix"
                    getSharedPreferences(PREFS_BROWSER, Context.MODE_PRIVATE).edit().putString("driver_name", name).apply()
                    getSharedPreferences("dashmate_prefs", Context.MODE_PRIVATE).edit().putString("driver_name", name).apply()
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        tts?.stop()
        tts?.shutdown()
    }
}
