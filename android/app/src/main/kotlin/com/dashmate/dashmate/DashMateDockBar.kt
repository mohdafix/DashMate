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

        // Add 9-dots button at front of pill to quickly collapse/expand
        val appsIcon = createIconButton("apps", R.drawable.dd_ic_grid_circles, "Apps Launcher") {
            toggleExpand()
        }
        dockPill.addView(appsIcon)

        // Add the destination buttons
        val items = listOf(
            Triple("home", R.drawable.dd_ic_home, "Home"),
            Triple("lyrics", R.drawable.dd_ic_lyrics, "Lyrics"),
            Triple("prayer", R.drawable.dd_ic_prayer, "Prayer Times"),
            Triple("custom", R.drawable.dd_ic_grid, "Custom Dashboard"),
            Triple("web", R.drawable.dd_ic_web, "Browser")
        )

        for ((id, drawableRes, desc) in items) {
            val btn = createIconButton(id, drawableRes, desc) {
                selectPage(id)
            }
            itemViews[id] = btn
            dockPill.addView(btn)
        }

        val pillParams = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT)
        addView(dockPill, pillParams)

        val launcherParams = LayoutParams(dp(44), dp(44)).apply {
            gravity = Gravity.START or Gravity.TOP
        }
        addView(launcherBtn, launcherParams)

        // Default: expanded
        updatePageHighlight(currentPage)
        setExpandedState(expanded = true, animate = false)
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

    private fun updatePageHighlight(activePage: String) {
        for ((id, btn) in itemViews) {
            val isActive = (id == activePage)
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                if (isActive) {
                    setColor(tealColor)
                } else {
                    setColor(inactiveItemBg)
                }
            }
            btn.background = bg

            if (isActive) {
                btn.imageTintList = ColorStateList.valueOf(darkNavyColor)
            } else {
                btn.imageTintList = ColorStateList.valueOf(Color.WHITE)
            }
        }
    }

    fun toggleExpand() {
        setExpandedState(!isExpanded, animate = true)
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
