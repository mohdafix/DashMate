package com.dashmate.dashmate

import android.app.Presentation
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.view.Display
import android.view.Gravity
import android.view.Surface
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.ScreenManager
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

/**
 * The car screen.
 *  - AUTO start (AA opened us on connect): finishCarApp() at once, before any surface work.
 *  - USER launch: the full deck ([DashMatePresentation]).
 *  - UNCERTAIN first session: the light "DashMate · Open" card (never the deck); one tap opens.
 * Exit tears everything down (radio, web pages) and finishes; the deck stays in AA's split panel.
 * See [DashMateCarLife] for the start rule.
 */
class DashMateCarScreen(
    carContext: CarContext,
    private val startIntent: Intent,
) : Screen(carContext), SurfaceCallback {

    private val TAG = DashMateCarLife.TAG
    private val main = Handler(Looper.getMainLooper())

    private var virtualDisplay: VirtualDisplay? = null
    private var presentation: DashMatePresentation? = null
    private var placeholder: ClosedCard? = null
    private var isFullscreen = false
    private var lastWidth = 0
    private var lastHeight = 0
    private var lastDpi = 0

    /** True when the owner wants the deck on screen. USER launches start with the deck. */
    private var userWantsDeck = false

    /** Until the start is classified, nothing is shown and the surface is not taken. */
    private var decided = false
    private var surfaceRegistered = false
    private var attempts = 0

    private val decideTick = object : Runnable {
        override fun run() {
            if (destroyed || decided) return
            val d = DashMateCarLife.tryDecide(carContext, startIntent, attempts)
            when {
                d != null -> applyStart(d)
                attempts * DECIDE_STEP_MS >= DashMateCarLife.SIGNAL_WAIT_MS -> applyStart(DashMateCarLife.timeoutDecision(carContext))
                else -> {
                    attempts++
                    main.postDelayed(this, DECIDE_STEP_MS)
                }
            }
        }
    }

    /** The owner did something explicit in this session (icon, Open button, tap, panel -> full). */
    private var userConfirmed = false
    private var closedByStop = false
    private var sawSurface = false
    private var lastWasPanel = false
    private var destroyed = false
    private var templateShowsDeck: Boolean? = null

    init {
        Log.i(TAG, "screen created, classifying the start")
        main.post(decideTick) // never finish from inside onCreateScreen
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                Log.i(TAG, "screen onStart")
                if (closedByStop) {
                    // Back after the AA home button: the owner tapped DashMate again.
                    closedByStop = false
                    requestOpen("back on screen after home")
                }
            }

            override fun onStop(owner: LifecycleOwner) {
                val onTop = try {
                    carContext.getCarService(ScreenManager::class.java).top === this@DashMateCarScreen
                } catch (_: Exception) {
                    true
                }
                Log.i(TAG, "screen onStop (onTop=$onTop)")
                // Our own keyboard / search screen on top also stops us: keep the deck then.
                if (!onTop) return
                if (userWantsDeck) closedByStop = true
                close("left the screen (AA home or another app)")
            }

            override fun onDestroy(owner: LifecycleOwner) {
                Log.i(TAG, "screen onDestroy")
                destroyed = true
                main.removeCallbacks(decideTick)
                teardown()
                try {
                    carContext.getCarService(AppManager::class.java).setSurfaceCallback(null)
                } catch (_: Exception) {
                }
            }
        })
    }

    // ------------------------------------------------------------------ open / close

    private fun applyStart(d: DashMateCarLife.StartDecision) {
        if (destroyed || decided) return
        decided = true
        main.removeCallbacks(decideTick)
        if (d.kind == DashMateCarLife.Kind.AUTO && !userConfirmed && DashMateCarLife.FINISH_ON_AUTO_START) {
            handBackToAndroidAuto() // never takes the surface
            return
        }
        userWantsDeck = true
        registerSurface()
        render()
    }

    private fun registerSurface() {
        if (surfaceRegistered) return
        surfaceRegistered = true
        try {
            carContext.getCarService(AppManager::class.java).setSurfaceCallback(this)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register SurfaceCallback", e)
        }
    }

    /** Owner asked for the deck (icon tap, Open button, tap on the closed card). */
    fun requestOpen(reason: String) {
        if (destroyed) return
        Log.i(TAG, "open requested: $reason")
        userConfirmed = true
        userWantsDeck = true
        if (!decided) {
            decided = true // an explicit tap settles it: the owner
            main.removeCallbacks(decideTick)
        }
        registerSurface()
        render()
    }

    private fun close(reason: String) {
        if (!userWantsDeck && presentation == null) return
        Log.i(TAG, "closing the deck: $reason")
        userWantsDeck = false
        render()
    }

    /** Android Auto opened us by itself on connect: give the screen straight back (AA app grid). */
    private fun handBackToAndroidAuto() {
        if (destroyed) return
        Log.i(TAG, "auto start -> finishCarApp (AA shows its app grid)")
        teardown()
        try {
            carContext.finishCarApp()
        } catch (e: Exception) {
            Log.w(TAG, "finishCarApp failed: ${e.message}")
        }
    }

    /** Red Exit in the dock: stop everything we started, then hand the screen back to AA. */
    private fun exitApp() {
        Log.i(TAG, "Exit pressed")
        userWantsDeck = false
        DashMateCarLife.markExit(carContext)
        DashMateMediaCardService.stopRadioForExit()
        teardown()
        try {
            carContext.finishCarApp()
        } catch (e: Exception) {
            Log.w(TAG, "finishCarApp failed: ${e.message}")
        }
    }

    /** Shows the deck or the closed card, whichever fits the current state. */
    private fun render() {
        if (destroyed) return
        val showDeck = userWantsDeck && !(CLOSE_IN_PANEL && lastWasPanel)
        val deckTemplate = userWantsDeck
        if (templateShowsDeck != deckTemplate) {
            templateShowsDeck = deckTemplate
            invalidate()
        }
        val display = virtualDisplay?.display ?: return
        if (showDeck) {
            if (presentation != null) return
            dismissPlaceholder()
            try {
                presentation = DashMatePresentation(carContext, display).apply {
                    // Red Exit button in the dock: close DashMate, back to the Android Auto screen.
                    onExit = { exitApp() }
                    onOpenKeyboard = { initialText, hint, onSubmitted ->
                        carContext.getCarService(ScreenManager::class.java)
                            .push(DashMateSearchScreen(carContext, initialText, hint, onSubmitted))
                    }
                }
                presentation?.show()
                if (isFullscreen) presentation?.toggleFullscreen(true)
                DashMateCarLife.markOpened(carContext)
                Log.i(TAG, "deck shown ${lastWidth}x$lastHeight")
            } catch (e: Exception) {
                Log.e(TAG, "Error showing the deck", e)
                presentation = null
            }
        } else {
            dismissDeck()
            if (placeholder != null) return
            try {
                placeholder = ClosedCard(carContext, display) { onClosedCardTapped() }.also { it.show() }
                Log.i(TAG, "closed card shown ${lastWidth}x$lastHeight (panel=$lastWasPanel)")
            } catch (e: Exception) {
                Log.e(TAG, "Error showing the closed card", e)
                placeholder = null
            }
        }
    }

    /** Any tap on the card (panel or full screen) opens the deck: one tap, always. */
    private fun onClosedCardTapped() {
        requestOpen("tap on the closed card")
    }

    private fun dismissDeck() {
        val p = presentation ?: return
        presentation = null
        try {
            p.dismiss() // destroys the deck + browser WebViews (stops any page audio)
        } catch (e: Exception) {
            Log.w(TAG, "deck dismiss: ${e.message}")
        }
    }

    private fun dismissPlaceholder() {
        val p = placeholder ?: return
        placeholder = null
        try {
            p.dismiss()
        } catch (_: Exception) {
        }
    }

    private fun teardown() {
        dismissDeck()
        dismissPlaceholder()
        try {
            virtualDisplay?.release()
        } catch (_: Exception) {
        }
        virtualDisplay = null
    }

    // ------------------------------------------------------------------ template

    override fun onGetTemplate(): Template {
        val actionStrip = ActionStrip.Builder()
        if (userWantsDeck) {
            val fsIconRes = if (isFullscreen) R.drawable.dd_ic_fullscreen_exit else R.drawable.dd_ic_fullscreen
            val carIcon = CarIcon.Builder(IconCompat.createWithResource(carContext, fsIconRes)).build()
            actionStrip.addAction(
                Action.Builder()
                    .setIcon(carIcon)
                    .setOnClickListener { toggleFullscreen() }
                    .build()
            )
        } else {
            actionStrip.addAction(
                Action.Builder()
                    .setTitle("Open DashMate")
                    .setOnClickListener { requestOpen("Open button") }
                    .build()
            )
        }
        return NavigationTemplate.Builder()
            .setActionStrip(actionStrip.build())
            .build()
    }

    private fun toggleFullscreen() {
        isFullscreen = !isFullscreen
        invalidate()
        presentation?.toggleFullscreen(isFullscreen)
    }

    // ------------------------------------------------------------------ surface

    override fun onSurfaceAvailable(surfaceContainer: SurfaceContainer) {
        val surface: Surface? = surfaceContainer.surface
        if (surface == null) {
            Log.w(TAG, "onSurfaceAvailable: surface is null")
            return
        }
        val width = if (surfaceContainer.width > 0) surfaceContainer.width else 1280
        val height = if (surfaceContainer.height > 0) surfaceContainer.height else 720
        val dpi = if (surfaceContainer.dpi > 0) surfaceContainer.dpi else 160
        val area = width.toLong() * height
        val full = maxOf(DashMateCarLife.fullArea(carContext, dpi), area)
        // AA's split / dashboard panel is ~57% of the full surface on an 800x480 DHU.
        val isPanel = area < full * 3 / 4
        Log.i(TAG, "onSurfaceAvailable ${width}x$height dpi=$dpi panel=$isPanel (full area=$full)")

        val wasPanel = lastWasPanel
        sawSurface = true
        lastWasPanel = isPanel
        lastWidth = width
        lastHeight = height
        lastDpi = dpi
        if (!isPanel) {
            DashMateCarLife.rememberFullArea(carContext, dpi, area)
            CarPreviewActivity.rememberCarScreen(carContext, width, height, dpi)
        }

        // Same surface resized, or a new one: reuse the VirtualDisplay when we can.
        var reused = false
        if (virtualDisplay != null) {
            try {
                virtualDisplay?.surface = surface
                virtualDisplay?.resize(width, height, dpi)
                presentation?.onSizeChanged(width, height)
                reused = true
            } catch (e: Exception) {
                Log.w(TAG, "Error resizing virtual display, will recreate", e)
                teardown()
            }
        }
        if (!reused) {
            try {
                val dm = carContext.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
                virtualDisplay = dm.createVirtualDisplay(
                    "DashMateDeckDisplay", width, height, dpi, surface,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_PRESENTATION,
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error creating VirtualDisplay", e)
                return
            }
        }

        when {
            // The deck stays in AA's split panel (Tall Car's small-panel layout). Only if the
            // owner chose to close it there does the card replace it.
            isPanel && CLOSE_IN_PANEL -> close("shown in the dashboard panel")
            // Panel -> full screen is the owner tapping the panel: one tap opens the deck.
            wasPanel && !isPanel && !userWantsDeck -> requestOpen("panel grew to full screen")
        }
        render()
    }

    override fun onVisibleAreaChanged(visibleArea: Rect) {
        Log.d(TAG, "onVisibleAreaChanged: $visibleArea")
        presentation?.onVisibleAreaChanged(visibleArea)
        if (!lastWasPanel) CarPreviewActivity.rememberVisibleArea(carContext, lastWidth, lastHeight, visibleArea)
    }

    override fun onStableAreaChanged(stableArea: Rect) {
        Log.d(TAG, "onStableAreaChanged: $stableArea")
        presentation?.onVisibleAreaChanged(stableArea)
    }

    override fun onSurfaceDestroyed(surfaceContainer: SurfaceContainer) {
        Log.i(TAG, "onSurfaceDestroyed")
        // Keep userWantsDeck: when the surface comes back full screen the deck is rebuilt fresh.
        teardown()
    }

    override fun onClick(x: Float, y: Float) {
        if (presentation == null) {
            onClosedCardTapped()
            return
        }
        presentation?.dispatchVirtualClick(x, y)
    }

    override fun onScroll(distanceX: Float, distanceY: Float) {
        presentation?.dispatchVirtualScroll(lastWidth / 2.0f, lastHeight / 2.0f, distanceX, distanceY)
    }

    override fun onFling(velocityX: Float, velocityY: Float) {
        presentation?.dispatchVirtualScroll(
            lastWidth / 2.0f,
            lastHeight / 2.0f,
            -velocityX / 10.0f,
            -velocityY / 10.0f,
        )
    }

    override fun onScale(focusX: Float, focusY: Float, scaleFactor: Float) {
    }
}

