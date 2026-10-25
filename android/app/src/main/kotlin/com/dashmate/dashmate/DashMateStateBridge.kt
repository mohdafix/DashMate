package com.dashmate.dashmate

import android.content.Context
import android.content.Intent
import android.content.res.AssetFileDescriptor
import android.media.MediaPlayer
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.dashmate.dashmate.deck.CalendarManager
import com.dashmate.dashmate.deck.FuelManager
import com.dashmate.dashmate.deck.LocalizationManager
import com.dashmate.dashmate.deck.LyricLine
import com.dashmate.dashmate.deck.LyricsFetcher
import com.dashmate.dashmate.deck.ParkingManager
import com.dashmate.dashmate.deck.PrayerTimesManager
import com.dashmate.dashmate.deck.WeatherManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.CopyOnWriteArrayList

object DashMateStateBridge {

    private const val TAG = "DashMateStateBridge"

    interface StateListener {
        fun onStateUpdated(stateJson: String)
        fun onSwitchPage(page: String)
        fun onExecuteScript(script: String)
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(Dispatchers.IO)
    private val listeners = CopyOnWriteArrayList<StateListener>()

    // Core States
    var cachedLayoutJson: String? = null
    var currentSpeed: Float = 0f
    var speedUnit: String = "km/h"
    var isGps: Boolean = true
    var songTitle: String = "Not Playing"
    var songArtist: String = "DashMate Audio"
    var songApp: String = "YouTube Music"
    var songCoverUrl: String = ""
    var currentArtBitmap: android.graphics.Bitmap? = null
    var currentArtUri: Uri? = null
    var isPlaying: Boolean = false
    var playbackPositionMs: Long = 0L
    var playbackPositionTimestampMs: Long = 0L
    var playbackSpeed: Float = 1.0f
    var playbackDurationMs: Long = 0L
    var isFetchingLyrics: Boolean = false
    var currentLyrics: List<LyricLine> = emptyList()

    var nextPrayerName: String = "Subuh"
    var nextPrayerTime: String = "05:49"
    var prayerCountdown: String = "42m"

    fun getCurrentPositionMs(): Long {
        if (!isPlaying || playbackPositionTimestampMs == 0L) {
            return playbackPositionMs
        }
        val elapsed = (SystemClock.elapsedRealtime() - playbackPositionTimestampMs)
        val computed = playbackPositionMs + (elapsed * playbackSpeed).toLong()
        return if (playbackDurationMs > 0L) computed.coerceIn(0L, playbackDurationMs) else computed.coerceAtLeast(0L)
    }

    fun getCurrentLyricLine(): String {
        if (currentLyrics.isEmpty()) return ""
        val pos = getCurrentPositionMs()
        for (i in currentLyrics.indices.reversed()) {
            if (pos >= currentLyrics[i].timeMs) {
                return currentLyrics[i].text
            }
        }
        return currentLyrics.first().text
    }

    fun updatePlaybackProgress(positionMs: Long, durationMs: Long = 0L, speed: Float = 1.0f) {
        playbackPositionMs = positionMs
        playbackPositionTimestampMs = SystemClock.elapsedRealtime()
        if (durationMs > 0L) playbackDurationMs = durationMs
        playbackSpeed = if (speed > 0f) speed else 1.0f
        if (listeners.isNotEmpty()) {
            notifyStateChanged()
        }
    }

    var activeFont: String = "orbitron" // orbitron, bebas, audiowide, monoton, teko, poiret
    var bgMode: String = "cover" // cover, plain, photo
    var bgUrl: String = ""
    var currentPage: String = "home" // home, lyrics, prayer, browse, custom
    var customPageMode: String = "weather" // weather, calendar, sports, radar, ev
    var currentYoutubeId: String = ""
    var appLanguage: String = "en"
    var carCardMode: String = "music" // music, prayer, weather, sports

    var customForecastObj: JSONObject? = null
    var customForecastArr: JSONArray? = null
    var customAirObj: JSONObject? = null
    var customRadarObj: JSONObject? = null
    var customEvObj: JSONObject? = null
    var customScoresArr: JSONArray? = null

    // Fuel Prices (MYR)
    var ron95Price: String = "2.05"
    var ron97Price: String = "3.19"
    var dieselPrice: String = "2.95"

