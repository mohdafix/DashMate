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
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

data class PrayerZone(val code: String, val name: String, val lat: Double, val lon: Double)

object PrayerTimesManager {
    private const val TAG = "PrayerTimesManager"
    private const val PREFS_NAME = "DashMatePrefs"
    private const val PREF_ZONE_KEY = "prayer_zone"
    private const val PREF_CACHE_PREFIX = "dashmate_prayer_cache_"

    val ZONES = listOf(
        PrayerZone("WLY01", "Kuala Lumpur, Putrajaya", 3.1390, 101.6869),
        PrayerZone("SGR01", "Shah Alam, Petaling, Gombak", 3.0738, 101.5183),
        PrayerZone("JHR02", "Johor Bahru, Kota Tinggi", 1.4927, 103.7414),
        PrayerZone("PNG01", "Pulau Pinang", 5.4164, 100.3327),
        PrayerZone("PRK02", "Ipoh, Batu Gajah, Kampar", 4.5975, 101.0901),
        PrayerZone("MLK01", "Melaka", 2.1896, 102.2501),
        PrayerZone("NSN01", "Seremban, Port Dickson", 2.7258, 101.9424),
        PrayerZone("KDH01", "Alor Setar, Kota Setar", 6.1248, 100.3678),
        PrayerZone("TRG01", "Kuala Terengganu, Marang", 5.3117, 103.1324),
        PrayerZone("KTN01", "Kota Bharu, Bachok", 6.1254, 102.2386),
        PrayerZone("PLS01", "Kangar, Perlis", 6.4449, 100.1985),
        PrayerZone("PHG02", "Kuantan, Pekan", 3.8077, 103.3260),
        PrayerZone("SBH01", "Kota Kinabalu, Ranau", 5.9804, 116.0735),
        PrayerZone("SWK01", "Kuching, Bau, Lundu", 1.5533, 110.3592)
    )

    fun getSelectedZone(context: Context): PrayerZone {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val savedCode = prefs.getString(PREF_ZONE_KEY, "WLY01") ?: "WLY01"
        return ZONES.find { it.code.equals(savedCode, ignoreCase = true) } ?: ZONES[0]
    }

    fun setSelectedZone(context: Context, zoneCode: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString(PREF_ZONE_KEY, zoneCode).apply()
    }

    suspend fun getPrayerData(context: Context): JSONObject = withContext(Dispatchers.IO) {
        val zone = getSelectedZone(context)
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Asia/Kuala_Lumpur")
        }.format(Date())

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val cached = prefs.getString("$PREF_CACHE_PREFIX${zone.code}_$todayStr", null)
        if (!cached.isNullOrBlank()) {
            try {
                return@withContext enrichPrayerJson(JSONObject(cached), zone)
            } catch (_: Throwable) {}
        }

