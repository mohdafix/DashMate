package com.dashmate.dashmate

import android.content.Intent
import android.provider.Settings
import com.dashmate.dashmate.deck.CalendarManager
import com.dashmate.dashmate.deck.LocalizationManager
import com.dashmate.dashmate.deck.LyricsFetcher
import com.dashmate.dashmate.deck.ParkingManager
import com.dashmate.dashmate.deck.PrayerTimesManager
import com.dashmate.dashmate.deck.WeatherManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.dashmate.dashmate/channel"
    private val scope = CoroutineScope(Dispatchers.Main)
    private var flutterChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        flutterChannel = channel

        DashMateStateBridge.addListener(object : DashMateStateBridge.StateListener {
            override fun onStateUpdated(stateJson: String) {
                runOnUiThread {
                    flutterChannel?.invokeMethod("onStateUpdate", stateJson)
                }
            }
            override fun onSwitchPage(page: String) {}
            override fun onExecuteScript(script: String) {}
        })

        channel.setMethodCallHandler { call, result ->
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
                        result.success(map)
                    } else {
                        result.success(null)
                    }
                }
                "clearParkingSpot" -> {
                    ParkingManager.clearSpot(this)
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "navigateBackToCar" -> {
                    ParkingManager.navigateBack(this)
                    result.success(true)
                }
                "setLanguage" -> {
                    val lang = call.argument<String>("lang") ?: "en"
                    LocalizationManager.setLanguage(this, lang)
                    DashMateStateBridge.appLanguage = lang
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "getLanguage" -> {
                    result.success(LocalizationManager.getLanguage(this))
                }
                "setCarCardMode" -> {
                    val mode = call.argument<String>("mode") ?: "music"
                    DashMateStateBridge.carCardMode = mode
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "getCarCardMode" -> {
                    result.success(DashMateStateBridge.carCardMode)
                }
                "setShortcuts" -> {
                    val list = call.argument<List<Map<String, String>>>("shortcuts")
                    if (list != null) {
                        DashMateStateBridge.shortcutsList.clear()
                        for (item in list) {
                            DashMateStateBridge.shortcutsList.add(JSONObject(item))
                        }
                        DashMateStateBridge.notifyStateChanged(this)
                    }
                    result.success(true)
                }
                "fetchLyrics" -> {
                    val artist = call.argument<String>("artist") ?: ""
                    val track = call.argument<String>("track") ?: ""
                    scope.launch {
                        val lyrics = LyricsFetcher.fetchLyrics(artist, track, this@MainActivity)
                        DashMateStateBridge.currentLyrics = lyrics
                        DashMateStateBridge.isFetchingLyrics = false
                        DashMateStateBridge.notifyStateChanged(this@MainActivity)
                        val formatted = lyrics.map { mapOf("time" to it.timeMs, "text" to it.text) }
                        result.success(formatted)
                    }
                }
                "setLyrics" -> {
                    val lines = call.argument<List<Map<String, Any>>>("lyrics")
                    if (lines != null) {
                        val list = lines.map {
                            com.dashmate.dashmate.deck.LyricLine(
                                (it["time"] as? Number)?.toLong() ?: 0L,
                                (it["text"] as? String) ?: ""
                            )
                        }
                        DashMateStateBridge.currentLyrics = list
                        DashMateStateBridge.isFetchingLyrics = false
                        DashMateStateBridge.notifyStateChanged(this)
                    }
                    result.success(true)
                }
                "setCarPage" -> {
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
                    val am = getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
                    am.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, android.view.KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
                    am.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_UP, android.view.KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
                    DashMateStateBridge.isPlaying = !DashMateStateBridge.isPlaying
                    DashMateStateBridge.notifyStateChanged(this)
                    result.success(true)
                }
                "mediaNext" -> {
                    val am = getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
                    am.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, android.view.KeyEvent.KEYCODE_MEDIA_NEXT))
                    am.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_UP, android.view.KeyEvent.KEYCODE_MEDIA_NEXT))
                    result.success(true)
                }
                "mediaPrevious" -> {
                    val am = getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
                    am.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, android.view.KeyEvent.KEYCODE_MEDIA_PREVIOUS))
                    am.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_UP, android.view.KeyEvent.KEYCODE_MEDIA_PREVIOUS))
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
                        getSharedPreferences("DashMatePrefs", android.content.Context.MODE_PRIVATE)
                            .edit()
                            .putString("dashmate_layout", layoutStr)
                            .apply()
                        DashMateStateBridge.applyLayoutLive(layoutStr)
                        DashMateStateBridge.notifyStateChanged(this)
                    }
                    result.success(true)
                }
                "getLayoutSettings" -> {
                    val layoutStr = getSharedPreferences("DashMatePrefs", android.content.Context.MODE_PRIVATE)
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
