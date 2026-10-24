package com.dashmate.dashmate

import android.content.Context
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.util.Log
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarColor
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.core.graphics.drawable.IconCompat

class DashMateCarScreen(carContext: CarContext) : Screen(carContext), SurfaceCallback {

    private val TAG = "DashMateCarScreen"
    private var virtualDisplay: VirtualDisplay? = null
    private var presentation: DashMatePresentation? = null
    private var isFullscreen: Boolean = false
    private var lastWidth: Int = 0
    private var lastHeight: Int = 0

    init {
        try {
            carContext.getCarService(AppManager::class.java).setSurfaceCallback(this)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register SurfaceCallback", e)
        }
    }

    override fun onGetTemplate(): Template {
        val fsIconRes = if (isFullscreen) R.drawable.dd_ic_fullscreen_exit else R.drawable.dd_ic_fullscreen
        val carIcon = CarIcon.Builder(IconCompat.createWithResource(carContext, fsIconRes)).build()

        val actionStrip = ActionStrip.Builder()
            .addAction(
                Action.Builder()
                    .setIcon(carIcon)
                    .setOnClickListener {
                        toggleFullscreen()
                    }
                    .build()
            )
            .build()

        return NavigationTemplate.Builder()
            .setActionStrip(actionStrip)
            .build()
    }

    private fun toggleFullscreen() {
        isFullscreen = !isFullscreen
        invalidate()
        presentation?.toggleFullscreen(isFullscreen)
    }

    override fun onSurfaceAvailable(surfaceContainer: SurfaceContainer) {
        val surface = surfaceContainer.surface
        if (surface == null) {
            Log.w(TAG, "onSurfaceAvailable: surface is null")
            return
        }

        val width = if (surfaceContainer.width > 0) surfaceContainer.width else 1280
        val height = if (surfaceContainer.height > 0) surfaceContainer.height else 720
        val dpi = if (surfaceContainer.dpi > 0) surfaceContainer.dpi else 160
        lastWidth = width
        lastHeight = height

        Log.d(TAG, "onSurfaceAvailable: ${width}x${height} dpi=$dpi")

        val displayManager = carContext.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager

        if (virtualDisplay != null && presentation != null) {
            Log.d(TAG, "Resizing existing VirtualDisplay to ${width}x${height} dpi=$dpi")
            try {
                virtualDisplay?.surface = surface
                virtualDisplay?.resize(width, height, dpi)
                presentation?.onSizeChanged(width, height)
                return
            } catch (e: Exception) {
                Log.w(TAG, "Error resizing virtual display, will recreate", e)
            }
        }

        presentation?.dismiss()
        virtualDisplay?.release()

        try {
            virtualDisplay = displayManager.createVirtualDisplay(
                "DashMateDeckDisplay",
                width,
                height,
                dpi,
                surface,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_PRESENTATION
            )

            val display = virtualDisplay?.display
            if (display != null) {
                presentation = DashMatePresentation(carContext, display).apply {
                    onOpenKeyboard = { initialText, hint, onSubmitted ->
                        carContext.getCarService(androidx.car.app.ScreenManager::class.java).push(
                            DashMateSearchScreen(carContext, initialText, hint, onSubmitted)
                        )
                    }
                }
                presentation?.show()
                Log.d(TAG, "Presentation successfully displayed on VirtualDisplay")
            } else {
                Log.e(TAG, "VirtualDisplay display is null")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing VirtualDisplay or Presentation", e)
        }
    }

    override fun onVisibleAreaChanged(visibleArea: Rect) {
        Log.d(TAG, "onVisibleAreaChanged: $visibleArea")
        presentation?.onVisibleAreaChanged(visibleArea)
    }

    override fun onStableAreaChanged(stableArea: Rect) {
        Log.d(TAG, "onStableAreaChanged: $stableArea")
        presentation?.onVisibleAreaChanged(stableArea)
    }

    override fun onSurfaceDestroyed(surfaceContainer: SurfaceContainer) {
        Log.d(TAG, "onSurfaceDestroyed")
        try {
            presentation?.dismiss()
            presentation = null
            virtualDisplay?.release()
            virtualDisplay = null
        } catch (e: Exception) {
            Log.e(TAG, "Error during surface destruction", e)
        }
    }

    override fun onClick(x: Float, y: Float) {
        Log.d(TAG, "onClick at ($x, $y)")
        presentation?.dispatchVirtualClick(x, y)
    }

    override fun onScroll(distanceX: Float, distanceY: Float) {
        presentation?.dispatchVirtualScroll(
            lastWidth / 2f,
            lastHeight / 2f,
            distanceX,
            distanceY
        )
    }

    override fun onFling(velocityX: Float, velocityY: Float) {
        presentation?.dispatchVirtualScroll(
            lastWidth / 2f,
            lastHeight / 2f,
            -velocityX / 10f,
            -velocityY / 10f
        )
    }

    override fun onScale(focusX: Float, focusY: Float, scaleFactor: Float) {
        // Can be used for zooming maps if needed
    }
}