        var rawJson: JSONObject? = null
        try {
            val url = URL("https://api.waktusolat.app/v2/solat/${zone.code}")
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 4000
            conn.readTimeout = 4000
            conn.setRequestProperty("User-Agent", "DashMate-AndroidAuto/1.0")

            if (conn.responseCode == 200) {
                val reader = BufferedReader(InputStreamReader(conn.inputStream))
                val resp = reader.readText()
                reader.close()

                val apiObj = JSONObject(resp)
                val prayersArr = apiObj.optJSONArray("prayers")
                if (prayersArr != null && prayersArr.length() > 0) {
                    val cal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kuala_Lumpur"))
                    val currentDay = cal.get(Calendar.DAY_OF_MONTH)
                    var p: JSONObject? = null
                    for (i in 0 until prayersArr.length()) {
                        val item = prayersArr.getJSONObject(i)
                        if (item.optInt("day", -1) == currentDay) {
                            p = item
                            break
                        }
                    }
                    if (p == null) {
                        val idx = (currentDay - 1).coerceIn(0, prayersArr.length() - 1)
                        p = prayersArr.getJSONObject(idx)
                    }

                    val fajrSec = p.optLong("fajr", 0)
                    val syurukSec = p.optLong("syuruk", 0)
                    val dhuhrSec = p.optLong("dhuhr", 0)
                    val asrSec = p.optLong("asr", 0)
                    val maghribSec = p.optLong("maghrib", 0)
                    val ishaSec = p.optLong("isha", 0)
                    val imsakSec = if (fajrSec > 600) fajrSec - 600 else 0

                    rawJson = JSONObject().apply {
                        put("imsak", formatTimestampToHHmm(imsakSec))
                        put("subuh", formatTimestampToHHmm(fajrSec))
                        put("syuruk", formatTimestampToHHmm(syurukSec))
                        put("zohor", formatTimestampToHHmm(dhuhrSec))
                        put("asar", formatTimestampToHHmm(asrSec))
                        put("maghrib", formatTimestampToHHmm(maghribSec))
                        put("isyak", formatTimestampToHHmm(ishaSec))
                        put("imsak_epoch", imsakSec * 1000L)
                        put("subuh_epoch", fajrSec * 1000L)
                        put("syuruk_epoch", syurukSec * 1000L)
                        put("zohor_epoch", dhuhrSec * 1000L)
                        put("asar_epoch", asrSec * 1000L)
                        put("maghrib_epoch", maghribSec * 1000L)
                        put("isyak_epoch", ishaSec * 1000L)
                    }
                    prefs.edit().putString("$PREF_CACHE_PREFIX${zone.code}_$todayStr", rawJson.toString()).apply()
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "Network fetch failed for prayer times: ${e.message}")
        }

        if (rawJson == null) {
            rawJson = calculateFallbackPrayers(zone)
        }

        return@withContext enrichPrayerJson(rawJson, zone)
    }

    private fun formatTimestampToHHmm(epochSec: Long): String {
        if (epochSec <= 0) return "00:00"
        val df = SimpleDateFormat("HH:mm", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Asia/Kuala_Lumpur")
        }
        return df.format(Date(epochSec * 1000L))
    }

    private fun calculateFallbackPrayers(zone: PrayerZone): JSONObject {
        val cal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kuala_Lumpur"))
        fun epochFor(h: Int, m: Int): Long {
            val c = cal.clone() as Calendar
            c.set(Calendar.HOUR_OF_DAY, h)
            c.set(Calendar.MINUTE, m)
            c.set(Calendar.SECOND, 0)
            c.set(Calendar.MILLISECOND, 0)
            return c.timeInMillis
        }
        return JSONObject().apply {
            put("imsak", "05:39")
            put("subuh", "05:49")
            put("syuruk", "06:56")
            put("zohor", "13:00")
            put("asar", "16:19")
            put("maghrib", "18:59")
            put("isyak", "20:10")
            put("imsak_epoch", epochFor(5, 39))
            put("subuh_epoch", epochFor(5, 49))
            put("syuruk_epoch", epochFor(6, 56))
            put("zohor_epoch", epochFor(13, 0))
            put("asar_epoch", epochFor(16, 19))
            put("maghrib_epoch", epochFor(18, 59))
            put("isyak_epoch", epochFor(20, 10))
        }
    }

