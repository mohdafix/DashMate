package com.dashmate.dashmate

import android.content.Intent
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.dashmate.dashmate.deck.ParkingAutoSaver
import com.dashmate.dashmate.deck.PrayerAlertManager

class DashMateSession : Session() {

    companion object {
        @Volatile var isSessionActive: Boolean = false
    }

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onCreate(owner: LifecycleOwner) {
                isSessionActive = true
                CarNav.attach(carContext)
                val app = carContext.applicationContext
                ParkingAutoSaver.start(app)
                PrayerAlertManager.scheduleAsync(app)
                DashMateStateBridge.notifyStateChanged(app)
            }

            override fun onDestroy(owner: LifecycleOwner) {
                isSessionActive = false
                val app = carContext.applicationContext
                ParkingAutoSaver.onCarSessionEnded(app)
                CarNav.detach()
                DashMateStateBridge.notifyStateChanged(app)
            }
        })
    }

    override fun onCreateScreen(intent: Intent): Screen {
        return DashMateCarScreen(carContext)
    }
}
