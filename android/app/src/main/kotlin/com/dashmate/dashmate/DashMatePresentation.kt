package com.dashmate.dashmate

import android.annotation.SuppressLint
import android.app.Presentation
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Rect
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
import java.util.Locale

class DashMatePresentation(
    private val hostContext: Context,
    display: Display
) : Presentation(hostContext, display), DashMateStateBridge.StateListener {

    private val TAG = "DashMatePresentation"
    
    // AutoDeck Dual-WebView Architecture:
    // deckWebView: dedicated permanently for in-car dashboard HTML (never reloaded/destroyed on web browsing)
    // browserWebView: dedicated for web navigation, YouTube, RTM Klik
    private var deckWebView: WebView? = null
    private var browserWebView: WebView? = null
    
    private lateinit var rootLayout: FrameLayout
    private lateinit var browserBar: LinearLayout
    private var dockBar: DashMateDockBar? = null
    private var isFullscreen: Boolean = false
    private var lastVisibleArea: Rect? = null
    private var currentPage: String = "home"
    private var isBrowsingWeb: Boolean = false
    private var currentZoom: Float = 1.0f
    
    // Google Sign-in Auth Overlay
    private var authOverlay: FrameLayout? = null
    private var authWebView: WebView? = null

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

        // Enable cookies globally for Google & YouTube authentication
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)

        // 1. Initialize permanent Deck WebView
        deckWebView = WebView(context).apply {
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
            }

            webChromeClient = object : WebChromeClient() {}
            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    Log.d(TAG, "Car Deck page finished loading: $url")
                    onStateUpdated(DashMateStateBridge.buildStateJson(hostContext))
                }
            }

            val bridge = AutoDeckJsInterface()
            addJavascriptInterface(bridge, "AutoDeck")
            addJavascriptInterface(bridge, "DashMateBridge")
            addJavascriptInterface(bridge, "AutoDeckWeb")

            loadUrl("file:///android_asset/drivedeck_home.html")
        }
        rootLayout.addView(deckWebView)

        // 2. Initialize dedicated Browser WebView (hidden by default)
        browserWebView = WebView(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#0B0F1A"))
            visibility = View.GONE
            setLayerType(View.LAYER_TYPE_HARDWARE, null)

            cookieManager.setAcceptThirdPartyCookies(this, true)

            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                databaseEnabled = true
                allowFileAccess = true
                allowContentAccess = true
                mediaPlaybackRequiresUserGesture = false
                cacheMode = WebSettings.LOAD_DEFAULT
                useWideViewPort = true
                loadWithOverviewMode = true
                userAgentString = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0"
                setSupportZoom(true)
                builtInZoomControls = true
                displayZoomControls = false
            }

            webChromeClient = object : WebChromeClient() {}
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                    val url = request?.url?.toString() ?: ""
                    if (isGoogleAuthUrl(url)) {
                        showAuthOverlay(url)
                        return true
                    }
                    return false
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    Log.d(TAG, "Browser page finished loading: $url")
                    injectBrowserEnhancements(view)
                }
            }

            val bridge = AutoDeckJsInterface()
            addJavascriptInterface(bridge, "AutoDeck")
            addJavascriptInterface(bridge, "AutoDeckWeb")
        }
        rootLayout.addView(browserWebView)

        // 3. Floating in-car browser navigation bar (with zoom & controls)
        browserBar = createBrowserControls()
        browserBar.visibility = View.GONE
        rootLayout.addView(browserBar)

        val density = context.resources.displayMetrics.density

        // 4. Floating in-car navigation dock bar (6-icon pill directly on head unit)
        dockBar = DashMateDockBar(context) { targetPage ->
            DashMateStateBridge.setPage(targetPage)
        }.apply {
            val lp = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.START or Gravity.TOP
                leftMargin = (16 * density + 0.5f).toInt()
                topMargin = (16 * density + 0.5f).toInt()
            }
            layoutParams = lp
        }
        rootLayout.addView(dockBar)

        // 5. In-car virtual keyboard overlay
        carKeyboard = DashMateCarKeyboard(
            context,
            onSubmit = { text, isAddressBar ->
                injectBrowserText(text, isAddressBar)
            },
            onDismiss = {
                // dismissed
            }
        )
        rootLayout.addView(carKeyboard)

        setContentView(rootLayout)
        DashMateStateBridge.addListener(this)

        updateVisibleArea(lastVisibleArea)
    }

    fun toggleFullscreen(fullscreen: Boolean) {
        isFullscreen = fullscreen
        val prefs = hostContext.getSharedPreferences("dd_car_browser", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("fullscreen", fullscreen).apply()
        // In AutoDeck, fullscreen removes system insets/padding; dockBar remains visible!
        updateVisibleArea(lastVisibleArea)
    }

    fun onSizeChanged(width: Int, height: Int) {
        rootLayout.post {
            updateVisibleArea(lastVisibleArea)
        }
    }

    fun onVisibleAreaChanged(visibleArea: Rect) {
        updateVisibleArea(visibleArea)
    }

    private fun isGoogleAuthUrl(url: String): Boolean {
        return url.contains("accounts.google.com") || url.contains("/gsi/transform")
    }

    private fun showAuthOverlay(url: String) {
        if (authOverlay == null) {
            val density = context.resources.displayMetrics.density
            authOverlay = FrameLayout(context).apply {
                layoutParams = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
                setBackgroundColor(Color.parseColor("#CC070B14"))

                val card = FrameLayout(context).apply {
                    val cardWidth = (560 * density).toInt()
                    val cardHeight = (420 * density).toInt()
                    layoutParams = FrameLayout.LayoutParams(cardWidth, cardHeight).apply {
                        gravity = Gravity.CENTER
                    }
                    background = GradientDrawable().apply {
                        setColor(Color.parseColor("#16253B"))
                        cornerRadius = 20 * density
                        setStroke((1 * density).toInt(), Color.parseColor("#335EF2D6"))
                    }

                    authWebView = WebView(context).apply {
                        layoutParams = FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.MATCH_PARENT
                        ).apply {
                            setMargins((8 * density).toInt(), (40 * density).toInt(), (8 * density).toInt(), (8 * density).toInt())
                        }
                        settings.javaScriptEnabled = true
                        settings.domStorageEnabled = true
                        webViewClient = object : WebViewClient() {
                            override fun onPageFinished(v: WebView?, u: String?) {
                                if (u != null && !u.contains("accounts.google.com")) {
                                    closeAuthOverlay()
                                    browserWebView?.reload()
                                }
                            }
                        }
                    }
                    addView(authWebView)

                    // Close button '×'
                    val closeBtn = TextView(context).apply {
                        text = "×"
                        textSize = 26f
                        setTextColor(Color.WHITE)
                        setPadding((16 * density).toInt(), (4 * density).toInt(), (16 * density).toInt(), (4 * density).toInt())
                        layoutParams = FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT
                        ).apply {
                            gravity = Gravity.END or Gravity.TOP
                        }
                        setOnClickListener {
                            closeAuthOverlay()
                        }
                    }
                    addView(closeBtn)
                }
                addView(card)
            }
            rootLayout.addView(authOverlay)
        }
        authOverlay?.visibility = View.VISIBLE
        authWebView?.loadUrl(url)
    }

    private fun closeAuthOverlay() {
        authOverlay?.visibility = View.GONE
        authWebView?.loadUrl("about:blank")
    }

    private fun injectBrowserEnhancements(view: WebView?) {
        val script = """
            (function () {
              var d = document.documentElement;
              function st(id, text) {
                if (document.getElementById(id)) return;
                var s = document.createElement('style');
                s.id = id;
                s.textContent = text;
                d.appendChild(s);
              }
              st('dd-corner', 'ytd-masthead #container.ytd-masthead{padding-right:88px!important}');
              st('dd-tap', 'html,body{touch-action:manipulation!important}');
              st('dd-fit', 'ytd-miniplayer{transform:scale(.62)!important;transform-origin:bottom right!important}');
              st('dd-fs', 'video{object-fit:cover!important}');

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

    override fun onSwitchPage(page: String) {
        if (currentPage == page && (if (page == "web" || page == "browse") isBrowsingWeb else !isBrowsingWeb)) return
        currentPage = page

        if (page == "web" || page == "browse") {
            loadWebUrl("https://m.youtube.com")
            dockBar?.updateCurrentPage("web")
            return
        }

        exitBrowserToHome(false)

        val assetUrl = when (page) {
            "lyrics" -> "file:///android_asset/drivedeck_lyrics.html"
            "prayer" -> "file:///android_asset/drivedeck_prayer.html"
            else -> "file:///android_asset/drivedeck_home.html"
        }
        deckWebView?.loadUrl(assetUrl)
        dockBar?.updateCurrentPage(page)
    }

    override fun onExecuteScript(script: String) {
        deckWebView?.post {
            deckWebView?.evaluateJavascript(script, null)
        }
    }

    fun loadWebUrl(url: String) {
        isBrowsingWeb = true
        dockBar?.visibility = View.VISIBLE
        dockBar?.updateCurrentPage("web")
        deckWebView?.visibility = View.GONE
        browserWebView?.visibility = View.VISIBLE
        browserBar.visibility = View.VISIBLE
        currentZoom = 1.0f
        browserWebView?.loadUrl(url)
    }

    fun exitBrowserToHome(reloadDeck: Boolean = false) {
        if (!isBrowsingWeb && currentPage == "home") return
        isBrowsingWeb = false
        currentPage = "home"
        browserWebView?.stopLoading()
        browserWebView?.visibility = View.GONE
        browserBar.visibility = View.GONE
        closeAuthOverlay()
        dockBar?.visibility = View.VISIBLE
        dockBar?.updateCurrentPage("home")
        deckWebView?.visibility = View.VISIBLE

        if (reloadDeck) {
            deckWebView?.loadUrl("file:///android_asset/drivedeck_home.html")
        } else {
            onStateUpdated(DashMateStateBridge.buildStateJson(hostContext))
        }
    }

    private fun createBrowserControls(): LinearLayout {
        val density = context.resources.displayMetrics.density
        val bar = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((12 * density).toInt(), (4 * density).toInt(), (12 * density).toInt(), (4 * density).toInt())
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#D90B0F1A"))
                cornerRadius = 24 * density
                setStroke((1 * density).toInt(), Color.parseColor("#33FFFFFF"))
            }
            val lp = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                (42 * density).toInt()
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                topMargin = (10 * density).toInt()
            }
            layoutParams = lp
        }

        // Home button
        val homeBtn = TextView(context).apply {
            text = "⌂ Deck"
            setTextColor(Color.parseColor("#5EF2D6"))
            textSize = 14f
            setPadding(14, 6, 14, 6)
            setOnClickListener {
                exitBrowserToHome()
            }
        }
        bar.addView(homeBtn)

        // Back button
        val backBtn = TextView(context).apply {
            text = "◀"
            setTextColor(Color.WHITE)
            textSize = 16f
            setPadding(12, 6, 12, 6)
            setOnClickListener {
                if (browserWebView?.canGoBack() == true) {
                    browserWebView?.goBack()
                } else {
                    exitBrowserToHome()
                }
            }
        }
        bar.addView(backBtn)

        // Forward button
        val fwdBtn = TextView(context).apply {
            text = "▶"
            setTextColor(Color.WHITE)
            textSize = 16f
            setPadding(12, 6, 12, 6)
            setOnClickListener {
                if (browserWebView?.canGoForward() == true) {
                    browserWebView?.goForward()
                }
            }
        }
        bar.addView(fwdBtn)

        // Reload button
        val reloadBtn = TextView(context).apply {
            text = "↻"
            setTextColor(Color.WHITE)
            textSize = 16f
            setPadding(12, 6, 12, 6)
            setOnClickListener {
                browserWebView?.reload()
            }
        }
        bar.addView(reloadBtn)

        // Search / Keyboard button
        val searchBtn = TextView(context).apply {
            text = "🔍 Search"
            setTextColor(Color.WHITE)
            textSize = 14f
            setPadding(14, 6, 14, 6)
            setOnClickListener {
                val currentUrl = browserWebView?.url ?: ""
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
            val query = text.trim()
            if (query.startsWith("http://") || query.startsWith("https://")) {
                loadWebUrl(query)
            } else if (query.contains(".") && !query.contains(" ")) {
                loadWebUrl("https://$query")
            } else {
                loadWebUrl("https://www.google.com/search?q=" + java.net.URLEncoder.encode(query, "UTF-8"))
            }
            return
        }

        val escaped = JSONObjectEscape(text)
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
            })('$escaped');
        """.trimIndent()

        browserWebView?.evaluateJavascript(script, null)
    }

    fun updateVisibleArea(visibleArea: Rect?) {
        lastVisibleArea = visibleArea
        if (visibleArea == null || !::rootLayout.isInitialized) return

        rootLayout.post {
            val screenWidth = rootLayout.width
            val screenHeight = rootLayout.height
            if (screenWidth <= 0 || screenHeight <= 0) return@post

            val insetLeft = visibleArea.left
            val insetTop = visibleArea.top
            val insetRight = screenWidth - visibleArea.right
            val insetBottom = screenHeight - visibleArea.bottom

            val padLeft = if (!isFullscreen && insetLeft > 0) insetLeft else 0
            val padTop = if (!isFullscreen && insetTop > 0) insetTop else 0
            val padRight = if (!isFullscreen && insetRight > 0) insetRight else 0
            val padBottom = if (!isFullscreen && insetBottom > 0) insetBottom else 0

            deckWebView?.setPadding(padLeft, padTop, padRight, padBottom)
            browserWebView?.setPadding(padLeft, padTop, padRight, padBottom)

            val density = context.resources.displayMetrics.density
            val lp = dockBar?.layoutParams as? FrameLayout.LayoutParams
            if (lp != null) {
                lp.leftMargin = padLeft + (16 * density + 0.5f).toInt()
                lp.topMargin = padTop + (16 * density + 0.5f).toInt()
                dockBar?.layoutParams = lp
            }
        }
    }

    override fun onStateUpdated(stateJson: String) {
        if (isBrowsingWeb) return
        val escapedJson = JSONObjectEscape(stateJson)
        val script = "if (window.ddUpdate) { window.ddUpdate('$escapedJson'); }"
        deckWebView?.post {
            deckWebView?.evaluateJavascript(script, null)
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
                if (isBrowsingWeb) {
                    val script = """
                        (function(dx, dy) {
                          var target = document.scrollingElement || document.documentElement;
                          target.scrollBy(dx, dy);
                        })($distanceX, $distanceY);
                    """.trimIndent()
                    browserWebView?.evaluateJavascript(script, null)
                }

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