    // Shortcuts (5 floating car shortcuts)
    var shortcutsList: MutableList<JSONObject> = mutableListOf(
        JSONObject().apply { put("name", "YouTube"); put("url", "https://m.youtube.com"); put("icon", "dd_youtube.png") },
        JSONObject().apply { put("name", "RTM Klik"); put("url", "https://rtmklik.rtm.gov.my"); put("icon", "dd_rtm.png") },
        JSONObject().apply { put("name", "Google"); put("url", "https://www.google.com"); put("icon", "https://www.google.com/favicon.ico") },
        JSONObject().apply { put("name", "Waze"); put("url", "https://www.waze.com/live-map"); put("icon", "https://www.waze.com/favicon.ico") },
        JSONObject().apply { put("name", "Parking"); put("url", "dashmate://parking"); put("icon", "assets/icons/parking.svg") }
    )

    fun addListener(listener: StateListener) {
        listeners.add(listener)
        listener.onStateUpdated(buildStateJson(null))
    }

    fun removeListener(listener: StateListener) {
        listeners.remove(listener)
    }

    private var lastMediaUpdateMs = 0L
    private var lastMediaKey = ""

    fun setPage(page: String) {
        if (currentPage == page && page != "custom") return
        currentPage = page
        mainHandler.post {
            for (listener in listeners) {
                listener.onSwitchPage(page)
            }
        }
    }

