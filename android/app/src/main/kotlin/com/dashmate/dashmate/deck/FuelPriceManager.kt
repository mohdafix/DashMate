package com.dashmate.dashmate.deck

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Weekly Malaysian fuel prices from the official open-data API (data.gov.my, KPDN source).
 * Prices change every Wednesday night, so a 6-hour cache is plenty.
 *
 * Output shape is what drivedeck_home.html's renderFuel() expects:
 * { date, items: [{label, price, change}] }
 */
object FuelPriceManager {
    private const val TAG = "FuelPrice"
    private const val URL_API = "https://api.data.gov.my/data-catalogue/?id=fuelprice&sort=-date&limit=4"
    private const val PREFS = "DashMatePrefs"
    private const val KEY_JSON = "dashmate_fuel_cache"
    private const val KEY_TIME = "dashmate_fuel_cache_time"
    private const val TTL_MS = 6 * 60 * 60 * 1000L

    /** Last good prices (may be days old — still the right prices until next Wednesday). */
    fun cached(context: Context): JSONObject? = try {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_JSON, null)?.let { JSONObject(it) }
    } catch (e: Exception) {
        null
    }

    suspend fun refresh(context: Context, force: Boolean = false): JSONObject? = withContext(Dispatchers.IO) {
        val sp = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val age = System.currentTimeMillis() - sp.getLong(KEY_TIME, 0L)
        if (!force && age < TTL_MS) return@withContext cached(context)
        try {
            val conn = (URL(URL_API).openConnection() as HttpURLConnection).apply {
                connectTimeout = 8000
                readTimeout = 8000
                instanceFollowRedirects = true
                setRequestProperty("User-Agent", "DashMate/1.0")
            }
            val body = conn.inputStream.bufferedReader().use { it.readText() }
            conn.disconnect()
            val rows = JSONArray(body)
            var level: JSONObject? = null
            var change: JSONObject? = null
            for (i in 0 until rows.length()) {
                val r = rows.getJSONObject(i)
                when (r.optString("series_type")) {
                    "level" -> if (level == null) level = r
                    "change_weekly" -> if (change == null) change = r
                }
            }
            val lv = level ?: return@withContext cached(context)
            fun item(label: String, key: String) = JSONObject().apply {
                put("label", label)
                put("price", lv.optDouble(key))
                put("change", change?.optDouble(key) ?: 0.0)
            }
            val out = JSONObject().apply {
                put("date", lv.optString("date"))
                put("items", JSONArray().apply {
                    // The page hides plain "RON95" and shows "RON95 BUDI" as "RON95".
                    put(item("RON95 BUDI", "ron95_budi95"))
                    put(item("RON95", "ron95"))
                    put(item("RON97", "ron97"))
                    put(item("Diesel", "diesel"))
                })
            }
            sp.edit().putString(KEY_JSON, out.toString()).putLong(KEY_TIME, System.currentTimeMillis()).apply()
            out
        } catch (e: Throwable) {
            Log.w(TAG, "Fuel price fetch failed: ${e.message}")
            cached(context)
        }
    }
}
