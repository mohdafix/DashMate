package com.dashmate.dashmate

import android.annotation.SuppressLint
import android.app.Presentation
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import android.view.Display
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

class DashMatePresentation(
    private val hostContext: Context,
    display: Display
) : Presentation(hostContext, display), DashMateStateBridge.StateListener {

    private val TAG = "DashMatePresentation"
    private var webView: WebView? = null
    private lateinit var rootLayout: FrameLayout
    private lateinit var browserBar: LinearLayout
    private var dockBar: DashMateDockBar? = null
    private var fullscreenBtn: ImageView? = null
    private var isFullscreen: Boolean = false
    private var lastVisibleArea: android.graphics.Rect? = null
    private var currentPage: String = "home"
    private var isBrowsingWeb: Boolean = false
    private var carKeyboard: DashMateCarKeyboard? = null
    var onOpenKeyboard: ((initialText: String, hint: String, onSubmitted: (String) -> Unit) -> Unit)? = null

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Play welcome audio chime on vehicle connection
        DashMateStateBridge.playWelcomeChime(context)

        rootLayout = FrameLayout(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#070B14"))
        }

        // Enable cookies for YouTube & Google authentication
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)

        webView = WebView(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.TRANSPARENT)
            setLayerType(View.LAYER_TYPE_HARDWARE, null)

            cookieManager.setAcceptThirdPartyCookies(this, true)

            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                databaseEnabled = true
                allowFileAccess = true
                allowContentAccess = true
                allowFileAccessFromFileURLs = true
                allowUniversalAccessFromFileURLs = true
                mediaPlaybackRequiresUserGesture = false
                cacheMode = WebSettings.LOAD_DEFAULT
                useWideViewPort = true
                loadWithOverviewMode = true
                userAgentString = "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36 DashMate/2.0"
            }

            webChromeClient = object : WebChromeClient() {}

            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                    return false
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    Log.d(TAG, "Car Deck page finished loading: $url")
                    if (!isBrowsingWeb) {
                        onStateUpdated(DashMateStateBridge.buildStateJson(hostContext))
                    } else {
                        val script = """
                            (function () {
                              if (window.__ddAudible) return;
                              window.__ddAudible = true;
                              var isField = function (el) {
                                if (!el || !el.tagName) return false;
                                var t = el.tagName;
                                if (t !== 'INPUT' && t !== 'TEXTAREA' && !el.isContentEditable) return false;
                                if (t === 'INPUT' && !/^(text|search|email|url|tel|number|password|)$/i.test(el.getAttribute('type') || '')) return false;
                                return !el.disabled && !el.readOnly;
                              };
                              var field = function (el) {
                                if (!isField(el) || !window.AutoDeckWeb) return;
                                window.__ddField = el;
                                var v = el.isContentEditable ? el.innerText : el.value;
                                try {
                                  AutoDeckWeb.textField(v || '', el.getAttribute('placeholder') || el.getAttribute('aria-label') || '');
                                } catch (err) {}
                              };
                              document.addEventListener('click', function (e) {
                                var el = e.target && e.target.closest ? e.target.closest('input,textarea,[contenteditable=""],[contenteditable="true"]') : null;
                                if (el) field(el);
                              }, true);
                            })();
                        """.trimIndent()
                        view?.evaluateJavascript(script, null)
                    }
                }
            }

            val bridge = AutoDeckJsInterface()
            addJavascriptInterface(bridge, "AutoDeck")
            addJavascriptInterface(bridge, "DashMateBridge")
            addJavascriptInterface(bridge, "AutoDeckWeb")

            loadUrl("file:///android_asset/drivedeck_home.html")
        }

        rootLayout.addView(webView)

        // Floating in-car browser navigation bar (discreet glassmorphic pill)
        browserBar = createBrowserControls()
        browserBar.visibility = View.GONE
        rootLayout.addView(browserBar)

        val density = context.resources.displayMetrics.density

        // Floating in-car navigation dock bar (6-icon pill directly on head unit)
        dockBar = DashMateDockBar(context) { targetPage ->
            DashMateStateBridge.setPage(targetPage)
        }.apply {
            val lp = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.START or Gravity.TOP
                leftMargin = (16 * density + 0.5f).toInt()
                topMargin = (12 * density + 0.5f).toInt()
            }
            layoutParams = lp
        }
        rootLayout.addView(dockBar)

        // In-car virtual keyboard (replaces external screen push, keeps VirtualDisplay fully intact)
        carKeyboard = DashMateCarKeyboard(
            context,
            onSubmit = { text, isAddressBar ->
                injectBrowserText(text, isAddressBar)
            },
            onDismiss = {
                // Keyboard closed
            }
        ).apply {
            val lp = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.BOTTOM
            }
            layoutParams = lp
        }
        rootLayout.addView(carKeyboard)

        rootLayout.post {
            dockBar?.restorePosition(rootLayout.width, rootLayout.height)
        }

        setContentView(rootLayout)

        DashMateStateBridge.addListener(this)
        DashMateStateBridge.refreshAllServices(hostContext)
    }

    private fun createBrowserControls(): LinearLayout {
        val bar = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#CC121826"))
                cornerRadius = 32f
                setStroke(2, Color.parseColor("#33FFFFFF"))
            }
            background = bg
            setPadding(24, 12, 24, 12)
            val params = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                topMargin = 20
            }
            layoutParams = params
        }

        // Home button
        val homeBtn = TextView(context).apply {
            text = "⌂ DashMate"
            setTextColor(Color.parseColor("#5EF2D6"))
            textSize = 14f
            setPadding(16, 8, 16, 8)
            setOnClickListener {
                exitBrowserToHome()
            }
        }
        bar.addView(homeBtn)

        // Back button
        val backBtn = TextView(context).apply {
            text = "◀ Back"
            setTextColor(Color.WHITE)
            textSize = 14f
            setPadding(16, 8, 16, 8)
            setOnClickListener {
                if (webView?.canGoBack() == true) {
                    webView?.goBack()
                } else {
                    exitBrowserToHome()
                }
            }
        }
        bar.addView(backBtn)

        // Reload button
        val reloadBtn = TextView(context).apply {
            text = "↻ Reload"
            setTextColor(Color.WHITE)
            textSize = 14f
            setPadding(16, 8, 16, 8)
            setOnClickListener {
                webView?.reload()
            }
        }
        bar.addView(reloadBtn)

        // Search / Keyboard button
        val searchBtn = TextView(context).apply {
            text = "🔍 Search"
            setTextColor(Color.WHITE)
            textSize = 14f
            setPadding(16, 8, 16, 8)
            setOnClickListener {
                val currentUrl = webView?.url ?: ""
                showVirtualKeyboard(if (currentUrl.startsWith("http")) currentUrl else "", "Search YouTube, Google or enter URL...", isAddressBar = true)
            }
        }
        bar.addView(searchBtn)

        return bar
    }

    fun showVirtualKeyboard(initialText: String, hint: String, isAddressBar: Boolean) {
        rootLayout.post {
            carKeyboard?.show(initialText, hint, isAddressBar)
        }
    }

    fun injectBrowserText(text: String, isAddressBar: Boolean = false) {
        if (isAddressBar) {
            val q = text.trim()
            if (q.isEmpty()) return
            val cur = webView?.url ?: ""
            if (Regex("^(https?://|[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+)", RegexOption.IGNORE_CASE).containsMatchIn(q)) {
                val target = if (q.startsWith("http://", true) || q.startsWith("https://", true)) q else "https://$q"
                loadWebUrl(target)
            } else if (cur.contains("youtube.com", true)) {
                loadWebUrl("https://m.youtube.com/results?search_query=" + android.net.Uri.encode(q))
            } else {
                loadWebUrl("https://www.google.com/search?q=" + android.net.Uri.encode(q))
            }
            return
        }

        val escaped = org.json.JSONObject.quote(text)
        val script = """
            (function (t) {
                var e = window.__ddField || document.activeElement;
                if (!e || !e.isConnected) return;
                if (e.isContentEditable) {
                    e.textContent = t;
                    e.dispatchEvent(new InputEvent('input', { bubbles: true }));
                } else {
                    var d = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(e), 'value');
                    if (d && d.set) d.set.call(e, t); else e.value = t;
                    e.dispatchEvent(new Event('input', { bubbles: true }));
                    e.dispatchEvent(new Event('change', { bubbles: true }));
                }
                if (/(^|\.)youtube\.com$/.test(location.hostname) && (e.name === 'search_query' || /search/i.test(e.id + ' ' + e.className))) {
                    location.href = '/results?search_query=' + encodeURIComponent(t);
                    return;
                }
                if (e.tagName === 'TEXTAREA') return;
                var o = { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true };
                var go = e.dispatchEvent(new KeyboardEvent('keydown', o));
                e.dispatchEvent(new KeyboardEvent('keypress', o));
                e.dispatchEvent(new KeyboardEvent('keyup', o));
                if (go && e.form) { if (e.form.requestSubmit) e.form.requestSubmit(); else e.form.submit(); }
            })($escaped);
        """.trimIndent()
        webView?.post {
            webView?.evaluateJavascript(script, null)
        }
    }

    private fun exitBrowserToHome() {
        isBrowsingWeb = false
        browserBar.visibility = View.GONE
        carKeyboard?.hide()
        onSwitchPage("home")
    }

    fun loadWebUrl(url: String) {
        isBrowsingWeb = true
        rootLayout.post {
            browserBar.visibility = View.VISIBLE
            webView?.loadUrl(url)
        }
    }

    override fun onDetachedFromWindow() {
        DashMateStateBridge.removeListener(this)
        webView?.destroy()
        webView = null
        super.onDetachedFromWindow()
    }

    fun updateViewportPadding(visibleArea: android.graphics.Rect?) {
        val dm = context.resources.displayMetrics
        val isSplit = visibleArea != null && (visibleArea.width() < dm.widthPixels * 0.8f)
        if (visibleArea != null && (!isFullscreen || isSplit)) {
            val l = Math.max(0, visibleArea.left)
            val t = Math.max(0, visibleArea.top)
            val r = Math.max(0, dm.widthPixels - visibleArea.right)
            val b = Math.max(0, dm.heightPixels - visibleArea.bottom)
            rootLayout.setPadding(l, t, r, b)
        } else {
            rootLayout.setPadding(0, 0, 0, 0)
        }
    }

    fun toggleFullscreen(fullscreen: Boolean) {
        isFullscreen = fullscreen
        updateViewportPadding(lastVisibleArea)
        rootLayout.post {
            dockBar?.restorePosition(rootLayout.width, rootLayout.height)
            webView?.evaluateJavascript(
                "if (window.applyLayout && window.pickLayout) { applyLayout(pickLayout()); }",
                null
            )
        }
    }

    fun onSizeChanged(width: Int, height: Int) {
        rootLayout.post {
            updateViewportPadding(lastVisibleArea)
            dockBar?.restorePosition(width, height)
            webView?.evaluateJavascript(
                "if (window.applyLayout && window.pickLayout) { applyLayout(pickLayout()); }",
                null
            )
        }
    }

    fun onVisibleAreaChanged(rect: android.graphics.Rect) {
        lastVisibleArea = rect
        updateViewportPadding(rect)
        rootLayout.post {
            dockBar?.restorePosition(rootLayout.width, rootLayout.height)
            webView?.evaluateJavascript(
                "if (window.applyLayout && window.pickLayout) { applyLayout(pickLayout()); }",
                null
            )
        }
    }

    override fun onSwitchPage(page: String) {
        currentPage = page
        dockBar?.updateCurrentPage(page)

        val targetUrl = when (page) {
            "lyrics" -> "file:///android_asset/drivedeck_lyrics.html"
            "prayer" -> "file:///android_asset/drivedeck_prayer.html"
            "custom" -> "file:///android_asset/drivedeck_home.html"
            "web", "browse" -> {
                loadWebUrl("https://m.youtube.com")
                return
            }
            else -> "file:///android_asset/drivedeck_home.html"
        }

        isBrowsingWeb = false
        browserBar.visibility = View.GONE

        webView?.post {
            val currentUrl = webView?.url ?: ""
            val targetAsset = targetUrl.substringAfter("android_asset/")
            if (!currentUrl.contains(targetAsset)) {
                Log.d(TAG, "Navigating to: $targetUrl")
                webView?.loadUrl(targetUrl)
            } else {
                Log.d(TAG, "Already on $targetAsset, updating state cleanly")
                onStateUpdated(DashMateStateBridge.buildStateJson(hostContext))
            }
        }
    }

    override fun onStateUpdated(stateJson: String) {
        if (isBrowsingWeb) return
        val script = when (currentPage) {
            "lyrics" -> "if (window.ddUpdate) { var d = $stateJson; window.ddUpdate(d.music || d); } else if (window.ddLyrics) { window.ddLyrics($stateJson); }"
            "prayer" -> "if (window.ddUpdate) { var d = $stateJson; window.ddUpdate(d.prayer || d); } else if (window.ddPrayer) { window.ddPrayer($stateJson); }"
            else -> "if (window.ddUpdate) { window.ddUpdate($stateJson); }"
        }
        webView?.post {
            webView?.evaluateJavascript(script, null)
        }
    }

    override fun onExecuteScript(script: String) {
        webView?.post {
            webView?.evaluateJavascript(script, null)
        }
    }

    fun dispatchVirtualClick(x: Float, y: Float) {
        val now = SystemClock.uptimeMillis()
        val down = MotionEvent.obtain(now, now, MotionEvent.ACTION_DOWN, x, y, 0)
        val up = MotionEvent.obtain(now, now + 50, MotionEvent.ACTION_UP, x, y, 0)

        if (::rootLayout.isInitialized) {
            rootLayout.post {
                if (carKeyboard?.isShowing() == true && y < (carKeyboard?.top ?: 0)) {
                    carKeyboard?.hide()
                } else {
                    rootLayout.dispatchTouchEvent(down)
                    rootLayout.dispatchTouchEvent(up)
                }
                down.recycle()
                up.recycle()
            }
        }
    }

    fun dispatchVirtualScroll(startX: Float, startY: Float, distanceX: Float, distanceY: Float) {
        val now = SystemClock.uptimeMillis()
        val down = MotionEvent.obtain(now, now, MotionEvent.ACTION_DOWN, startX, startY, 0)
        val move = MotionEvent.obtain(now, now + 20, MotionEvent.ACTION_MOVE, startX - distanceX, startY - distanceY, 0)
        val up = MotionEvent.obtain(now, now + 40, MotionEvent.ACTION_UP, startX - distanceX, startY - distanceY, 0)

        if (::rootLayout.isInitialized) {
            rootLayout.post {
                rootLayout.dispatchTouchEvent(down)
                rootLayout.dispatchTouchEvent(move)
                rootLayout.dispatchTouchEvent(up)
                down.recycle()
                move.recycle()
                up.recycle()
            }
        }
    }

    private fun JSONObjectEscape(str: String): String {
        return str.replace("\\", "\\\\")
            .replace("'", "\\'")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
    }

    inner class AutoDeckJsInterface {
        @JavascriptInterface
        fun media(action: String) {
            Log.d(TAG, "Media control clicked: $action")
            val am = hostContext.getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
            when (action) {
                "lyrics" -> onSwitchPage("lyrics")
                "toggle" -> {
                    am?.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, android.view.KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
                    am?.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_UP, android.view.KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
                }
                "next" -> {
                    am?.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, android.view.KeyEvent.KEYCODE_MEDIA_NEXT))
                    am?.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_UP, android.view.KeyEvent.KEYCODE_MEDIA_NEXT))
                }
                "prev" -> {
                    am?.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, android.view.KeyEvent.KEYCODE_MEDIA_PREVIOUS))
                    am?.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_UP, android.view.KeyEvent.KEYCODE_MEDIA_PREVIOUS))
                }
            }
        }

        @JavascriptInterface
        fun navigate(lat: Double, lng: Double) {
            DashMateStateBridge.launchNavigationCoords(hostContext, lat, lng)
        }

        @JavascriptInterface
        fun youtube(videoId: String) {
            Log.d(TAG, "YouTube requested: $videoId")
            DashMateStateBridge.currentYoutubeId = videoId
            loadWebUrl("https://m.youtube.com/watch?v=$videoId")
        }

        @JavascriptInterface
        fun site(url: String) {
            Log.d(TAG, "Open site requested: $url")
            if (url.startsWith("dashmate://parking")) {
                val spot = com.dashmate.dashmate.deck.ParkingManager.getSpot(hostContext)
                if (spot != null) {
                    com.dashmate.dashmate.deck.ParkingManager.navigateBack(hostContext)
                }
                return
            }
            if (url.startsWith("http://") || url.startsWith("https://")) {
                loadWebUrl(url)
            } else {
                try {
                    val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url))
                    intent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                    hostContext.startActivity(intent)
                } catch (_: Exception) {}
            }
        }

        @JavascriptInterface
        fun page(target: String) {
            onSwitchPage(target)
        }

        @JavascriptInterface
        fun textField(initialValue: String, hint: String) {
            val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
            mainHandler.post {
                showVirtualKeyboard(initialValue, hint, isAddressBar = false)
            }
        }

        @JavascriptInterface
        fun audibleVideo() {
            // Audio playback event from browser
        }
    }
}
