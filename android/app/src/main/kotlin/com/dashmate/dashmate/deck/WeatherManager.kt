package com.dashmate.dashmate.deck

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

object WeatherManager {
    private const val TAG = "WeatherManager"
    private const val PREFS_NAME = "DashMatePrefs"
    private const val PREF_CACHE_KEY = "dashmate_weather_cache"
    private const val PREF_AIR_CACHE_KEY = "dashmate_air_cache"
    private const val PREF_RADAR_CACHE_KEY = "dashmate_radar_cache"
    private const val PREF_CACHE_TIME_KEY = "dashmate_weather_cache_time"
    private const val CACHE_DURATION_MS = 900000L // 15 min
    private const val USER_AGENT = "DashMate-AndroidAuto/1.0"

    private fun openConn(urlStr: String): HttpURLConnection {
        val conn = URL(urlStr).openConnection() as HttpURLConnection
        conn.connectTimeout = 4000
        conn.readTimeout = 4000
        conn.setRequestProperty("User-Agent", USER_AGENT)
        return conn
    }

    private fun cityOf(zone: PrayerZone): String = zone.name.split(",")[0].trim()

    /**
     * The Forecast card's data: now (temp, feels, UV, humidity, wind), the next 12 hours and 7 days,
     * shaped as the car page reads it ({now, hours, days}). Null if Open-Meteo can't be reached.
     */
    private fun fetchDetail(zone: PrayerZone): JSONObject? = try {
        val url = "https://api.open-meteo.com/v1/forecast?latitude=${zone.lat}&longitude=${zone.lon}" +
            "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day,uv_index" +
            "&hourly=temperature_2m,weather_code,precipitation_probability,is_day" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max" +
            "&forecast_days=7&timezone=auto"
        val conn = openConn(url)
        if (conn.responseCode != 200) null else {
            val api = JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
            val c = api.getJSONObject("current")
            val now = JSONObject().apply {
                put("temp", c.optDouble("temperature_2m")); put("feels", c.optDouble("apparent_temperature"))
                put("code", c.optInt("weather_code")); put("isDay", c.optInt("is_day", 1) == 1)
                put("uv", c.optDouble("uv_index")); put("humidity", c.optDouble("relative_humidity_2m"))
                put("wind", c.optDouble("wind_speed_10m"))
            }
            // The next 8 hours from the current one (the list starts at local midnight); more crowd a tall screen.
            val h = api.getJSONObject("hourly")
            val times = h.getJSONArray("time")
            val currentHour = c.optString("time").take(13)
            var start = 0
            while (start < times.length() && times.getString(start).take(13) < currentHour) start++
            val hours = JSONArray()
            for (i in start until minOf(start + 8, times.length())) hours.put(JSONObject().apply {
                put("t", times.getString(i).substring(11, 16)); put("temp", h.getJSONArray("temperature_2m").optDouble(i))
                put("code", h.getJSONArray("weather_code").optInt(i)); put("isDay", h.getJSONArray("is_day").optInt(i, 1) == 1)
                put("rain", h.getJSONArray("precipitation_probability").optInt(i))
            })
            val d = api.getJSONObject("daily")
            val days = JSONArray()
            for (i in 0 until d.getJSONArray("time").length()) days.put(JSONObject().apply {
                put("d", d.getJSONArray("time").getString(i)); put("code", d.getJSONArray("weather_code").optInt(i))
                put("max", d.getJSONArray("temperature_2m_max").optDouble(i)); put("min", d.getJSONArray("temperature_2m_min").optDouble(i))
                put("rain", d.getJSONArray("precipitation_probability_max").optInt(i))
            })
            JSONObject().apply { put("now", now); put("hours", hours); put("days", days) }
        }
    } catch (e: Exception) {
        Log.w(TAG, "Forecast detail failed: ${e.message}")
        null
    }

