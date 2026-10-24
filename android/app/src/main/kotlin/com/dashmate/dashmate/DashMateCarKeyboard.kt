package com.dashmate.dashmate

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.content.res.ColorStateList
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

class DashMateCarKeyboard(
    context: Context,
    private val onSubmit: (text: String, isAddressBar: Boolean) -> Unit,
    private val onDismiss: () -> Unit
) : LinearLayout(context) {

    private val density = context.resources.displayMetrics.density
    private var isShifted = false
    private var isSymbols = false
    private var isAddressBar = false
    private var currentText = StringBuilder()
    private var currentHint = "Search or type..."

    private lateinit var previewText: TextView
    private lateinit var keysContainer: LinearLayout

    init {
        orientation = VERTICAL
        val bg = GradientDrawable().apply {
            setColor(Color.parseColor("#F5101524"))
            val r = 18f * density
            cornerRadii = floatArrayOf(r, r, r, r, 0f, 0f, 0f, 0f)
            setStroke((1 * density).toInt(), Color.parseColor("#33FFFFFF"))
        }
        background = bg
        val pad = (8 * density).toInt()
        setPadding(pad, (10 * density).toInt(), pad, pad)

        buildHeader()
        buildKeys()

        visibility = GONE
    }

    private fun dp(v: Float): Int = (v * density + 0.5f).toInt()

    private fun buildHeader() {
        val header = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val lp = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = dp(8f)
            }
            layoutParams = lp
        }

        previewText = TextView(context).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.START
            val pLp = LayoutParams(0, dp(40f), 1f).apply {
                marginEnd = dp(6f)
            }
            layoutParams = pLp
            gravity = Gravity.CENTER_VERTICAL or Gravity.START
            setPadding(dp(12f), 0, dp(12f), 0)
            val pBg = GradientDrawable().apply {
                setColor(Color.parseColor("#1F2840"))
                cornerRadius = 10f * density
                setStroke((1 * density).toInt(), Color.parseColor("#25FFFFFF"))
            }
            background = pBg
        }
        header.addView(previewText)

        // Clear button
        val clearBtn = TextView(context).apply {
            text = "✕"
            setTextColor(Color.parseColor("#8B95AD"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            gravity = Gravity.CENTER
            layoutParams = LayoutParams(dp(40f), dp(40f)).apply {
                marginEnd = dp(6f)
            }
            val cBg = GradientDrawable().apply {
                setColor(Color.parseColor("#1F2840"))
                cornerRadius = 10f * density
            }
            background = cBg
            setOnClickListener {
                currentText.clear()
                updatePreview()
            }
        }
        header.addView(clearBtn)

        // Close / Hide button
        val closeBtn = TextView(context).apply {
            text = "▼"
            setTextColor(Color.parseColor("#8B95AD"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            gravity = Gravity.CENTER
            layoutParams = LayoutParams(dp(40f), dp(40f))
            val clBg = GradientDrawable().apply {
                setColor(Color.parseColor("#1F2840"))
                cornerRadius = 10f * density
            }
            background = clBg
            setOnClickListener {
                hide()
                onDismiss()
            }
        }
        header.addView(closeBtn)

        addView(header)
    }

    private fun buildKeys() {
        if (::keysContainer.isInitialized) {
            removeView(keysContainer)
        }
        keysContainer = LinearLayout(context).apply {
            orientation = VERTICAL
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT)
        }

        if (isSymbols) {
            buildSymbolsRows(keysContainer)
        } else {
            buildLettersRows(keysContainer)
        }

        addView(keysContainer)
    }

    private fun buildLettersRows(container: LinearLayout) {
        val row1 = listOf("q", "w", "e", "r", "t", "y", "u", "i", "o", "p")
        val row2 = listOf("a", "s", "d", "f", "g", "h", "j", "k", "l")
        val row3 = listOf("z", "x", "c", "v", "b", "n", "m")

        container.addView(createRow(row1.map { if (isShifted) it.uppercase() else it }))
        container.addView(createRow(row2.map { if (isShifted) it.uppercase() else it }, paddingSide = dp(16f)))

        // Row 3 with Shift & Backspace
        val r3 = LinearLayout(context).apply {
            orientation = HORIZONTAL
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(4f)
            }
        }
        // Shift key
        val shiftKey = createKey(if (isShifted) "⇪" else "⇧", weight = 1.4f, isSpecial = true) {
            isShifted = !isShifted
            buildKeys()
        }
        r3.addView(shiftKey)

        for (letter in row3) {
            val keyVal = if (isShifted) letter.uppercase() else letter
            r3.addView(createKey(keyVal, weight = 1.0f) {
                currentText.append(keyVal)
                updatePreview()
            })
        }

        // Backspace key
        val backspaceKey = createKey("⌫", weight = 1.4f, isSpecial = true) {
            if (currentText.isNotEmpty()) {
                currentText.deleteCharAt(currentText.length - 1)
                updatePreview()
            }
        }
        r3.addView(backspaceKey)
        container.addView(r3)

        // Row 4: ?123, .com, Space, Go
        val r4 = LinearLayout(context).apply {
            orientation = HORIZONTAL
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(4f)
            }
        }
        val symKey = createKey("?123", weight = 1.5f, isSpecial = true) {
            isSymbols = true
            buildKeys()
        }
        r4.addView(symKey)

        val comKey = createKey(".com", weight = 1.3f, isSpecial = true) {
            currentText.append(".com")
            updatePreview()
        }
        r4.addView(comKey)

        val spaceKey = createKey("Space", weight = 4.2f) {
            currentText.append(" ")
            updatePreview()
        }
        r4.addView(spaceKey)

        val submitKey = createKey("Go ↵", weight = 2.0f, isAction = true) {
            val text = currentText.toString()
            hide()
            onSubmit(text, isAddressBar)
        }
        r4.addView(submitKey)
        container.addView(r4)
    }

    private fun buildSymbolsRows(container: LinearLayout) {
        val row1 = listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "0")
        val row2 = listOf("@", "#", "$", "%", "&", "-", "+", "(", ")", "/")
        val row3 = listOf("*", "\"", "'", ":", ";", "!", "?")

        container.addView(createRow(row1))
        container.addView(createRow(row2))

        val r3 = LinearLayout(context).apply {
            orientation = HORIZONTAL
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(4f)
            }
        }
        val abcKey = createKey("ABC", weight = 1.4f, isSpecial = true) {
            isSymbols = false
            buildKeys()
        }
        r3.addView(abcKey)

        for (sym in row3) {
            r3.addView(createKey(sym, weight = 1.0f) {
                currentText.append(sym)
                updatePreview()
            })
        }

        val backspaceKey = createKey("⌫", weight = 1.4f, isSpecial = true) {
            if (currentText.isNotEmpty()) {
                currentText.deleteCharAt(currentText.length - 1)
                updatePreview()
            }
        }
        r3.addView(backspaceKey)
        container.addView(r3)

        // Row 4: .com, /, ., Space, Go
        val r4 = LinearLayout(context).apply {
            orientation = HORIZONTAL
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(4f)
            }
        }
        val comKey = createKey(".com", weight = 1.5f, isSpecial = true) {
            currentText.append(".com")
            updatePreview()
        }
        r4.addView(comKey)

        val slashKey = createKey("/", weight = 1.0f, isSpecial = true) {
            currentText.append("/")
            updatePreview()
        }
        r4.addView(slashKey)

        val dotKey = createKey(".", weight = 1.0f, isSpecial = true) {
            currentText.append(".")
            updatePreview()
        }
        r4.addView(dotKey)

        val spaceKey = createKey("Space", weight = 3.5f) {
            currentText.append(" ")
            updatePreview()
        }
        r4.addView(spaceKey)

        val submitKey = createKey("Go ↵", weight = 2.0f, isAction = true) {
            val text = currentText.toString()
            hide()
            onSubmit(text, isAddressBar)
        }
        r4.addView(submitKey)
        container.addView(r4)
    }

    private fun createRow(keys: List<String>, paddingSide: Int = 0): LinearLayout {
        val row = LinearLayout(context).apply {
            orientation = HORIZONTAL
            val lp = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(4f)
            }
            layoutParams = lp
            if (paddingSide > 0) {
                setPadding(paddingSide, 0, paddingSide, 0)
            }
        }
        for (k in keys) {
            row.addView(createKey(k, weight = 1f) {
                currentText.append(k)
                updatePreview()
            })
        }
        return row
    }

    private fun createKey(
        label: String,
        weight: Float,
        isSpecial: Boolean = false,
        isAction: Boolean = false,
        onClick: () -> Unit
    ): View {
        val tv = TextView(context).apply {
            text = label
            gravity = Gravity.CENTER
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (label.length > 2) 13f else 17f)
            val lp = LayoutParams(0, dp(42f), weight).apply {
                setMargins(dp(2f), 0, dp(2f), 0)
            }
            layoutParams = lp

            val normalColor = when {
                isAction -> Color.parseColor("#14E0C1")
                isSpecial -> Color.parseColor("#26324D")
                else -> Color.parseColor("#1F2840")
            }
            val textColor = when {
                isAction -> Color.parseColor("#0B0F1A")
                isSpecial -> Color.parseColor("#5EF2D6")
                else -> Color.WHITE
            }
            setTextColor(textColor)
            setTypeface(null, if (isAction || isSpecial) android.graphics.Typeface.BOLD else android.graphics.Typeface.NORMAL)

            val shape = GradientDrawable().apply {
                setColor(normalColor)
                cornerRadius = 8f * density
                setStroke((1 * density).toInt(), Color.parseColor("#1AFFFFFF"))
            }
            background = shape

            isClickable = true
            isFocusable = true
            setOnClickListener {
                onClick()
            }
        }
        return tv
    }

    private fun updatePreview() {
        if (currentText.isEmpty()) {
            previewText.text = currentHint
            previewText.setTextColor(Color.parseColor("#607090"))
        } else {
            previewText.text = currentText.toString()
            previewText.setTextColor(Color.WHITE)
        }
    }

    fun show(initialText: String, hint: String, isAddressBar: Boolean) {
        this.currentText = StringBuilder(initialText)
        this.currentHint = if (hint.isNotBlank()) hint else "Search or type..."
        this.isAddressBar = isAddressBar
        this.isShifted = false
        this.isSymbols = false
        updatePreview()
        buildKeys()
        visibility = VISIBLE
        bringToFront()
    }

    fun hide() {
        visibility = GONE
    }

    fun isShowing(): Boolean = visibility == VISIBLE
}
