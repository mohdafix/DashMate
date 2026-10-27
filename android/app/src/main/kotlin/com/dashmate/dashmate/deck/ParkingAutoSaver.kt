package com.dashmate.dashmate.deck

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Looper
import android.util.Log
import androidx.car.app.connection.CarConnection
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Observer
import com.dashmate.dashmate.MainActivity
import com.dashmate.dashmate.R

/**
 * Saves the parking spot automatically when the phone disconnects from the car.
 *
 * While the DashMate Deck car session runs we keep the latest location fix
 * (the app counts as "in use" while shown on the car screen). When Android Auto
 * reports NOT_CONNECTED we store that fix via ParkingManager and post a
 * "Parked" notification with a running timer and a Navigate-back button.
 */
object ParkingAutoSaver {
    private const val TAG = "ParkingAutoSaver"
    private const val CHANNEL_ID = "dashmate_parking"
    const val NOTIF_ID = 3101
    private const val PREFS = "DashMatePrefs"
    private const val KEY_ENABLED = "auto_park_enabled"
    private const val MAX_FIX_AGE_MS = 15 * 60 * 1000L

    private var appContext: Context? = null
    private var lastFix: Location? = null
    private var wasConnected = false
    private var observing = false
    private var listening = false
    private var carConnection: CarConnection? = null

    private val connectionObserver = Observer<Int> { type ->
        val ctx = appContext ?: return@Observer
        val connected = type != CarConnection.CONNECTION_TYPE_NOT_CONNECTED
        Log.d(TAG, "Car connection type=$type (wasConnected=$wasConnected)")
        if (connected) {
            if (!wasConnected) clearAutoSavedSpot(ctx) // driving away: the old auto-saved spot is stale
            wasConnected = true
            startLocationUpdates(ctx)
        } else if (wasConnected) {
            wasConnected = false
            stopLocationUpdates(ctx)
            saveNow(ctx)
        }
    }

    private val locationListener = LocationListener { loc ->
        if (lastFix == null || loc.accuracy <= (lastFix?.accuracy ?: Float.MAX_VALUE) + 30 ||
            loc.time - (lastFix?.time ?: 0L) > 30_000L
        ) {
            lastFix = loc
        }
    }

    fun isConnected(): Boolean = wasConnected

    fun isEnabled(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, true)

    fun setEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    private const val AUTO_NOTE = "Auto-saved when the car disconnected"

    private fun clearAutoSavedSpot(ctx: Context) {
        val spot = ParkingManager.getSpot(ctx) ?: return
        if (spot.notes == AUTO_NOTE) {
            ParkingManager.clearSpot(ctx)
            (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIF_ID)
        }
    }

    /** Call from the car session (main thread). Safe to call repeatedly. */
    fun start(context: Context) {
        val ctx = context.applicationContext
        appContext = ctx
        if (!wasConnected) clearAutoSavedSpot(ctx)
        if (!observing) {
            observing = true
            val conn = carConnection ?: CarConnection(ctx).also { carConnection = it }
            conn.type.observeForever(connectionObserver)
        }
        wasConnected = true
        startLocationUpdates(ctx)
    }

    /** Car session ended: Android Auto usually unbinds right as the car disconnects. */
    fun onCarSessionEnded(context: Context) {
        // CarConnection will confirm the disconnect; keep the fix we have.
        lastFix?.let { Log.d(TAG, "Session ended with fix acc=${it.accuracy}") }
    }

    fun stop() {
        if (observing) {
            carConnection?.type?.removeObserver(connectionObserver)
            observing = false
        }
        appContext?.let { stopLocationUpdates(it) }
    }

    private fun hasLocationPermission(ctx: Context) =
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission")
    private fun startLocationUpdates(ctx: Context) {
        if (listening || !hasLocationPermission(ctx)) return
        val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return
        try {
            for (p in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
                if (lm.isProviderEnabled(p)) {
                    lm.requestLocationUpdates(p, 10_000L, 15f, locationListener, Looper.getMainLooper())
                    lm.getLastKnownLocation(p)?.let { locationListener.onLocationChanged(it) }
                }
            }
            listening = true
        } catch (e: Exception) {
            Log.w(TAG, "Location updates failed: ${e.message}")
        }
    }

    private fun stopLocationUpdates(ctx: Context) {
        if (!listening) return
        try {
            (ctx.getSystemService(Context.LOCATION_SERVICE) as? LocationManager)?.removeUpdates(locationListener)
        } catch (_: Exception) {
        }
        listening = false
    }

    @SuppressLint("MissingPermission")
    fun saveNow(ctx: Context) {
        if (!isEnabled(ctx)) return
        var fix = lastFix
        if (fix == null || System.currentTimeMillis() - fix.time > MAX_FIX_AGE_MS) {
            if (hasLocationPermission(ctx)) {
                val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                fix = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
                    .mapNotNull { p -> try { lm?.getLastKnownLocation(p) } catch (e: Exception) { null } }
                    .maxByOrNull { it.time }
            }
        }
        if (fix == null) {
            Log.w(TAG, "No location fix — parking spot not saved")
            return
        }
        val spot = ParkingManager.saveSpot(ctx, fix.latitude, fix.longitude, "", "", AUTO_NOTE)
        Log.i(TAG, "Parking auto-saved at ${spot.lat},${spot.lng}")
        lastFix = null
        showParkedNotification(ctx, spot)
        try {
            com.dashmate.dashmate.DashMateStateBridge.notifyStateChanged(ctx)
        } catch (_: Throwable) {
        }
    }

    fun showParkedNotification(ctx: Context, spot: ParkingManager.ParkingSpot) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Parking", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Where you parked and how long ago"
                }
            )
        }
        val navIntent = Intent(Intent.ACTION_VIEW, Uri.parse("google.navigation:q=${spot.lat},${spot.lng}&mode=w"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val navPi = PendingIntent.getActivity(ctx, 1, navIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val openPi = PendingIntent.getActivity(
            ctx, 2, Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val n = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Car parked")
            .setContentText("Tap Navigate to walk back to your car")
            .setWhen(spot.timestamp)
            .setShowWhen(true)
            .setUsesChronometer(true) // live "parked for" timer
            .setOngoing(false)
            .setContentIntent(openPi)
            .addAction(0, "Navigate back", navPi)
            .build()
        try {
            nm.notify(NOTIF_ID, n)
        } catch (e: SecurityException) {
            Log.w(TAG, "Notification permission missing")
        }
    }
}