    suspend fun getWeatherData(context: Context): JSONObject = withContext(Dispatchers.IO) {
        val zone = PrayerTimesManager.getSelectedZone(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lastTime = prefs.getLong(PREF_CACHE_TIME_KEY, 0L)
        val cached = prefs.getString(PREF_CACHE_KEY, null)
        val now = System.currentTimeMillis()

        if (!cached.isNullOrBlank() && now - lastTime < CACHE_DURATION_MS) {
            try {
                return@withContext JSONObject(cached)
            } catch (ignored: Throwable) {
            }
        }

        try {
            val urlStr = "https://api.open-meteo.com/v1/forecast?latitude=" + zone.lat +
                "&longitude=" + zone.lon +
                "&current_weather=true&hourly=temperature_2m,weathercode,relativehumidity_2m&forecast_days=2"
            val conn = openConn(urlStr)
            if (conn.responseCode == 200) {
                val reader = BufferedReader(InputStreamReader(conn.inputStream))
                val resp = reader.readText()
                reader.close()
                val apiObj = JSONObject(resp)
                val current = apiObj.optJSONObject("current_weather")
                if (current != null) {
                    val temp = current.optDouble("temperature", 31.0)
                    val code = current.optInt("weathercode", 2)
                    val wind = current.optDouble("windspeed", 10.0)
                    val conditionInfo = parseWeatherCode(code)

                    val result = JSONObject()
                    result.put("temp", Math.round(temp))
                    result.put("code", code)
                    result.put("cond", conditionInfo.first)
                    result.put("icon", conditionInfo.second)
                    result.put("city", cityOf(zone))
                    result.put("wind", "${Math.round(wind)} km/h")
                    result.put("rain", if (code in 51..82) "Precipitation expected" else null)

                    val hourly = apiObj.optJSONObject("hourly")
                    val forecastArr = JSONArray()
                    if (hourly != null) {
                        val times = hourly.optJSONArray("time")
                        val temps = hourly.optJSONArray("temperature_2m")
                        val codes = hourly.optJSONArray("weathercode")
                        if (times != null && temps != null && codes != null) {
                            val count = minOf(times.length(), 6)
                            for (i in 0 until count) {
                                val tStr = times.optString(i, "")
                                val hour = if (tStr.length >= 16) tStr.substring(11, 16) else "$i:00"
                                val hTemp = Math.round(temps.optDouble(i, 30.0))
                                val hCode = codes.optInt(i, 1)
                                val item = JSONObject()
                                item.put("time", hour)
                                item.put("temp", "$hTemp°")
                                item.put("icon", parseWeatherCode(hCode).second)
                                forecastArr.put(item)
                            }
                        }
                    }
                    result.put("forecast", forecastArr)
                    fetchDetail(zone)?.let { result.put("detail", it) }

                    prefs.edit()
                        .putString(PREF_CACHE_KEY, result.toString())
                        .putLong(PREF_CACHE_TIME_KEY, now)
                        .apply()
                    return@withContext result
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "Weather fetch error: " + e.message)
        }

        JSONObject().apply {
            put("temp", "31°")
            put("cond", "Partly Cloudy")
            put("icon", "partly-cloudy-day")
            put("city", cityOf(zone))
            put("wind", "12 km/h")
            put("rain", null)
        }
    }

    suspend fun getAirQuality(context: Context): JSONObject = withContext(Dispatchers.IO) {
        val zone = PrayerTimesManager.getSelectedZone(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val cached = prefs.getString(PREF_AIR_CACHE_KEY, null)
        val lastTime = prefs.getLong(PREF_CACHE_TIME_KEY, 0L)
        val now = System.currentTimeMillis()

        if (!cached.isNullOrBlank() && now - lastTime < CACHE_DURATION_MS) {
            try {
                return@withContext JSONObject(cached)
            } catch (ignored: Throwable) {
            }
        }

        try {
            val urlStr = "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=" + zone.lat +
                "&longitude=" + zone.lon + "&current=us_aqi,pm2_5,uv_index"
            val conn = openConn(urlStr)
            if (conn.responseCode == 200) {
                val resp = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                val root = JSONObject(resp)
                val current = root.optJSONObject("current")
                if (current != null) {
                    val aqi = current.optDouble("us_aqi", 42.0).toInt()
                    val pm25 = current.optDouble("pm2_5", 12.0).toInt()
                    val uv = current.optDouble("uv_index", 5.0)
                    val airObj = JSONObject()
                    airObj.put("aqi", aqi)
                    airObj.put("pm25", pm25)
                    airObj.put("uv", uv)
                    airObj.put("label", getAqiLabel(aqi))
                    prefs.edit().putString(PREF_AIR_CACHE_KEY, airObj.toString()).apply()
                    return@withContext airObj
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "Air Quality fetch error: " + e.message)
        }

        JSONObject().apply {
            put("aqi", 42)
            put("pm25", 12)
            put("uv", 5.0)
            put("label", "Good")
        }
    }

    suspend fun getRainRadar(context: Context): JSONObject? = withContext(Dispatchers.IO) {
        val zone = PrayerTimesManager.getSelectedZone(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val cached = prefs.getString(PREF_RADAR_CACHE_KEY, null)
        val lastTime = prefs.getLong(PREF_CACHE_TIME_KEY, 0L)
        val now = System.currentTimeMillis()

        // Radar uses a 10-minute window (not CACHE_DURATION_MS).
        if (!cached.isNullOrBlank() && now - lastTime < 600000L) {
            try {
                return@withContext JSONObject(cached)
            } catch (ignored: Throwable) {
            }
        }

        try {
            val conn = openConn("https://api.rainviewer.com/public/weather-maps.json")
            if (conn.responseCode == 200) {
                val resp = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                val root = JSONObject(resp)
                val host = root.optString("host", "https://tilecache.rainviewer.com")
                val past = root.optJSONObject("radar")?.optJSONArray("past")
                if (past != null && past.length() > 0) {
                    val latest = past.getJSONObject(past.length() - 1)
                    val path = latest.optString("path", "")
                    val time = latest.optLong("time", now / 1000)
                    val radar = JSONObject()
                    radar.put("host", host)
                    radar.put("path", path)
                    radar.put("lat", zone.lat)
                    radar.put("lon", zone.lon)
                    radar.put("time", time)
                    prefs.edit().putString(PREF_RADAR_CACHE_KEY, radar.toString()).apply()
                    return@withContext radar
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "RainViewer fetch error: " + e.message)
        }

        JSONObject().apply {
            put("host", "https://tilecache.rainviewer.com")
            put("path", "/v2/radar/nowcast")
            put("lat", zone.lat)
            put("lon", zone.lon)
            put("time", now / 1000)
        }
    }

    private fun getAqiLabel(aqi: Int): String = when {
        aqi <= 50 -> "Good"
        aqi <= 100 -> "Moderate"
        aqi <= 150 -> "Sensitive"
        aqi <= 200 -> "Unhealthy"
        aqi <= 300 -> "Very Unhealthy"
        else -> "Hazardous"
    }

    private fun parseWeatherCode(code: Int): Pair<String, String> = when (code) {
        0 -> "Clear Sky" to "clear-day"
        1, 2 -> "Partly Cloudy" to "partly-cloudy-day"
        3 -> "Overcast" to "overcast-day"
        45, 48 -> "Foggy" to "fog-day"
        51, 53, 55 -> "Drizzle" to "drizzle"
        61, 63, 65 -> "Rain Showers" to "rain"
        80, 81, 82 -> "Heavy Rain" to "thunderstorms-day-rain"
        95, 96, 99 -> "Thunderstorm" to "thunderstorms-day-rain"
        else -> "Scattered Clouds" to "partly-cloudy-day"
    }
}