    fun playWelcomeChime(context: Context) {
        try {
            val afd: AssetFileDescriptor = context.assets.openFd("dd_welcome_chime.wav")
            val player = MediaPlayer().apply {
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                prepare()
                start()
                setOnCompletionListener {
                    it.release()
                    afd.close()
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not play welcome chime: ${e.message}")
        }
    }

    fun updateMediaInfo(
        context: Context,
        title: String,
        artist: String,
        playing: Boolean,
        coverUrl: String = "",
        app: String = "",
        durationMs: Long = 0L,
        positionMs: Long = 0L,
        lastUpdateTime: Long = 0L,
        speed: Float = 1.0f
    ) {
        val titleChanged = title != songTitle || artist != songArtist
        val playStateChanged = playing != isPlaying
        val now = System.currentTimeMillis()
        val currentKey = "$title|$artist|$playing"
        val isSamePlayback = (currentKey == lastMediaKey)

        // Throttle updates: if song & play state haven't changed, don't spam updates more than once every 1.5s
        if (!titleChanged && !playStateChanged && isSamePlayback && (now - lastMediaUpdateMs) < 1500L) {
            return
        }
        lastMediaKey = currentKey
        lastMediaUpdateMs = now

        songTitle = title
        songArtist = artist
        isPlaying = playing
        if (coverUrl.isNotBlank()) songCoverUrl = coverUrl
        if (app.isNotBlank()) songApp = app

        if (titleChanged) {
            playbackPositionMs = positionMs.coerceAtLeast(0L)
            playbackDurationMs = durationMs.coerceAtLeast(0L)
            playbackPositionTimestampMs = if (lastUpdateTime > 0L) lastUpdateTime else SystemClock.elapsedRealtime()
        } else {
            if (durationMs > 0L) playbackDurationMs = durationMs
            if (positionMs >= 0L) {
                playbackPositionMs = positionMs
                playbackPositionTimestampMs = if (lastUpdateTime > 0L) lastUpdateTime else SystemClock.elapsedRealtime()
            }
        }
        playbackSpeed = if (speed > 0f) speed else 1.0f

        if (titleChanged && title.isNotBlank() && title != "Not Playing") {
            isFetchingLyrics = true
            currentLyrics = emptyList()
            notifyStateChanged(context)
            scope.launch {
                try {
                    val fetched = LyricsFetcher.fetchLyrics(artist, title, context)
                    currentLyrics = fetched
                    Log.d(TAG, "Fetched ${currentLyrics.size} lyrics lines for $title")
                } catch (e: Exception) {
                    Log.w(TAG, "Error fetching lyrics: ${e.message}")
                } finally {
                    isFetchingLyrics = false
                    notifyStateChanged(context)
                }
            }
        } else {
            notifyStateChanged(context)
        }
    }

    fun refreshAllServices(context: Context) {
        scope.launch {
            try {
                WeatherManager.getWeatherData(context)
                WeatherManager.getAirQuality(context)
                WeatherManager.getRainRadar(context)
                FuelManager.syncFuelPrices(context)
            } catch (e: Exception) {
                Log.w(TAG, "Service refresh error: ${e.message}")
            }
            notifyStateChanged(context)
        }
    }

    fun isCarConnected(context: Context?): Boolean {
        return DashMatePresentation.isPresentationActive ||
               DashMateSession.isSessionActive ||
               com.dashmate.dashmate.deck.ParkingAutoSaver.isConnected()
    }

    fun buildStateJson(context: Context?): String {
        val root = JSONObject()
        val connected = isCarConnected(context)
        root.put("carConnected", connected)
        root.put("connected", connected)
        root.put("scr_w", DashMatePresentation.activeDisplayWidth)
        root.put("scr_h", DashMatePresentation.activeDisplayHeight)
        root.put("scr_name", DashMatePresentation.activeHeadUnitName)
        root.put("speed", currentSpeed.toInt())
        root.put("speedOnly", false)
        root.put("gps", isGps)

        if (context != null) {
            try {
                val spBrowser = context.getSharedPreferences("dd_car_browser", Context.MODE_PRIVATE)
                val spPrefs = context.getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE)
                val savedCustom = spBrowser.getString("customPage", null)
                    ?: spPrefs.getString("customPage", null)
                if (!savedCustom.isNullOrBlank()) {
                    customPageMode = savedCustom
                }
            } catch (_: Exception) {}
        }

        root.put("fn", if (currentPage == "custom") customPageMode else activeFont)
        root.put("page", currentPage)
        root.put("carCard", carCardMode)
        root.put("customPage", customPageMode)

        // Custom Multi-Widget Dashboard Layout
        if (currentPage == "custom") {
            val customLayout = JSONObject().apply {
                put("v", 2)
                put("textScale", 1)
                put("clockFont", "thin")
                val widgets = JSONArray()
                when (customPageMode) {
                    "calendar" -> {
                        widgets.put(JSONObject().apply { put("id", "calendar"); put("x", 1); put("y", 1); put("w", 12); put("h", 8) })
                    }
                    "sports" -> {
                        widgets.put(JSONObject().apply { put("id", "sports"); put("x", 1); put("y", 1); put("w", 12); put("h", 8) })
                    }
                    "radar" -> {
                        widgets.put(JSONObject().apply { put("id", "radar"); put("x", 1); put("y", 1); put("w", 12); put("h", 8) })
                    }
                    "ev" -> {
                        widgets.put(JSONObject().apply { put("id", "ev"); put("x", 1); put("y", 1); put("w", 12); put("h", 8) })
                    }
                    else -> { // "weather"
                        widgets.put(JSONObject().apply { put("id", "forecast"); put("x", 1); put("y", 1); put("w", 6); put("h", 8) })
                        widgets.put(JSONObject().apply { put("id", "air"); put("x", 7); put("y", 1); put("w", 6); put("h", 4) })
                        widgets.put(JSONObject().apply { put("id", "radar"); put("x", 7); put("y", 5); put("w", 6); put("h", 4) })
                    }
                }
                put("widgets", widgets)
            }
            root.put("layout", customLayout)
        } else {
            var activeLayoutStr = cachedLayoutJson
            if (context != null) {
                try {
                    val spBrowser = context.getSharedPreferences("dd_car_browser", Context.MODE_PRIVATE)
                    val spPrefs = context.getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE)
                    val layoutStr = spBrowser.getString("dashmate_layout", null)
                        ?: spBrowser.getString("car_layouts_current", null)
                        ?: spPrefs.getString("dashmate_layout", null)
                    if (!layoutStr.isNullOrBlank()) {
                        activeLayoutStr = layoutStr
                        cachedLayoutJson = layoutStr
                    }
                } catch (_: Exception) {}
            }
            if (!activeLayoutStr.isNullOrBlank()) {
                try {
                    root.put("layout", JSONObject(activeLayoutStr))
                } catch (_: Exception) {}
            }
        }

        // Portrait / Split-Screen Layout (12x18 grid)
        val defaultPortraitLayout = JSONObject().apply {
            put("v", 2)
            put("textScale", 1)
            put("clockFont", "thin")
            val widgets = JSONArray().apply {
                put(JSONObject().apply { put("id", "clock"); put("x", 1); put("y", 1); put("w", 12); put("h", 3) })
                put(JSONObject().apply { put("id", "music"); put("x", 1); put("y", 4); put("w", 12); put("h", 4) })
                put(JSONObject().apply { put("id", "prayer"); put("x", 1); put("y", 8); put("w", 6); put("h", 3) })
                put(JSONObject().apply { put("id", "weather"); put("x", 7); put("y", 8); put("w", 6); put("h", 3) })
                put(JSONObject().apply { put("id", "football"); put("x", 1); put("y", 11); put("w", 12); put("h", 2) })
                put(JSONObject().apply { put("id", "fuel"); put("x", 1); put("y", 13); put("w", 12); put("h", 3) })
                put(JSONObject().apply { put("id", "speed"); put("x", 1); put("y", 16); put("w", 5); put("h", 3); put("ta", "center") })
                put(JSONObject().apply { put("id", "shortcuts"); put("x", 6); put("y", 16); put("w", 7); put("h", 3); put("ta", "center") })
            }
            put("widgets", widgets)
        }
        root.put("layoutP", defaultPortraitLayout)

        // Labels / Localization
        val lang = if (context != null) LocalizationManager.getLanguage(context) else appLanguage
        val labelsObj = LocalizationManager.getLabels(lang)
        root.put("labels", labelsObj)
        root.put("lang", lang)

        // Background
        val bgObj = JSONObject().apply {
            put("mode", bgMode)
            put("dim", 0.4)
            if (bgUrl.isNotBlank()) put("url", bgUrl)
            else if (songCoverUrl.isNotBlank()) put("url", songCoverUrl)
        }
        root.put("bg", bgObj)

        // Lyrics data
        val lyricsArr = JSONArray()
        val linesPairArr = JSONArray()
        for (l in currentLyrics) {
            lyricsArr.put(JSONObject().apply {
                put("time", l.timeMs)
                put("text", l.text)
            })
            linesPairArr.put(JSONArray().apply {
                put(l.timeMs)
                put(l.text)
            })
        }
        val musicStatus = if (currentLyrics.isNotEmpty()) "found"
            else if (isFetchingLyrics) "loading"
            else if (songTitle.isNotBlank() && songTitle != "Not Playing") "notFound"
            else "waiting"

        // Music (matches drivedeck_home.html renderMusic and drivedeck_lyrics.html)
        val currentPos = getCurrentPositionMs()
        val musicObj = JSONObject().apply {
            put("title", songTitle)
            put("artist", songArtist)
            put("art", songCoverUrl)
            put("cover", songCoverUrl)
            put("playing", isPlaying)
            put("isPlaying", isPlaying)
            put("positionMs", currentPos)
            put("durationMs", playbackDurationMs)
            put("pos", currentPos / 1000)
            put("dur", playbackDurationMs / 1000)
            put("lines", linesPairArr)
            put("status", musicStatus)
            put("sentAtMs", System.currentTimeMillis())
            put("app", songApp)
            put("lyrics", lyricsArr)
        }
        root.put("music", musicObj)
        root.put("positionMs", currentPos)
        root.put("durationMs", playbackDurationMs)

        // Weather
        val weatherObj = if (context != null) {
            try {
                val cached = context.getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE)
                    .getString("dashmate_weather_cache", null)
                if (cached != null) JSONObject(cached) else defaultWeather()
            } catch (_: Exception) { defaultWeather() }
        } else defaultWeather()
        root.put("weather", weatherObj)

