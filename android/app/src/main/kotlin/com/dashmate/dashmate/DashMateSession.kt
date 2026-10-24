package com.dashmate.dashmate

import android.content.Intent
import androidx.car.app.Screen
import androidx.car.app.Session

class DashMateSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen {
        return DashMateCarScreen(carContext)
    }
}
