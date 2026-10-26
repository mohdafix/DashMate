package com.dashmate.dashmate.deck

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat
import org.json.JSONObject

/**
 * The car's position for the Home map card: GPS (and network as a fallback), every ~2 s.
 * Listens only while the car screen asks for it (the map card polls), and stops when the car
 * screen closes.
 */
object CarLocation {
    private const val TAG = "DashMateLocation"
    @Volatile private var last: Location? = null
    private var listening = false
    private var lastAskMs = 0L

    private val listener = LocationListener { loc ->
        val prev = last
        // Keep a GPS fix over a rougher network one unless the GPS fix is old (> 10 s).
        if (prev == null || loc.provider == LocationManager.GPS_PROVIDER || prev.provider != LocationManager.GPS_PROVIDER ||
            loc.elapsedRealtimeNanos - prev.elapsedRealtimeNanos > 10_000_000_000L) last = loc
    }

    /** Latest fix as JSON ({lat, lng, acc, bearing, ageMs}), or "" when there is none yet. */
    fun json(ctx: Context): String {
        lastAskMs = SystemClock.elapsedRealtime()
        start(ctx)
        val l = last ?: return ""
        return JSONObject().apply {
            put("lat", l.latitude)
            put("lng", l.longitude)
            put("acc", if (l.hasAccuracy()) l.accuracy.toDouble() else -1.0)
            put("bearing", if (l.hasBearing() && l.hasSpeed() && l.speed > 1.5f) l.bearing.toDouble() else -1.0)
            put("ageMs", (SystemClock.elapsedRealtimeNanos() - l.elapsedRealtimeNanos) / 1_000_000L)
        }.toString()
    }

    @SuppressLint("MissingPermission")
    private fun start(ctx: Context) {
        if (listening) return
        val app = ctx.applicationContext
        val ok = ContextCompat.checkSelfPermission(app, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(app, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!ok) return
        val lm = app.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return
        try {
            for (p in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
                if (!lm.isProviderEnabled(p)) continue
                lm.requestLocationUpdates(p, 2_000L, 0f, listener, Looper.getMainLooper())
                lm.getLastKnownLocation(p)?.let { listener.onLocationChanged(it) }
            }
            listening = true
        } catch (e: Exception) {
            Log.w(TAG, "Location updates failed: ${e.message}")
        }
    }

    /** The car screen closed: stop listening (saves battery). */
    fun stop(ctx: Context) {
        if (!listening) return
        try {
            (ctx.applicationContext.getSystemService(Context.LOCATION_SERVICE) as? LocationManager)?.removeUpdates(listener)
        } catch (_: Exception) {
        }
        listening = false
    }
}
