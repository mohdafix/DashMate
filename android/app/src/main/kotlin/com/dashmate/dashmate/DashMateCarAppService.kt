package com.dashmate.dashmate

import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

class DashMateCarAppService : CarAppService() {

    override fun createHostValidator(): HostValidator {
        // ALLOW_ALL_HOSTS_VALIDATOR allows running with Android Auto Desktop Head Unit (DHU)
        // and sideloaded testing without strict Google Play signature checks.
        return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
    }

    override fun onCreateSession(): Session {
        return DashMateSession()
    }
}