/** Show the closed card (not the deck) when AA shrinks DashMate into its split / dashboard panel. */
private const val CLOSE_IN_PANEL = false

/** Retry step while waiting for a live connection signal. */
private const val DECIDE_STEP_MS = 100L

/**
 * The "DashMate · Open" card shown when DashMate started by itself (no WebView, chime or media).
 * One tap anywhere, or on Open, opens the deck. Colours follow [DashMateTheme] day / night.
 */
private class ClosedCard(
    context: Context,
    display: Display,
    private val onTap: () -> Unit,
) : Presentation(context, display) {

    private lateinit var root: FrameLayout
    private lateinit var card: LinearLayout
    private lateinit var title: TextView
    private lateinit var open: TextView
    private val themeListener: (Boolean) -> Unit = { dark -> applyTheme(dark) }

    private fun dp(v: Float) = (v * context.resources.displayMetrics.density + 0.5f).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val icon = ImageView(context).apply {
            setImageResource(R.mipmap.ic_launcher)
            layoutParams = LinearLayout.LayoutParams(dp(72f), dp(72f)).apply { gravity = Gravity.CENTER_HORIZONTAL }
        }
        title = TextView(context).apply {
            text = "DashMate"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 30f)
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, dp(12f), 0, dp(20f))
        }
        open = TextView(context).apply {
            text = "Open"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            gravity = Gravity.CENTER
            minHeight = dp(80f)
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(80f))
            setOnClickListener { onTap() }
        }
        card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(28f), dp(28f), dp(28f), dp(28f))
            addView(icon)
            addView(title)
            addView(open)
            setOnClickListener { onTap() }
        }
        root = FrameLayout(context).apply {
            addView(
                card,
                FrameLayout.LayoutParams(dp(300f), FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER),
            )
            setOnClickListener { onTap() }
        }
        setContentView(root)
        applyTheme(DashMateTheme.isDark)
    }

    override fun onStart() {
        super.onStart()
        DashMateTheme.addListener(themeListener)
        applyTheme(DashMateTheme.isDark)
    }

    override fun onStop() {
        DashMateTheme.removeListener(themeListener)
        super.onStop()
    }

    private fun applyTheme(dark: Boolean) {
        if (!::root.isInitialized) return
        root.setBackgroundColor(DashMateTheme.bg(dark)) // #F8FAFC / #0F1115
        card.background = GradientDrawable().apply {
            cornerRadius = dp(24f).toFloat()
            setColor(DashMateTheme.surface(dark)) // #FFFFFF / #181B21
            setStroke(dp(1f), DashMateTheme.border(dark))
        }
        title.setTextColor(DashMateTheme.ink(dark)) // #0F172A / #F1F5F9
        open.background = GradientDrawable().apply {
            cornerRadius = dp(18f).toFloat()
            setColor(DashMateTheme.accent(dark)) // #0F766E / #2DD4BF
        }
        open.setTextColor(if (dark) DashMateTheme.bg(true) else Color.WHITE)
    }

    override fun dismiss() {
        DashMateTheme.removeListener(themeListener)
        super.dismiss()
    }
}
