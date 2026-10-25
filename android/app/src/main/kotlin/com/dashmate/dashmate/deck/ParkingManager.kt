package com.dashmate.dashmate.deck

import android.content.Context
import android.content.Intent
import android.net.Uri
import org.json.JSONObject

object ParkingManager {
    private const val PREFS_NAME = "DashMateParkingPrefs"
    private const val KEY_SPOT = "dashmate_parking_spot"

    data class ParkingSpot(
        val lat: Double,
        val lng: Double,
        val bay: String,
        val level: String,
        val notes: String,
        val timestamp: Long,
    )

    fun saveSpot(
        context: Context,
        lat: Double,
        lng: Double,
        bay: String,
        level: String,
        notes: String,
    ): ParkingSpot {
        val spot = ParkingSpot(lat, lng, bay, level, notes, System.currentTimeMillis())
        val json = JSONObject()
        json.put("lat", spot.lat)
        json.put("lng", spot.lng)
        json.put("bay", spot.bay)
        json.put("level", spot.level)
        json.put("notes", spot.notes)
        json.put("timestamp", spot.timestamp)
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().putString(KEY_SPOT, json.toString()).apply()
        return spot
    }

    fun getSpot(context: Context): ParkingSpot? {
        val str = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_SPOT, null) ?: return null
        return try {
            val json = JSONObject(str)
            ParkingSpot(
                lat = json.optDouble("lat", 0.0),
                lng = json.optDouble("lng", 0.0),
                bay = json.optString("bay", ""),
                level = json.optString("level", ""),
                notes = json.optString("notes", ""),
                timestamp = json.optLong("timestamp", 0L),
            )
        } catch (e: Exception) {
            null
        }
    }

    fun clearSpot(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().remove(KEY_SPOT).apply()
    }

    fun navigateBack(context: Context) {
        val spot = getSpot(context) ?: return
        if (com.dashmate.dashmate.CarNav.carSessionActive) {
            com.dashmate.dashmate.CarNav.toCoords(context, spot.lat, spot.lng, "My car")
            return
        }
        try {
            val gmmIntentUri = Uri.parse("google.navigation:q=${spot.lat},${spot.lng}")
            val mapIntent = Intent(Intent.ACTION_VIEW, gmmIntentUri)
            mapIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(mapIntent)
        } catch (e: Exception) {
            val webIntent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("https://maps.google.com/?q=${spot.lat},${spot.lng}")
            )
            webIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(webIntent)
        }
    }
}