    private fun enrichPrayerJson(prayersObj: JSONObject, zone: PrayerZone): JSONObject {
        val result = JSONObject()
        result.put("status", "ok")
        result.put("zone", "${zone.code} · ${zone.name}")
        result.put("zoneName", zone.name)

        val cal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kuala_Lumpur"))
        val dfDate = SimpleDateFormat("EEEE, d MMM", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Asia/Kuala_Lumpur")
        }
        result.put("date", dfDate.format(cal.time))

        val nowMs = System.currentTimeMillis()

        val prayersList = listOf(
            Triple("Imsak", prayersObj.optString("imsak", "05:39"), false),
            Triple("Subuh", prayersObj.optString("subuh", "05:49"), true),
            Triple("Syuruk", prayersObj.optString("syuruk", "06:56"), false),
            Triple("Zohor", prayersObj.optString("zohor", "13:00"), true),
            Triple("Asar", prayersObj.optString("asar", "16:19"), true),
            Triple("Maghrib", prayersObj.optString("maghrib", "18:59"), true),
            Triple("Isyak", prayersObj.optString("isyak", "20:10"), true)
        )

        val timesArr = JSONArray()
        var currentPrayerObj: JSONObject? = null
        var nextPrayerObj: JSONObject? = null
        var minutesRemaining = 0

        for (triple in prayersList) {
            val name = triple.first
            val timeStr = triple.second
            val obligatory = triple.third
            val cachedEpoch = prayersObj.optLong("${name.lowercase()}_epoch", 0L)
            val pEpochMs = if (cachedEpoch > 0) cachedEpoch else {
                val parts = timeStr.split(":")
                val pHour = parts.getOrNull(0)?.toIntOrNull() ?: 0
                val pMin = parts.getOrNull(1)?.toIntOrNull() ?: 0
                val pCal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kuala_Lumpur")).apply {
                    set(Calendar.HOUR_OF_DAY, pHour)
                    set(Calendar.MINUTE, pMin)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                pCal.timeInMillis
            }

            val pItem = JSONObject().apply {
                put("name", name)
                put("time", timeStr)
                put("epochMs", pEpochMs)
                put("obligatory", obligatory)
            }
            timesArr.put(pItem)

            if (pEpochMs <= nowMs) {
                currentPrayerObj = pItem
            } else if (nextPrayerObj == null) {
                nextPrayerObj = pItem
                minutesRemaining = ((pEpochMs - nowMs) / 60000L).toInt().coerceAtLeast(1)
            }

            result.put(name.lowercase(), timeStr)
        }

        // If after Isyak, next is tomorrow's Subuh
        if (nextPrayerObj == null) {
            val subuhParts = prayersList[1].second.split(":")
            val subuhHour = subuhParts.getOrNull(0)?.toIntOrNull() ?: 5
            val subuhMin = subuhParts.getOrNull(1)?.toIntOrNull() ?: 49

            val tomorrowCal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kuala_Lumpur")).apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, subuhHour)
                set(Calendar.MINUTE, subuhMin)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            minutesRemaining = ((tomorrowCal.timeInMillis - nowMs) / 60000L).toInt().coerceAtLeast(1)

            nextPrayerObj = JSONObject().apply {
                put("name", "Subuh")
                put("time", prayersList[1].second)
                put("epochMs", tomorrowCal.timeInMillis)
                put("obligatory", true)
            }
        }

        if (currentPrayerObj == null) {
            // Before Subuh: current is yesterday's Isyak
            val isyakParts = prayersList[6].second.split(":")
            val isyakHour = isyakParts.getOrNull(0)?.toIntOrNull() ?: 20
            val isyakMin = isyakParts.getOrNull(1)?.toIntOrNull() ?: 10
            val yesterdayCal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Kuala_Lumpur")).apply {
                add(Calendar.DAY_OF_YEAR, -1)
                set(Calendar.HOUR_OF_DAY, isyakHour)
                set(Calendar.MINUTE, isyakMin)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            currentPrayerObj = JSONObject().apply {
                put("name", "Isyak")
                put("time", prayersList[6].second)
                put("epochMs", yesterdayCal.timeInMillis)
                put("obligatory", true)
            }
        }

        val hours = minutesRemaining / 60
        val mins = minutesRemaining % 60
        val formattedCountdown = if (hours > 0) "${hours}h ${mins}m" else "${mins}m"

        result.put("times", timesArr)
        result.put("current", currentPrayerObj)
        result.put("next", nextPrayerObj)
        result.put("time", nextPrayerObj.optString("time", "05:49"))
        result.put("count", formattedCountdown)
        result.put("countMin", minutesRemaining)

        return result
    }
}
