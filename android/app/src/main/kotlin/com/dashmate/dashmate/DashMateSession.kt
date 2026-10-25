package com.dashmate.dashmate

import android.content.Intent
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.dashmate.dashmate.deck.ParkingAutoSaver
import com.dashmate.dashmate.deck.PrayerAlertManager

class DashMateSession : Session() {

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onCreate(owner: LifecycleOwner) {
                CarNav.attach(carContext)
                val app = carContext.applicationContext
                ParkingAutoSaver.start(app)
                PrayerAlertManager.scheduleAsync(app)
            }

            override fun onDestroy(owner: LifecycleOwner) {
                ParkingAutoSaver.onCarSessionEnded(carContext.applicationContext)
                CarNav.detach()
            }
        })
    }

    override fun onCreateScreen(intent: Intent): Screen {
        return DashMateCarScreen(carContext)
    }
}
