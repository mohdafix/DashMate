package com.dashmate.dashmate.deck

// Originally declared in PrayerTimesManager.kt; split into its own file.
data class PrayerZone(
    val code: String,
    val name: String,
    val lat: Double,
    val lon: Double,
)
