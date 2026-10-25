package com.dashmate.dashmate.deck

import android.content.Context
import org.json.JSONObject

object LocalizationManager {
    private const val PREFS_NAME = "DashMatePrefs"
    private const val KEY_LANG = "dashmate_language"

    fun getLanguage(context: Context): String =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_LANG, "en") ?: "en"

    fun setLanguage(context: Context, lang: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().putString(KEY_LANG, lang).apply()
    }

    fun getLabels(lang: String): JSONObject {
        val root = JSONObject()
        val isMs = lang == "ms"
        fun t(ms: String, en: String) = if (isMs) ms else en

        root.put("lang", t("ms", "en"))
        root.put("today", t("Hari ini", "Today"))
        root.put("tomorrow", t("Esok", "Tomorrow"))
        root.put("now", t("Sekarang", "Now"))
        root.put("allDay", t("Sepanjang hari", "All day"))
        root.put("happeningNow", t("Sedang berlaku", "Happening now"))
        root.put("noEvents", t("Tiada acara minggu ini", "No events this week"))
        root.put("calAccess", t("Benarkan akses kalendar dalam aplikasi DashMate", "Allow calendar access in the DashMate app"))
        root.put("clear", t("Cerah", "Clear"))
        root.put("partlyCloudy", t("Separa Berawan", "Partly cloudy"))
        root.put("cloudy", t("Mendung", "Cloudy"))
        root.put("hazy", t("Jerebu", "Hazy"))
        root.put("drizzle", t("Hujan Renyai", "Drizzle"))
        root.put("rain", t("Hujan", "Rain"))
        root.put("showers", t("Hujan Lebat", "Showers"))
        root.put("thunder", t("Ribut Petir", "Thunderstorm"))
        root.put("feelsLike", t("Terasa seperti", "Feels like"))
        root.put("noRainSoon", t("Tiada hujan diramalkan", "No rain expected soon"))
        root.put("humidity", t("Kelembapan", "Humidity"))
        root.put("wind", t("Angin", "Wind"))
        root.put("noData", t("Tiada data ramalan", "No forecast yet"))
        root.put("airQuality", t("Kualiti Udara", "Air quality"))
        root.put("aqi_Good", t("Baik", "Good"))
        root.put("aqi_Moderate", t("Sederhana", "Moderate"))
        root.put("aqi_Sensitive", t("Sensitif", "Sensitive"))
        root.put("aqi_Unhealthy", t("Tidak Sihat", "Unhealthy"))
        root.put("aqi_Very unhealthy", t("Sangat Tidak Sihat", "Very unhealthy"))
        root.put("aqi_Hazardous", t("Berbahaya", "Hazardous"))
        root.put("uv_Low", t("Rendah", "Low"))
        root.put("uv_Moderate", t("Sederhana", "Moderate"))
        root.put("uv_High", t("Tinggi", "High"))
        root.put("uv_Very high", t("Sangat Tinggi", "Very high"))
        root.put("uv_Extreme", t("Ekstrem", "Extreme"))
        root.put("rainRadar", t("Radar Hujan", "Rain radar"))
        root.put("noRadar", t("Radar tidak tersedia", "Radar unavailable"))
        root.put("sports", t("Sukan", "Sports"))
        root.put("live", t("Langsung", "Live"))
        root.put("noGames", t("Tiada perlawanan hari ini", "No games today"))
        root.put("pickTeams", t("Pilih pasukan kegemaran anda", "Pick favourite teams in DashMate settings"))
        return root
    }
}
