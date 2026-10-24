package com.dashmate.dashmate.deck

import android.content.Context
import org.json.JSONObject

object LocalizationManager {
    private const val PREFS_NAME = "DashMatePrefs"
    private const val KEY_LANG = "dashmate_language"

    fun getLanguage(context: Context): String {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_LANG, "en") ?: "en"
    }

    fun setLanguage(context: Context, lang: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LANG, lang)
            .apply()
    }

    fun getLabels(lang: String): JSONObject {
        val root = JSONObject()
        val isMs = lang == "ms"

        root.put("lang", if (isMs) "ms" else "en")
        root.put("today", if (isMs) "Hari ini" else "Today")
        root.put("tomorrow", if (isMs) "Esok" else "Tomorrow")
        root.put("now", if (isMs) "Sekarang" else "Now")
        root.put("allDay", if (isMs) "Sepanjang hari" else "All day")
        root.put("happeningNow", if (isMs) "Sedang berlaku" else "Happening now")
        root.put("noEvents", if (isMs) "Tiada acara minggu ini" else "No events this week")
        root.put("calAccess", if (isMs) "Benarkan akses kalendar dalam aplikasi DashMate" else "Allow calendar access in the DashMate app")

        // Weather
        root.put("clear", if (isMs) "Cerah" else "Clear")
        root.put("partlyCloudy", if (isMs) "Separa Berawan" else "Partly cloudy")
        root.put("cloudy", if (isMs) "Mendung" else "Cloudy")
        root.put("hazy", if (isMs) "Jerebu" else "Hazy")
        root.put("drizzle", if (isMs) "Hujan Renyai" else "Drizzle")
        root.put("rain", if (isMs) "Hujan" else "Rain")
        root.put("showers", if (isMs) "Hujan Lebat" else "Showers")
        root.put("thunder", if (isMs) "Ribut Petir" else "Thunderstorm")
        root.put("feelsLike", if (isMs) "Terasa seperti" else "Feels like")
        root.put("noRainSoon", if (isMs) "Tiada hujan diramalkan" else "No rain expected soon")
        root.put("humidity", if (isMs) "Kelembapan" else "Humidity")
        root.put("wind", if (isMs) "Angin" else "Wind")
        root.put("noData", if (isMs) "Tiada data ramalan" else "No forecast yet")

        // Air Quality
        root.put("airQuality", if (isMs) "Kualiti Udara" else "Air quality")
        root.put("aqi_Good", if (isMs) "Baik" else "Good")
        root.put("aqi_Moderate", if (isMs) "Sederhana" else "Moderate")
        root.put("aqi_Sensitive", if (isMs) "Sensitif" else "Sensitive")
        root.put("aqi_Unhealthy", if (isMs) "Tidak Sihat" else "Unhealthy")
        root.put("aqi_Very unhealthy", if (isMs) "Sangat Tidak Sihat" else "Very unhealthy")
        root.put("aqi_Hazardous", if (isMs) "Berbahaya" else "Hazardous")

        // UV
        root.put("uv_Low", if (isMs) "Rendah" else "Low")
        root.put("uv_Moderate", if (isMs) "Sederhana" else "Moderate")
        root.put("uv_High", if (isMs) "Tinggi" else "High")
        root.put("uv_Very high", if (isMs) "Sangat Tinggi" else "Very high")
        root.put("uv_Extreme", if (isMs) "Ekstrem" else "Extreme")

        // Radar & Sports
        root.put("rainRadar", if (isMs) "Radar Hujan" else "Rain radar")
        root.put("noRadar", if (isMs) "Radar tidak tersedia" else "Radar unavailable")
        root.put("sports", if (isMs) "Sukan" else "Sports")
        root.put("live", if (isMs) "Langsung" else "Live")
        root.put("noGames", if (isMs) "Tiada perlawanan hari ini" else "No games today")
        root.put("pickTeams", if (isMs) "Pilih pasukan kegemaran anda" else "Pick favourite teams in DashMate settings")

        return root
    }
}
