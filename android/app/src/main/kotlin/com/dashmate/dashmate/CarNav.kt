package com.dashmate.dashmate

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.car.app.CarContext
import kotlinx.coroutines.launch
import java.lang.ref.WeakReference

/**
 * Hands navigation to Waze (or Google Maps) from the car.
 *
 * Android Auto only sends CarContext.ACTION_NAVIGATE to the navigation app that is
 * currently running, which is DashMate Deck itself, and it refuses to start another
 * car app explicitly. So we use Waze's own deep link (...&navigate=yes):
 * Waze starts the route and takes over the car screen. Google Maps' navigation
 * link is the fallback.
 */
object CarNav {
    private const val TAG = "CarNav"
    private const val WAZE = "com.waze"
    private val main = Handler(Looper.getMainLooper())
    private var carContextRef: WeakReference<CarContext>? = null

    fun attach(carContext: CarContext) {
        carContextRef = WeakReference(carContext)
    }

    fun detach() {
        carContextRef = null
    }

    val carSessionActive: Boolean get() = carContextRef?.get() != null

    /** The owner's choice on the Navigation page: "waze" (default) or "maps" (Google Maps). */
    private const val NAV_APP_KEY = "nav_app"
    fun navApp(context: Context): String =
        context.getSharedPreferences("dd_car_browser", Context.MODE_PRIVATE).getString(NAV_APP_KEY, "waze") ?: "waze"
    fun setNavApp(context: Context, app: String) {
        context.getSharedPreferences("dd_car_browser", Context.MODE_PRIVATE).edit()
            .putString(NAV_APP_KEY, if (app == "maps") "maps" else "waze").apply()
    }

    fun toCoords(context: Context, lat: Double, lng: Double, label: String? = null) {
        launch(
            context,
            waze = "https://waze.com/ul?ll=$lat,$lng&navigate=yes",
            maps = "google.navigation:q=$lat,$lng",
            web = "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng",
        )
    }

    /** Free-text search near you, e.g. "masjid" or "petrol station". */
    fun toQuery(context: Context, query: String) {
        val enc = Uri.encode(query)
        launch(
            context,
            waze = "https://waze.com/ul?q=$enc&navigate=yes",
            maps = "google.navigation:q=$enc",
            web = "https://www.google.com/maps/search/?api=1&query=$enc",
        )
    }

    private val io = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.IO)

    /** Nearest masjid / petrol station as exact coordinates (Waze then starts the route by itself). */
    fun toNearest(context: Context, kind: com.dashmate.dashmate.deck.NearbyFinder.Kind) {
        val app = context.applicationContext
        io.launch {
            val place = com.dashmate.dashmate.deck.NearbyFinder.nearest(app, kind)
            if (place != null) toCoords(app, place.lat, place.lng, place.name)
            else toQuery(app, kind.label) // no location / offline: fall back to a search
        }
    }

    private fun installed(ctx: Context, pkg: String) = try {
        ctx.packageManager.getPackageInfo(pkg, 0); true
    } catch (e: Exception) { false }

    private fun launch(context: Context, waze: String, maps: String, web: String) {
        main.post {
            val ctx = context.applicationContext
            val wazeIntent = if (installed(ctx, WAZE)) Intent(Intent.ACTION_VIEW, Uri.parse(waze)).setPackage(WAZE) else null
            val mapsIntent = Intent(Intent.ACTION_VIEW, Uri.parse(maps)).setPackage("com.google.android.apps.maps")
            // The chosen app first, the other as a backup, a web link last.
            val attempts = (if (navApp(ctx) == "maps") listOf(mapsIntent, wazeIntent) else listOf(wazeIntent, mapsIntent))
                .filterNotNull() + Intent(Intent.ACTION_VIEW, Uri.parse(web))
            for (i in attempts) {
                try {
                    ctx.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    Log.i(TAG, "Navigation handed to ${i.`package` ?: "browser"}: ${i.data}")
                    return@post
                } catch (e: Exception) {
                    Log.w(TAG, "Could not open ${i.data}: ${e.message}")
                }
            }
        }
    }
}
