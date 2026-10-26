package com.dashmate.dashmate

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Locale

class DashMateCarKeyboard(
    context: Context,
    private val onSubmit: (String, Boolean) -> Unit,
    private val onDismiss: () -> Unit,
    /** Every key press, with the whole text so far (not called for the address bar). */
    private val onChange: (String) -> Unit = {},
) : LinearLayout(context) {

    private val density: Float = context.resources.displayMetrics.density
    private var currentText = StringBuilder()
    private var currentHint = "Search or type..."
    private var isAddressBar = false
    private var isShifted = false
    private var isSymbols = false
    private var isPassword = false
    private var dark = DashMateTheme.isDark
    private lateinit var keysContainer: LinearLayout
    private lateinit var previewText: TextView
    private val headerButtons = mutableListOf<TextView>()

    // Day / night palette (DashMate design tokens).
    private fun panelBg() = Color.parseColor(if (dark) "#181B21" else "#F1F5F9")
    private fun keyBg() = Color.parseColor(if (dark) "#20242B" else "#FFFFFF")
    private fun specialBg() = Color.parseColor(if (dark) "#2A2F37" else "#E2E8F0")
    private fun border() = DashMateTheme.border(dark)
    private fun ink() = DashMateTheme.ink(dark)
    private fun muted() = Color.parseColor(if (dark) "#94A3B8" else "#64748B")
    private fun accent() = DashMateTheme.accent(dark)
    private fun onAccent() = Color.parseColor(if (dark) "#0F1115" else "#FFFFFF")

    init {
        orientation = VERTICAL
        // Docked full-width at the bottom of the car screen (not a full-screen overlay).
        layoutParams = android.widget.FrameLayout.LayoutParams(
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
            android.widget.FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM,
        )
        isClickable = true // taps between keys must not fall through to the page
        val pad = (8 * density).toInt()
        setPadding(pad, (10 * density).toInt(), pad, pad)
        buildHeader()
        buildKeys()
        applyTheme(dark)
        visibility = View.GONE
    }

    /** Recolours for day / night; safe to call any time. */
    fun applyTheme(dark: Boolean) {
        this.dark = dark
        background = GradientDrawable().apply {
            setColor(panelBg())
            val r = density * 18f
            cornerRadii = floatArrayOf(r, r, r, r, 0f, 0f, 0f, 0f)
            setStroke((1 * density).toInt(), border())
        }
        previewText.background = GradientDrawable().apply {
            setColor(keyBg())
            cornerRadius = density * 10f
            setStroke((1 * density).toInt(), border())
        }
        for (b in headerButtons) {
            b.setTextColor(ink())
            b.background = GradientDrawable().apply {
                setColor(specialBg())
                cornerRadius = density * 10f
            }
        }
        updatePreview()
        buildKeys()
    }

    private fun dp(v: Float): Int = (density * v + 0.5f).toInt()

    private fun buildHeader() {
        val header = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = dp(8f)
            }
        }

        previewText = TextView(context).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.START
            layoutParams = LayoutParams(0, dp(48f), 1f).apply { marginEnd = dp(6f) }
            gravity = Gravity.START or Gravity.CENTER_VERTICAL
            setPadding(dp(12f), 0, dp(12f), 0)
        }
        header.addView(previewText)

        val clearBtn = TextView(context).apply {
            text = "✕"
            contentDescription = "Clear"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            gravity = Gravity.CENTER
            layoutParams = LayoutParams(dp(56f), dp(48f)).apply { marginEnd = dp(6f) }
            setOnClickListener {
                currentText.clear()
                changed()
            }
        }
        headerButtons.add(clearBtn)
        header.addView(clearBtn)

        val dismissBtn = TextView(context).apply {
            text = "▼"
            contentDescription = "Close keyboard"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            gravity = Gravity.CENTER
            layoutParams = LayoutParams(dp(56f), dp(48f))
            setOnClickListener {
                hide()
                onDismiss()
            }
        }
        headerButtons.add(dismissBtn)
        header.addView(dismissBtn)

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

    private fun newBottomRow(): LinearLayout = LinearLayout(context).apply {
        orientation = HORIZONTAL
        layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(4f)
        }
    }

    private fun changed() {
        updatePreview()
        if (!isAddressBar) onChange(currentText.toString())
    }

    private fun append(s: String) {
        currentText.append(s)
        changed()
    }

    private fun backspace() {
        if (currentText.isNotEmpty()) {
            currentText.deleteCharAt(currentText.length - 1)
            changed()
        }
    }

    private fun submit() {
        val text = currentText.toString()
        hide()
        onSubmit(text, isAddressBar)
    }

    private fun buildLettersRows(container: LinearLayout) {
        val row1 = listOf("q", "w", "e", "r", "t", "y", "u", "i", "o", "p")
        val row2 = listOf("a", "s", "d", "f", "g", "h", "j", "k", "l")
        val row3 = listOf("z", "x", "c", "v", "b", "n", "m")

        container.addView(createRow(row1.map { if (isShifted) it.uppercase(Locale.ROOT) else it }))
        container.addView(createRow(row2.map { if (isShifted) it.uppercase(Locale.ROOT) else it }, dp(16f)))

        val row3Layout = newBottomRow()
        row3Layout.addView(
            createKey(if (isShifted) "⇪" else "⇧", 1.4f, isSpecial = true) {
                isShifted = !isShifted
                buildKeys()
            }
        )
        for (letter in row3) {
            val keyVal = if (isShifted) letter.uppercase(Locale.ROOT) else letter
            row3Layout.addView(createKey(keyVal, 1.0f) { append(keyVal) })
        }
        row3Layout.addView(createKey("⌫", 1.4f, isSpecial = true) { backspace() })
        container.addView(row3Layout)

        val bottomRow = newBottomRow()
        bottomRow.addView(
            createKey("?123", 1.5f, isSpecial = true) {
                isSymbols = true
                buildKeys()
            }
        )
        bottomRow.addView(createKey(".com", 1.3f, isSpecial = true) { append(".com") })
        bottomRow.addView(createKey("Space", 4.2f) { append(" ") })
        bottomRow.addView(createKey("Go ↵", 2.0f, isAction = true) { submit() })
        container.addView(bottomRow)
    }

    private fun buildSymbolsRows(container: LinearLayout) {
        val row1 = listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "0")
        val row2 = listOf("@", "#", "$", "%", "&", "-", "+", "(", ")", "/")
        val row3 = listOf("*", "\"", "'", ":", ";", "!", "?")

        container.addView(createRow(row1))
        container.addView(createRow(row2))

        val row3Layout = newBottomRow()
        row3Layout.addView(
            createKey("ABC", 1.4f, isSpecial = true) {
                isSymbols = false
                buildKeys()
            }
        )
        for (sym in row3) {
            row3Layout.addView(createKey(sym, 1.0f) { append(sym) })
        }
        row3Layout.addView(createKey("⌫", 1.4f, isSpecial = true) { backspace() })
        container.addView(row3Layout)

        val bottomRow = newBottomRow()
        bottomRow.addView(createKey(".com", 1.5f, isSpecial = true) { append(".com") })
        bottomRow.addView(createKey("/", 1.0f, isSpecial = true) { append("/") })
        bottomRow.addView(createKey(".", 1.0f, isSpecial = true) { append(".") })
        bottomRow.addView(createKey("Space", 3.5f) { append(" ") })
        bottomRow.addView(createKey("Go ↵", 2.0f, isAction = true) { submit() })
        container.addView(bottomRow)
    }

    private fun createRow(keys: List<String>, paddingSide: Int = 0): LinearLayout {
        val row = LinearLayout(context).apply {
            orientation = HORIZONTAL
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(4f)
            }
        }
        if (paddingSide > 0) {
            row.setPadding(paddingSide, 0, paddingSide, 0)
        }
        for (k in keys) {
            row.addView(createKey(k, 1.0f) { append(k) })
        }
        return row
    }

    private fun createKey(
        label: String,
        weight: Float,
        isSpecial: Boolean = false,
        isAction: Boolean = false,
        onClick: () -> Unit,
    ): View {
        return TextView(context).apply {
            text = label
            gravity = Gravity.CENTER
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (label.length > 2) 13f else 17f)
            layoutParams = LayoutParams(0, dp(48f), weight).apply {
                setMargins(dp(2f), 0, dp(2f), 0)
            }
            val bgColor = when {
                isAction -> accent()
                isSpecial -> specialBg()
                else -> keyBg()
            }
            val fgColor = when {
                isAction -> onAccent()
                isSpecial -> accent()
                else -> ink()
            }
            setTextColor(fgColor)
            setTypeface(null, if (isAction || isSpecial) Typeface.BOLD else Typeface.NORMAL)
            background = GradientDrawable().apply {
                setColor(bgColor)
                cornerRadius = density * 8f
                if (!isAction) setStroke((1 * density).toInt(), border())
            }
            isClickable = true
            isFocusable = true
            setOnClickListener { onClick() }
        }
    }

    private fun updatePreview() {
        if (!::previewText.isInitialized) return
        if (currentText.isEmpty()) {
            previewText.text = currentHint
            previewText.setTextColor(muted())
        } else {
            previewText.text = if (isPassword) "•".repeat(currentText.length) else currentText.toString()
            previewText.setTextColor(ink())
        }
    }

    /**
     * Opens the keyboard. [inputType] is the web field's type ("text", "password", "number",
     * "tel", "textarea"…): passwords show dots, number / tel fields start on the digits page.
     */
    fun show(initialText: String, hint: String, isAddressBar: Boolean, inputType: String = "text") {
        currentText = StringBuilder(initialText)
        currentHint = if (hint.isNotBlank()) hint else "Search or type..."
        this.isAddressBar = isAddressBar
        isPassword = inputType.equals("password", ignoreCase = true)
        isShifted = false
        isSymbols = inputType.equals("number", ignoreCase = true) || inputType.equals("tel", ignoreCase = true)
        if (dark != DashMateTheme.isDark) applyTheme(DashMateTheme.isDark)
        updatePreview()
        buildKeys()
        visibility = View.VISIBLE
        bringToFront()
    }

    fun hide() {
        visibility = View.GONE
    }

    fun isShowing(): Boolean = visibility == View.VISIBLE
}
