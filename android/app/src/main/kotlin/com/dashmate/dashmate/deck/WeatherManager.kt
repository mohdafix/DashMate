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
    private const val CACHE_DURATION_MS = 15 * 60 * 1000L // 15 minutes

    suspend fun getWeatherData(context: Context): JSONObject = withContext(Dispatchers.IO) {
        val zone = PrayerTimesManager.getSelectedZone(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val lastTime = prefs.getLong(PREF_CACHE_TIME_KEY, 0L)
        val cached = prefs.getString(PREF_CACHE_KEY, null)
        val now = System.currentTimeMillis()

        if (!cached.isNullOrBlank() && (now - lastTime) < CACHE_DURATION_MS) {
            try {
                return@withContext JSONObject(cached)
            } catch (_: Throwable) {}
        }

        try {
            val urlStr = "https://api.open-meteo.com/v1/forecast?latitude=${zone.lat}&longitude=${zone.lon}&current_weather=true&hourly=temperature_2m,weathercode,relativehumidity_2m&forecast_days=2"
            val url = URL(urlStr)
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 4000
            conn.readTimeout = 4000
            conn.setRequestProperty("User-Agent", "DashMate-AndroidAuto/1.0")

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

                    val weatherObj = JSONObject().apply {
                        put("temp", Math.round(temp))
                        put("code", code)
                        put("cond", conditionInfo.first)
                        put("icon", conditionInfo.second)
                        put("city", zone.name.split(",")[0].trim())
                        put("wind", "${Math.round(wind)} km/h")
                        put("rain", if (code in 51..82) "Precipitation expected" else null)
                    }

                    // Hourly forecast strip
                    val hourly = apiObj.optJSONObject("hourly")
                    val forecastArr = JSONArray()
                    if (hourly != null) {
                        val times = hourly.optJSONArray("time")
                        val temps = hourly.optJSONArray("temperature_2m")
                        val codes = hourly.optJSONArray("weathercode")
                        if (times != null && temps != null && codes != null) {
                            for (i in 0 until minOf(times.length(), 6)) {
                                val tStr = times.optString(i, "")
                                val hour = if (tStr.length >= 16) tStr.substring(11, 16) else "$i:00"
                                val hTemp = Math.round(temps.optDouble(i, 30.0))
                                val hCode = codes.optInt(i, 1)
                                val item = JSONObject().apply {
                                    put("time", hour)
                                    put("temp", "${hTemp}°")
                                    put("icon", parseWeatherCode(hCode).second)
                                }
                                forecastArr.put(item)
                            }
                        }
                    }
                    weatherObj.put("forecast", forecastArr)

                    prefs.edit()
                        .putString(PREF_CACHE_KEY, weatherObj.toString())
                        .putLong(PREF_CACHE_TIME_KEY, now)
                        .apply()

                    return@withContext weatherObj
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "Weather fetch error: ${e.message}")
        }

        return@withContext JSONObject().apply {
            put("temp", "31°")
            put("cond", "Partly Cloudy")
            put("icon", "partly-cloudy-day")
            put("city", zone.name.split(",")[0].trim())
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

        if (!cached.isNullOrBlank() && (now - lastTime) < CACHE_DURATION_MS) {
            try { return@withContext JSONObject(cached) } catch (_: Throwable) {}
        }

        try {
            val urlStr = "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=${zone.lat}&longitude=${zone.lon}&current=us_aqi,pm2_5,uv_index"
            val conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
                connectTimeout = 4000
                readTimeout = 4000
                setRequestProperty("User-Agent", "DashMate-AndroidAuto/1.0")
            }

            if (conn.responseCode == 200) {
                val resp = conn.inputStream.bufferedReader().use { it.readText() }
                val root = JSONObject(resp)
                val current = root.optJSONObject("current")
                if (current != null) {
                    val aqi = current.optDouble("us_aqi", 42.0).toInt()
                    val pm25 = current.optDouble("pm2_5", 12.0).toInt()
                    val uv = current.optDouble("uv_index", 5.0)

                    val airObj = JSONObject().apply {
                        put("aqi", aqi)
                        put("pm25", pm25)
                        put("uv", uv)
                        put("label", getAqiLabel(aqi))
                    }

                    prefs.edit().putString(PREF_AIR_CACHE_KEY, airObj.toString()).apply()
                    return@withContext airObj
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "Air Quality fetch error: ${e.message}")
        }

        return@withContext JSONObject().apply {
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

        if (!cached.isNullOrBlank() && (now - lastTime) < (10 * 60 * 1000L)) {
            try { return@withContext JSONObject(cached) } catch (_: Throwable) {}
        }

        try {
            val urlStr = "https://api.rainviewer.com/public/weather-maps.json"
            val conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
                connectTimeout = 4000
                readTimeout = 4000
                setRequestProperty("User-Agent", "DashMate-AndroidAuto/1.0")
            }

            if (conn.responseCode == 200) {
                val resp = conn.inputStream.bufferedReader().use { it.readText() }
                val root = JSONObject(resp)
                val host = root.optString("host", "https://tilecache.rainviewer.com")
                val radar = root.optJSONObject("radar")
                val past = radar?.optJSONArray("past")

                if (past != null && past.length() > 0) {
                    val latest = past.getJSONObject(past.length() - 1)
                    val path = latest.optString("path", "")
                    val time = latest.optLong("time", now / 1000)

                    val radarObj = JSONObject().apply {
                        put("host", host)
                        put("path", path)
                        put("lat", zone.lat)
                        put("lon", zone.lon)
                        put("time", time)
                    }

                    prefs.edit().putString(PREF_RADAR_CACHE_KEY, radarObj.toString()).apply()
                    return@withContext radarObj
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "RainViewer fetch error: ${e.message}")
        }

        return@withContext JSONObject().apply {
            put("host", "https://tilecache.rainviewer.com")
            put("path", "/v2/radar/nowcast")
            put("lat", zone.lat)
            put("lon", zone.lon)
            put("time", now / 1000)
        }
    }

    private fun getAqiLabel(aqi: Int): String {
        return when {
            aqi <= 50 -> "Good"
            aqi <= 100 -> "Moderate"
            aqi <= 150 -> "Sensitive"
            aqi <= 200 -> "Unhealthy"
            aqi <= 300 -> "Very Unhealthy"
            else -> "Hazardous"
        }
    }

    private fun parseWeatherCode(code: Int): Pair<String, String> {
        return when (code) {
            0 -> Pair("Clear Sky", "clear-day")
            1, 2 -> Pair("Partly Cloudy", "partly-cloudy-day")
            3 -> Pair("Overcast", "overcast-day")
            45, 48 -> Pair("Foggy", "fog-day")
            51, 53, 55 -> Pair("Drizzle", "drizzle")
            61, 63, 65 -> Pair("Rain Showers", "rain")
            80, 81, 82 -> Pair("Heavy Rain", "thunderstorms-day-rain")
            95, 96, 99 -> Pair("Thunderstorm", "thunderstorms-day-rain")
            else -> Pair("Scattered Clouds", "partly-cloudy-day")
        }
    }
}
