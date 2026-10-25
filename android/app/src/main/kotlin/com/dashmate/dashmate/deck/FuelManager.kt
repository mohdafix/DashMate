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

object FuelManager {
    private const val TAG = "FuelManager"
    private const val PREFS_NAME = "DashMatePrefs"
    private const val PREF_FUEL_CACHE = "dashmate_fuel_cache"
    private const val PREF_FUEL_CACHE_TIME = "dashmate_fuel_cache_time"
    private const val CACHE_DURATION_MS = 6 * 60 * 60 * 1000L // 6 hours

    @Volatile
    var cachedFuelObj: JSONObject? = null

    fun getFuelData(context: Context?): JSONObject {
        cachedFuelObj?.let { return it }

        if (context != null) {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val cached = prefs.getString(PREF_FUEL_CACHE, null)
                if (!cached.isNullOrBlank()) {
                    val obj = JSONObject(cached)
                    cachedFuelObj = obj
                    return obj
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error reading fuel cache: ${e.message}")
            }
        }

        return getDefaultFuelData()
    }

    fun getDefaultFuelData(): JSONObject {
        return JSONObject().apply {
            val items = JSONArray().apply {
                put(JSONObject().apply { put("label", "RON97"); put("price", 4.80) })
                put(JSONObject().apply { put("label", "Diesel"); put("price", 5.07) })
                put(JSONObject().apply { put("label", "RON95 BUDI"); put("price", 1.99) })
                put(JSONObject().apply { put("label", "Diesel (East Msia)"); put("price", 2.15) })
            }
            put("items", items)
        }
    }

    suspend fun syncFuelPrices(context: Context): JSONObject = withContext(Dispatchers.IO) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lastTime = prefs.getLong(PREF_FUEL_CACHE_TIME, 0L)
        val cached = prefs.getString(PREF_FUEL_CACHE, null)
        val now = System.currentTimeMillis()

        if (!cached.isNullOrBlank() && (now - lastTime) < CACHE_DURATION_MS) {
            try {
                val obj = JSONObject(cached)
                cachedFuelObj = obj
                return@withContext obj
            } catch (_: Throwable) {}
        }

        try {
            val url = URL("https://api.data.gov.my/data-catalogue?id=fuelprice")
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 6000
            conn.readTimeout = 6000
            conn.setRequestProperty("User-Agent", "DashMate-AndroidAuto/1.0")

            if (conn.responseCode == 200) {
                val reader = BufferedReader(InputStreamReader(conn.inputStream))
                val resp = reader.readText()
                reader.close()

                val dataArr = JSONArray(resp)
                var latestObj: JSONObject? = null

                for (i in 0 until dataArr.length()) {
                    val item = dataArr.optJSONObject(i)
                    if (item != null && item.optString("series_type") == "level") {
                        latestObj = item
                    }
                }

                if (latestObj != null) {
                    val ron97 = latestObj.optDouble("ron97", 4.80)
                    val diesel = latestObj.optDouble("diesel", 5.07)
                    val ron95Budi = if (latestObj.has("ron95_budi95")) {
                        latestObj.optDouble("ron95_budi95", 1.99)
                    } else if (latestObj.has("ron95_skps")) {
                        latestObj.optDouble("ron95_skps", 2.05)
                    } else {
                        latestObj.optDouble("ron95", 2.05)
                    }
                    val dieselEast = latestObj.optDouble("diesel_eastmsia", diesel)

                    val fuelObj = JSONObject().apply {
                        val items = JSONArray().apply {
                            put(JSONObject().apply { put("label", "RON97"); put("price", ron97) })
                            put(JSONObject().apply { put("label", "Diesel"); put("price", diesel) })
                            put(JSONObject().apply { put("label", "RON95 BUDI"); put("price", ron95Budi) })
                            put(JSONObject().apply { put("label", "Diesel (East Msia)"); put("price", dieselEast) })
                        }
                        put("items", items)
                    }

                    cachedFuelObj = fuelObj
                    prefs.edit()
                        .putString(PREF_FUEL_CACHE, fuelObj.toString())
                        .putLong(PREF_FUEL_CACHE_TIME, now)
                        .apply()

                    return@withContext fuelObj
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to fetch live fuel prices: ${e.message}")
        }

        val fallback = getFuelData(context)
        return@withContext fallback
    }
}
