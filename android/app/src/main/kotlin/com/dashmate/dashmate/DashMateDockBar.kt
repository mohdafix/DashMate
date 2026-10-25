package com.dashmate.dashmate

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.content.Context
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.animation.OvershootInterpolator
import android.view.animation.PathInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class DashMateDockBar(
    context: Context,
    private val onPageSelected: (String) -> Unit
) : FrameLayout(context) {

    private val prefs: SharedPreferences = context.getSharedPreferences("dd_car_browser", Context.MODE_PRIVATE)
    private val density = context.resources.displayMetrics.density

    private fun dp(value: Int): Int = (value * density + 0.5f).toInt()

    private val colorPalette = listOf(
        Color.parseColor("#14E0C1"), // 0: Teal
        Color.parseColor("#009688"), // 1: Emerald Green
        Color.parseColor("#E55368"), // 2: Coral / Pink Red
        Color.parseColor("#3B82F6"), // 3: Blue
        Color.parseColor("#D9822B"), // 4: Amber / Gold
        Color.parseColor("#8B5CF6")  // 5: Purple
    )
    private val darkPaletteColor = Color.parseColor("#161B26")

    private val tealColor = Color.parseColor("#14E0C1")
    private val darkNavyColor = Color.parseColor("#0B0F1A")
    private val glassBgColor = Color.argb(0xDC, 0x0E, 0x12, 0x1E)
    private val glassStrokeColor = Color.argb(0x3C, 0xFF, 0xFF, 0xFF)
    private val inactiveItemBg = Color.argb(0x19, 0xFF, 0xFF, 0xFF)

    private val expandInterpolator = OvershootInterpolator(1.3f)
    private val collapseInterpolator = PathInterpolator(0.4f, 0f, 0.2f, 1f)

    private val launcherBtn: ImageView
    private val dockPill: LinearLayout
    private val itemViews = mutableMapOf<String, ImageView>()
    private var currentItemIds: List<String> = emptyList()

    private val allItemDefs = mapOf(
        "home" to Triple(R.drawable.dd_ic_home, "Home", "home"),
        "lyrics" to Triple(R.drawable.dd_ic_lyrics, "Lyrics", "lyrics"),
        "prayer" to Triple(R.drawable.dd_ic_prayer, "Prayer Times", "prayer"),
        "radio" to Triple(R.drawable.dd_ic_radio, "Radio FM", "radio"),
        "custom" to Triple(R.drawable.dd_ic_grid, "Custom Dashboard", "custom"),
        "web" to Triple(R.drawable.dd_ic_web, "Browser", "web"),
        "browse" to Triple(R.drawable.dd_ic_web, "Browser", "web")
    )

    var isExpanded: Boolean = true
        private set

    var currentPage: String = "home"
        private set

    // Touch dragging with onInterceptTouchEvent
    private var downX = 0f
    private var downY = 0f
    private var initialMarginX = 0
    private var initialMarginY = 0
    private var isDragging = false
    private val dragThreshold = dp(10)

    init {
        clipChildren = false
        clipToPadding = false

        // 1. Launcher button (9-circles icon) shown when collapsed
        launcherBtn = ImageView(context).apply {
            setImageResource(R.drawable.dd_ic_grid_circles)
            imageTintList = ColorStateList.valueOf(Color.WHITE)
            scaleType = ImageView.ScaleType.FIT_CENTER
            setPadding(dp(10), dp(10), dp(10), dp(10))

            val bg = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(glassBgColor)
                setStroke(dp(1), glassStrokeColor)
            }
            background = bg
            elevation = dp(4).toFloat()

            setOnClickListener {
                toggleExpand()
            }
            setOnLongClickListener {
                isDragging = true
                true
            }
        }

        // 2. Main horizontal pill container
        dockPill = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(6), dp(4), dp(6), dp(4))

            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(24).toFloat()
                setColor(glassBgColor)
                setStroke(dp(1), glassStrokeColor)
            }
            background = bg
            elevation = dp(4).toFloat()
        }

        val pillParams = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT)
        addView(dockPill, pillParams)

        val launcherParams = LayoutParams(dp(44), dp(44)).apply {
            gravity = Gravity.START or Gravity.TOP
        }
        addView(launcherBtn, launcherParams)

        rebuildMenuButtons()

        // Default: expanded
        setExpandedState(expanded = true, animate = false)
    }

    fun rebuildMenuButtons() {
        val jsonStr = prefs.getString("menu_items", "[\"home\",\"lyrics\",\"prayer\",\"radio\",\"custom\",\"web\"]")
        val activeIds = mutableListOf<String>()
        try {
            val arr = org.json.JSONArray(jsonStr)
            for (i in 0 until arr.length()) {
                activeIds.add(arr.getString(i))
            }
        } catch (_: Exception) {
            activeIds.addAll(listOf("home", "lyrics", "prayer", "radio", "custom", "web"))
        }

        if (activeIds.isEmpty()) {
            activeIds.addAll(listOf("home", "lyrics", "prayer", "radio", "custom", "web"))
        }

        if (activeIds == currentItemIds && dockPill.childCount > 0) {
            updatePageHighlight(currentPage)
            return
        }

        currentItemIds = ArrayList(activeIds)
        dockPill.removeAllViews()
        itemViews.clear()

        // Add 9-dots button at front of pill to quickly collapse/expand
        val appsIcon = createIconButton("apps", R.drawable.dd_ic_grid_circles, "Apps Launcher") {
            toggleExpand()
        }.apply {
            setOnLongClickListener {
                isDragging = true
                true
            }
        }
        dockPill.addView(appsIcon)

        for (id in activeIds) {
            val def = allItemDefs[id] ?: continue
            val btn = createIconButton(id, def.first, def.second) {
                selectPage(id)
            }
            itemViews[id] = btn
            dockPill.addView(btn)
        }

        updatePageHighlight(currentPage)
        applyStylePrefs()
    }

    fun applyStylePrefs() {
        post {
            val scale = prefs.getFloat("nav_scale", 1.0f).coerceIn(0.7f, 1.4f)
            val opacity = prefs.getFloat("nav_opacity", 0.92f).coerceIn(0.2f, 1.0f)
            val colorIdx = prefs.getInt("nav_color_idx", 0)
            val position = prefs.getString("dock_position", "top_left") ?: "top_left"
            val autoCollapse = prefs.getBoolean("dock_auto_collapse", true)

            scaleX = scale
            scaleY = scale
            pivotX = 0f
            pivotY = 0f

            dockPill.alpha = opacity
            launcherBtn.alpha = opacity

            val activeColor = if (colorIdx == -1) darkPaletteColor else colorPalette.getOrElse(colorIdx) { colorPalette[0] }
            updatePageHighlight(currentPage, activeColor)

            // Update gravity & margins according to position from companion app!
            (layoutParams as? FrameLayout.LayoutParams)?.let { lp ->
                val margin = dp(16)
                when (position) {
                    "top_right" -> {
                        lp.gravity = Gravity.TOP or Gravity.END
                        lp.setMargins(0, margin, margin, 0)
                    }
                    "bottom_left" -> {
                        lp.gravity = Gravity.BOTTOM or Gravity.START
                        lp.setMargins(margin, 0, 0, margin)
                    }
                    "bottom_right" -> {
                        lp.gravity = Gravity.BOTTOM or Gravity.END
                        lp.setMargins(0, 0, margin, margin)
                    }
                    else -> { // "top_left"
                        lp.gravity = Gravity.TOP or Gravity.START
                        lp.setMargins(margin, margin, 0, 0)
                    }
                }
                layoutParams = lp
            }

            if (autoCollapse) {
                scheduleAutoCollapse()
            } else {
                cancelAutoCollapse()
            }
        }
    }

    private var autoCollapseJob: Runnable? = null
    private val collapseHandler = android.os.Handler(android.os.Looper.getMainLooper())

    fun scheduleAutoCollapse() {
        cancelAutoCollapse()
        val autoCollapseEnabled = prefs.getBoolean("dock_auto_collapse", true)
        if (!autoCollapseEnabled || !isExpanded) return

        val r = Runnable {
            if (isExpanded) {
                setExpandedState(expanded = false, animate = true)
            }
        }
        autoCollapseJob = r
        collapseHandler.postDelayed(r, 6000L) // 6 seconds
    }

    fun cancelAutoCollapse() {
        autoCollapseJob?.let { collapseHandler.removeCallbacks(it) }
        autoCollapseJob = null
    }

    private fun createIconButton(
        id: String,
        drawableRes: Int,
        desc: String,
        onClick: () -> Unit
    ): ImageView {
        val size = dp(38)
        val btn = ImageView(context).apply {
            tag = id
            setImageResource(drawableRes)
            scaleType = ImageView.ScaleType.FIT_CENTER
            setPadding(dp(7), dp(7), dp(7), dp(7))
            contentDescription = desc

            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                marginStart = dp(3)
                marginEnd = dp(3)
            }

            setOnClickListener {
                onClick()
            }
        }
        return btn
    }

    fun selectPage(page: String) {
        scheduleAutoCollapse()
        if (currentPage == page && page != "custom") return
        currentPage = page
        updatePageHighlight(page)
        onPageSelected(page)
    }

    fun updateCurrentPage(page: String) {
        if (currentPage != page) {
            currentPage = page
            updatePageHighlight(page)
        }
    }

    private fun updatePageHighlight(activePage: String, activeColorOverride: Int? = null) {
        val colorIdx = prefs.getInt("nav_color_idx", 0)
        val tintColor = activeColorOverride ?: if (colorIdx == -1) darkPaletteColor else colorPalette.getOrElse(colorIdx) { colorPalette[0] }

        for ((id, btn) in itemViews) {
            val isActive = (id == activePage)
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                if (isActive) {
                    setColor(tintColor)
                } else {
                    setColor(inactiveItemBg)
                }
            }
            btn.background = bg

            if (isActive) {
                btn.imageTintList = ColorStateList.valueOf(if (colorIdx == -1) Color.WHITE else darkNavyColor)
            } else {
                btn.imageTintList = ColorStateList.valueOf(Color.WHITE)
            }
        }
    }

    fun toggleExpand() {
        val next = !isExpanded
        setExpandedState(next, animate = true)
        if (next) {
            scheduleAutoCollapse()
        } else {
            cancelAutoCollapse()
        }
    }

    private fun setExpandedState(expanded: Boolean, animate: Boolean) {
        isExpanded = expanded

        if (!animate) {
            if (expanded) {
                dockPill.visibility = View.VISIBLE
                dockPill.alpha = 1f
                dockPill.scaleX = 1f
                dockPill.scaleY = 1f
                launcherBtn.visibility = View.GONE
            } else {
                dockPill.visibility = View.GONE
                launcherBtn.visibility = View.VISIBLE
                launcherBtn.alpha = 1f
            }
            return
        }

        if (expanded) {
            dockPill.visibility = View.VISIBLE
            dockPill.alpha = 0f
            dockPill.scaleX = 0.7f
            dockPill.scaleY = 0.7f
            dockPill.pivotX = 0f
            dockPill.pivotY = dockPill.height / 2f

            launcherBtn.animate()
                .alpha(0f)
                .setDuration(120)
                .setListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        launcherBtn.visibility = View.GONE
                    }
                })
                .start()

            dockPill.animate()
                .alpha(1f)
                .scaleX(1f)
                .scaleY(1f)
                .setInterpolator(expandInterpolator)
                .setDuration(220)
                .setListener(null)
                .start()
        } else {
            launcherBtn.visibility = View.VISIBLE
            launcherBtn.alpha = 0f
            launcherBtn.animate()
                .alpha(1f)
                .setDuration(150)
                .setListener(null)
                .start()

            dockPill.animate()
                .alpha(0f)
                .scaleX(0.7f)
                .scaleY(0.7f)
                .setInterpolator(collapseInterpolator)
                .setDuration(150)
                .setListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        dockPill.visibility = View.GONE
                    }
                })
                .start()
        }
    }

    override fun onInterceptTouchEvent(ev: MotionEvent): Boolean {
        when (ev.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downX = ev.rawX
                downY = ev.rawY
                initialMarginX = (layoutParams as? LayoutParams)?.leftMargin ?: 0
                initialMarginY = (layoutParams as? LayoutParams)?.topMargin ?: 0
                isDragging = false
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = ev.rawX - downX
                val dy = ev.rawY - downY
                if (abs(dx) > dragThreshold || abs(dy) > dragThreshold) {
                    isDragging = true
                    return true
                }
            }
        }
        return false
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val parentView = parent as? ViewGroup ?: return super.onTouchEvent(event)
        val lp = layoutParams as? LayoutParams ?: return super.onTouchEvent(event)

        when (event.actionMasked) {
            MotionEvent.ACTION_MOVE -> {
                if (isDragging) {
                    val dx = event.rawX - downX
                    val dy = event.rawY - downY
                    val maxMarginX = max(0, parentView.width - width)
                    val maxMarginY = max(0, parentView.height - height)

                    lp.leftMargin = min(maxMarginX, max(0, (initialMarginX + dx).toInt()))
                    lp.topMargin = min(maxMarginY, max(0, (initialMarginY + dy).toInt()))
                    layoutParams = lp
                    return true
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (isDragging) {
                    savePosition(lp.leftMargin, lp.topMargin)
                    isDragging = false
                    return true
                }
            }
        }
        return super.onTouchEvent(event)
    }

    private fun savePosition(x: Int, y: Int) {
        prefs.edit()
            .putInt("dock_x", x)
            .putInt("dock_y", y)
            .apply()
    }

    fun restorePosition(parentWidth: Int, parentHeight: Int) {
        val defaultX = dp(16)
        val defaultY = dp(12)

        val savedX = prefs.getInt("dock_x", defaultX)
        val savedY = prefs.getInt("dock_y", defaultY)

        val maxMarginX = max(0, parentWidth - dp(240))
        val maxMarginY = max(0, parentHeight - dp(56))

        val clampedX = min(maxMarginX, max(0, savedX))
        val clampedY = min(maxMarginY, max(0, savedY))

        (layoutParams as? LayoutParams)?.let { lp ->
            lp.leftMargin = clampedX
            lp.topMargin = clampedY
            layoutParams = lp
        }
    }
}
