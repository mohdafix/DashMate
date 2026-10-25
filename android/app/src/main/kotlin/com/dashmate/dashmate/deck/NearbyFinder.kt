package com.dashmate.dashmate.deck

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL

/**
 * Finds the nearest masjid / petrol station around the current location using
 * OpenStreetMap's Nominatim search (free, no key). Returning exact coordinates
 * lets Waze start the route straight away instead of showing a search list.
 */
object NearbyFinder {
    private const val TAG = "NearbyFinder"
    private const val RADIUS_DEG = 0.045 // ~5 km box around you

    data class Place(val name: String, val lat: Double, val lng: Double, val distanceM: Float)

    enum class Kind(val terms: List<String>, val label: String) {
        MASJID(listOf("mosque", "masjid", "surau"), "masjid"),
        PETROL(listOf("petrol station", "fuel"), "petrol station"),
    }

    @SuppressLint("MissingPermission")
    fun currentLocation(ctx: Context): Location? = try {
        val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
            .mapNotNull { p -> try { lm.getLastKnownLocation(p) } catch (e: Exception) { null } }
            .maxByOrNull { it.time }
    } catch (e: Exception) { null }

    suspend fun nearest(ctx: Context, kind: Kind): Place? = withContext(Dispatchers.IO) {
        val here = currentLocation(ctx) ?: return@withContext null
        val box = "${here.longitude - RADIUS_DEG},${here.latitude + RADIUS_DEG}," +
            "${here.longitude + RADIUS_DEG},${here.latitude - RADIUS_DEG}"
        val found = mutableListOf<Place>()
        for (term in kind.terms) {
            try {
                val url = "https://nominatim.openstreetmap.org/search?format=jsonv2&limit=8&bounded=1" +
                    "&viewbox=$box&q=" + Uri.encode(term)
                val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 6000; readTimeout = 6000
                    setRequestProperty("User-Agent", "DashMateDeck/1.0 (personal Android Auto app)")
                }
                val arr = JSONArray(conn.inputStream.bufferedReader().use { it.readText() })
                conn.disconnect()
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    val lat = o.optString("lat").toDoubleOrNull() ?: continue
                    val lng = o.optString("lon").toDoubleOrNull() ?: continue
                    val d = FloatArray(1)
                    Location.distanceBetween(here.latitude, here.longitude, lat, lng, d)
                    found += Place(o.optString("name").ifBlank { kind.label }, lat, lng, d[0])
                }
            } catch (e: Exception) {
                Log.w(TAG, "Search '$term' failed: ${e.message}")
            }
        }
        found.minByOrNull { it.distanceM }?.also { Log.i(TAG, "Nearest ${kind.label}: ${it.name} (${it.distanceM.toInt()} m)") }
    }
}