        // Forecast
        val forecastObj = customForecastObj ?: (if (context != null) {
            try {
                val cached = context.getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE)
                    .getString("dashmate_forecast_cache", null)
                if (cached != null) JSONObject(cached) else defaultForecast(weatherObj)
            } catch (_: Exception) { defaultForecast(weatherObj) }
        } else defaultForecast(weatherObj))
        root.put("forecast", forecastObj)

        // Air Quality
        val airObj = customAirObj ?: (if (context != null) {
            try {
                val cached = context.getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE)
                    .getString("dashmate_air_cache", null)
                if (cached != null) JSONObject(cached) else defaultAir()
            } catch (_: Exception) { defaultAir() }
        } else defaultAir())
        root.put("air", airObj)

        // Rain Radar
        val radarObj = customRadarObj ?: (if (context != null) {
            try {
                val cached = context.getSharedPreferences("DashMatePrefs", Context.MODE_PRIVATE)
                    .getString("dashmate_radar_cache", null)
                if (cached != null) JSONObject(cached) else defaultRadar()
            } catch (_: Exception) { defaultRadar() }
        } else defaultRadar())
        root.put("radar", radarObj)

        // Calendar
        val calendarObj = if (context != null) {
            try {
                CalendarManager.getUpcomingEvents(context)
            } catch (_: Exception) { defaultCalendar() }
        } else defaultCalendar()
        root.put("calendar", calendarObj)

        // Parking
        val parkingSpot = if (context != null) ParkingManager.getSpot(context) else null
        val parkingObj = JSONObject().apply {
            put("saved", parkingSpot != null)
            if (parkingSpot != null) {
                put("lat", parkingSpot.lat)
                put("lng", parkingSpot.lng)
                put("bay", parkingSpot.bay)
                put("level", parkingSpot.level)
                put("notes", parkingSpot.notes)
                put("time", parkingSpot.timestamp)
            }
        }
        root.put("parking", parkingObj)

        // Shortcuts
        val shortcutsArr = JSONArray()
        for (sc in shortcutsList) {
            shortcutsArr.put(sc)
        }
        root.put("shortcuts", shortcutsArr)

        // Prayer
        val prayerObj = if (context != null) {
            try {
                PrayerTimesManager.getEnrichedPrayerData(context)
            } catch (_: Exception) { defaultPrayer() }
        } else defaultPrayer()
        root.put("prayer", prayerObj)

        // Fuel
        val fuelObj = FuelManager.getFuelData(context)
        root.put("fuel", fuelObj)

        // Sports / Football
        val sportsArr = customScoresArr ?: JSONArray().apply {
            put(JSONObject().apply {
                put("league", "Premier League")
                put("home", "Arsenal")
                put("away", "Liverpool")
                put("score", "2 - 1")
                put("hs", 2)
                put("as", 1)
                put("time", "74'")
                put("detail", "74'")
                put("status", "live")
                put("state", "in")
            })
            put(JSONObject().apply {
                put("league", "La Liga")
                put("home", "Real Madrid")
                put("away", "Barcelona")
                put("score", "3 - 2")
                put("hs", 3)
                put("as", 2)
                put("time", "FT")
                put("detail", "FT")
                put("status", "ft")
                put("state", "post")
            })
            put(JSONObject().apply {
                put("league", "Premier League")
                put("home", "Man City")
                put("away", "Chelsea")
                put("score", "vs")
                put("time", "23:30")
                put("detail", "23:30")
                put("status", "pre")
                put("state", "pre")
            })
        }
        root.put("scores", sportsArr)
        root.put("scoresLabel", "Today's Matches")
        root.put("sports", JSONObject().apply {
            put("games", sportsArr)
        })

        // EV Chargers & Nearby Petrol Stations
        val evObj = customEvObj ?: JSONObject().apply {
            put("lat", 3.1390)
            put("lng", 101.6869)
            val items = JSONArray().apply {
                // EV Charger 1
                put(JSONObject().apply {
                    put("name", "Shell Recharge Pavilion KL")
                    put("kind", "ev")
                    put("operator", "Shell Recharge")
                    put("km", 1.2)
                    put("lat", 3.1488)
                    put("lng", 101.7133)
                    put("status", "up")
                    put("plugs", JSONArray().apply {
                        put(JSONObject().apply { put("type", "CCS2"); put("kw", 180); put("n", 2) })
                        put(JSONObject().apply { put("type", "Type 2"); put("kw", 22); put("n", 2) })
                    })
                })
                // Petrol Station 1
                put(JSONObject().apply {
                    put("name", "Petronas Jalan Ampang")
                    put("kind", "fuel")
                    put("operator", "Petronas")
                    put("km", 1.5)
                    put("lat", 3.1585)
                    put("lng", 101.7125)
                    put("status", "up")
                    put("fuels", "RON95 · RON97 · Diesel")
                    put("plugs", JSONArray().apply {
                        put(JSONObject().apply { put("type", "RON95"); put("kw", 0); put("n", 8) })
                        put(JSONObject().apply { put("type", "RON97"); put("kw", 0); put("n", 4) })
                        put(JSONObject().apply { put("type", "Euro 5 Diesel"); put("kw", 0); put("n", 4) })
                    })
                })
                // EV Charger 2
                put(JSONObject().apply {
                    put("name", "Gentari Suria KLCC")
                    put("kind", "ev")
                    put("operator", "Gentari")
                    put("km", 2.1)
                    put("lat", 3.1579)
                    put("lng", 101.7116)
                    put("status", "up")
                    put("plugs", JSONArray().apply {
                        put(JSONObject().apply { put("type", "CCS2"); put("kw", 60); put("n", 2) })
                        put(JSONObject().apply { put("type", "Type 2"); put("kw", 22); put("n", 4) })
                    })
                })
                // Petrol Station 2
                put(JSONObject().apply {
                    put("name", "Shell Jalan Tun Razak")
                    put("kind", "fuel")
                    put("operator", "Shell")
                    put("km", 2.4)
                    put("lat", 3.1465)
                    put("lng", 101.7190)
                    put("status", "up")
                    put("fuels", "FuelSave 95 · V-Power Racing · Diesel")
                    put("plugs", JSONArray().apply {
                        put(JSONObject().apply { put("type", "FuelSave 95"); put("kw", 0); put("n", 6) })
                        put(JSONObject().apply { put("type", "V-Power"); put("kw", 0); put("n", 4) })
                        put(JSONObject().apply { put("type", "Diesel"); put("kw", 0); put("n", 4) })
                    })
                })
                // Petrol Station 3
                put(JSONObject().apply {
                    put("name", "BHPetrol Sungai Besi")
                    put("kind", "fuel")
                    put("operator", "BHPetrol")
                    put("km", 3.2)
                    put("lat", 3.1320)
                    put("lng", 101.7080)
                    put("status", "up")
                    put("fuels", "Infiniti 95 · Infiniti 97 · Euro 5 Diesel")
                    put("plugs", JSONArray().apply {
                        put(JSONObject().apply { put("type", "Infiniti 95"); put("kw", 0); put("n", 6) })
                        put(JSONObject().apply { put("type", "Infiniti 97"); put("kw", 0); put("n", 2) })
                    })
                })
                // EV Charger 3
                put(JSONObject().apply {
                    put("name", "ChargEV Menara Maybank")
                    put("kind", "ev")
                    put("operator", "ChargEV")
                    put("km", 3.5)
                    put("lat", 3.1472)
                    put("lng", 101.6995)
                    put("status", "up")
                    put("plugs", JSONArray().apply {
                        put(JSONObject().apply { put("type", "CCS2"); put("kw", 50); put("n", 2) })
                        put(JSONObject().apply { put("type", "AC"); put("kw", 22); put("n", 2) })
                    })
                })
            }
            put("items", items)
        }
        root.put("ev", evObj)

        // Top-level lyrics and music fields (for drivedeck_lyrics.html and standalone views)
        root.put("lyrics", lyricsArr)
        root.put("lines", linesPairArr)
        root.put("title", songTitle)
        root.put("artist", songArtist)
        root.put("art", songCoverUrl)
        root.put("playing", isPlaying)
        root.put("positionMs", playbackPositionMs)
        root.put("durationMs", playbackDurationMs)
        root.put("status", musicStatus)
        root.put("app", songApp)
        root.put("cached", true)
        root.put("sentAtMs", System.currentTimeMillis())

        return root.toString()
    }

    fun defaultForecast(weatherObj: JSONObject?): JSONObject {
        val temp = weatherObj?.optInt("temp", 31) ?: 31
        val code = weatherObj?.optInt("code", 2) ?: 2
        val windStr = weatherObj?.optString("wind", "12 km/h") ?: "12 km/h"
        val wind = windStr.replace(" km/h", "").toIntOrNull() ?: 12

        val nowObj = JSONObject().apply {
            put("temp", temp)
            put("feels", temp + 3)
            put("code", code)
            put("isDay", true)
            put("humidity", 75)
            put("wind", wind)
            put("uv", 5.0)
        }

        val hoursArr = JSONArray()
        val cal = java.util.Calendar.getInstance()
        val curHour = cal.get(java.util.Calendar.HOUR_OF_DAY)
        for (i in 0 until 12) {
            val h = (curHour + i) % 24
            val hStr = String.format(java.util.Locale.US, "%02d:00", h)
            val hTemp = when (h) {
                in 11..16 -> temp + (h % 3)
                in 0..6 -> (temp - 5).coerceAtLeast(20) + (h % 2)
                else -> temp - 2
            }
            hoursArr.put(JSONObject().apply {
                put("t", hStr)
                put("temp", hTemp)
                put("code", if (i == 4 || i == 5) 80 else code)
                put("isDay", h in 7..19)
                put("rain", if (i == 4 || i == 5) 45 else 0)
            })
        }

        val daysArr = JSONArray()
        val sdf = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
        for (i in 0 until 7) {
            val dayCal = java.util.Calendar.getInstance().apply { add(java.util.Calendar.DAY_OF_YEAR, i) }
            val dStr = sdf.format(dayCal.time)
            daysArr.put(JSONObject().apply {
                put("d", dStr)
                put("code", if (i == 2 || i == 5) 80 else code)
                put("min", 24 + (i % 2))
                put("max", 32 + (i % 3))
                put("rain", if (i == 2 || i == 5) 60 else 10)
            })
        }

        return JSONObject().apply {
            put("now", nowObj)
            put("hours", hoursArr)
            put("days", daysArr)
        }
    }

    private fun defaultWeather(): JSONObject = JSONObject().apply {
        put("temp", 31)
        put("code", 2)
        put("cond", "Partly Cloudy")
        put("icon", "partly-cloudy-day")
        put("city", "Kuala Lumpur")
        put("wind", "12 km/h")
        put("rain", null)
    }

    private fun defaultAir(): JSONObject = JSONObject().apply {
        put("aqi", 42)
        put("pm25", 12)
        put("uv", 5.0)
        put("label", "Good")
    }

    private fun defaultRadar(): JSONObject = JSONObject().apply {
        put("host", "https://tilecache.rainviewer.com")
        put("path", "/v2/radar/nowcast")
        put("lat", 3.1390)
        put("lon", 101.6869)
        put("time", System.currentTimeMillis() / 1000)
    }

    private fun defaultCalendar(): JSONObject = JSONObject().apply {
        put("access", true)
        val now = System.currentTimeMillis()
        val eventsArr = JSONArray().apply {
            put(JSONObject().apply {
                put("title", "Daily Standup & Sync")
                put("begin", now + 1800000L)
                put("end", now + 3600000L)
                put("where", "Google Meet")
                put("allDay", false)
                put("color", "#14E0C1")
            })
            put(JSONObject().apply {
                put("title", "Family Dinner")
                put("begin", now + (4 * 3600000L))
                put("end", now + (6 * 3600000L))
                put("where", "Pavilion KL")
                put("allDay", false)
                put("color", "#F59E0B")
            })
        }
        put("events", eventsArr)
    }

    private fun defaultPrayer(): JSONObject = JSONObject().apply {
        put("status", "ok")
        put("zone", "WLY01 · Kuala Lumpur, Putrajaya")
        put("zoneName", "Kuala Lumpur, Putrajaya")
        put("date", "Today")

        val cal = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("Asia/Kuala_Lumpur"))
        fun epochAt(h: Int, m: Int): Long {
            val c = cal.clone() as java.util.Calendar
            c.set(java.util.Calendar.HOUR_OF_DAY, h)
            c.set(java.util.Calendar.MINUTE, m)
            c.set(java.util.Calendar.SECOND, 0)
            c.set(java.util.Calendar.MILLISECOND, 0)
            return c.timeInMillis
        }

        val imsakEpoch = epochAt(5, 39)
        val subuhEpoch = epochAt(5, 49)
        val syurukEpoch = epochAt(6, 56)
        val zohorEpoch = epochAt(13, 0)
        val asarEpoch = epochAt(16, 19)
        val maghribEpoch = epochAt(18, 59)
        val isyakEpoch = epochAt(20, 10)

        val arr = JSONArray().apply {
            put(JSONObject().apply { put("name", "Imsak"); put("time", "05:39"); put("epochMs", imsakEpoch); put("obligatory", false) })
            put(JSONObject().apply { put("name", "Subuh"); put("time", "05:49"); put("epochMs", subuhEpoch); put("obligatory", true) })
            put(JSONObject().apply { put("name", "Syuruk"); put("time", "06:56"); put("epochMs", syurukEpoch); put("obligatory", false) })
            put(JSONObject().apply { put("name", "Zohor"); put("time", "13:00"); put("epochMs", zohorEpoch); put("obligatory", true) })
            put(JSONObject().apply { put("name", "Asar"); put("time", "16:19"); put("epochMs", asarEpoch); put("obligatory", true) })
            put(JSONObject().apply { put("name", "Maghrib"); put("time", "18:59"); put("epochMs", maghribEpoch); put("obligatory", true) })
            put(JSONObject().apply { put("name", "Isyak"); put("time", "20:10"); put("epochMs", isyakEpoch); put("obligatory", true) })
        }
        put("times", arr)

        val nowMs = System.currentTimeMillis()
        var curObj: JSONObject? = null
        var nextObj: JSONObject? = null
        for (i in 0 until arr.length()) {
            val item = arr.getJSONObject(i)
            val ep = item.getLong("epochMs")
            if (ep <= nowMs) {
                curObj = item
            } else if (nextObj == null) {
                nextObj = item
            }
        }
        if (nextObj == null) {
            val tomCal = (cal.clone() as java.util.Calendar).apply {
                add(java.util.Calendar.DAY_OF_YEAR, 1)
                set(java.util.Calendar.HOUR_OF_DAY, 5)
                set(java.util.Calendar.MINUTE, 49)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }
            nextObj = JSONObject().apply {
                put("name", "Subuh")
                put("time", "05:49")
                put("epochMs", tomCal.timeInMillis)
                put("obligatory", true)
            }
        }
        if (curObj == null) {
            val yestCal = (cal.clone() as java.util.Calendar).apply {
                add(java.util.Calendar.DAY_OF_YEAR, -1)
                set(java.util.Calendar.HOUR_OF_DAY, 20)
                set(java.util.Calendar.MINUTE, 10)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }
            curObj = JSONObject().apply {
                put("name", "Isyak")
                put("time", "20:10")
                put("epochMs", yestCal.timeInMillis)
                put("obligatory", true)
            }
        }

        val remMs = (nextObj.getLong("epochMs") - nowMs).coerceAtLeast(0L)
        val remMin = (remMs / 60000L).toInt()
        val h = remMin / 60
        val m = remMin % 60
        val countStr = if (h > 0) "${h}h ${m}m" else "${m}m"

        put("current", curObj)
        put("next", nextObj)
        put("time", nextObj.optString("time", "05:49"))
        put("count", countStr)
        put("countMin", remMin)
        put("imsak", "05:39")
        put("subuh", "05:49")
        put("syuruk", "06:56")
        put("zohor", "13:00")
        put("asar", "16:19")
        put("maghrib", "18:59")
        put("isyak", "20:10")
    }

    fun notifyStateChanged(context: Context? = null) {
        val json = buildStateJson(context)
        mainHandler.post {
            for (listener in listeners) {
                listener.onStateUpdated(json)
            }
            try {
                DashMateMediaCardService.triggerUpdate()
            } catch (_: Throwable) {}
        }
    }

    fun highlightWidget(id: String) {
        executeScript("if (window.ddHighlight) window.ddHighlight('$id');")
    }

    fun applyLayoutLive(layoutJson: String) {
        cachedLayoutJson = layoutJson
        val script = "if (window.applyLayout) { window.applyLayout($layoutJson); } else if (window.ddUpdate) { window.ddUpdate({ layout: $layoutJson }); }"
        executeScript(script)
    }

    fun executeScript(script: String) {
        mainHandler.post {
            for (listener in listeners) {
                listener.onExecuteScript(script)
            }
        }
    }

    fun launchNavigation(context: Context, destination: String) {
        mainHandler.post {
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=" + Uri.encode(destination)))
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(intent)
            } catch (e: Exception) {
                val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://maps.google.com/?q=" + Uri.encode(destination)))
                webIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(webIntent)
            }
        }
    }

    fun launchNavigationCoords(context: Context, lat: Double, lng: Double) {
        mainHandler.post {
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("google.navigation:q=$lat,$lng"))
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(intent)
            } catch (e: Exception) {
                launchNavigation(context, "$lat,$lng")
            }
        }
    }
}
