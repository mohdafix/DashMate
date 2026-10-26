package com.dashmate.dashmate

import android.content.ComponentName
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSession
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Base64
import android.util.Log
import android.app.Notification
import java.io.ByteArrayOutputStream
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap

/**
 * Notification listener that discovers other apps' media sessions (Spotify,
 * YouTube Music, ...) and pushes now-playing info into [DashMateStateBridge].
 */
class DashMateMediaListenerService : NotificationListenerService() {

    companion object {
        var activeController: MediaController? = null

        /** Set while Android has this listener connected (it can read active notifications). */
        @Volatile
        private var instance: DashMateMediaListenerService? = null

        /** Android Auto's own connection notification: gearhead, foreground-service, no-clear. */
        fun isAaConnection(sbn: StatusBarNotification): Boolean =
            sbn.packageName == DashMateCarLife.GEARHEAD &&
                (sbn.notification?.flags ?: 0) and Notification.FLAG_FOREGROUND_SERVICE != 0

        /**
         * postTime (epoch ms) of Android Auto's active connection notification, 0 if none is
         * active, or null if the listener is not connected (unknown).
         */
        fun aaConnectionPostTime(): Long? {
            val svc = instance ?: return null
            return try {
                svc.activeNotifications?.filter { isAaConnection(it) }?.maxOfOrNull { it.postTime } ?: 0L  // newest: errs toward hand-back
            } catch (e: Exception) {
                Log.w("DashMateMediaListener", "active notifications: ${e.message}")
                null
            }
        }

        fun play() {
            try {
                activeController?.transportControls?.play()
            } catch (e: Exception) {
                Log.w("DashMateMediaListener", "play failed: ${e.message}")
            }
        }

        fun pause() {
            try {
                activeController?.transportControls?.pause()
            } catch (e: Exception) {
                Log.w("DashMateMediaListener", "pause failed: ${e.message}")
            }
        }

        fun skipToNext() {
            try {
                activeController?.transportControls?.skipToNext()
            } catch (e: Exception) {
                Log.w("DashMateMediaListener", "skipNext failed: ${e.message}")
            }
        }

        fun skipToPrevious() {
            try {
                activeController?.transportControls?.skipToPrevious()
            } catch (e: Exception) {
                Log.w("DashMateMediaListener", "skipPrev failed: ${e.message}")
            }
        }

        fun seekTo(posMs: Long) {
            try {
                activeController?.transportControls?.seekTo(posMs)
            } catch (e: Exception) {
                Log.w("DashMateMediaListener", "seekTo failed: ${e.message}")
            }
        }

        fun fastForward(offsetMs: Long = 10000L) {
            val cur = DashMateStateBridge.getCurrentPositionMs()
            seekTo(cur + offsetMs)
        }

        fun rewind(offsetMs: Long = 10000L) {
            val cur = DashMateStateBridge.getCurrentPositionMs()
            seekTo((cur - offsetMs).coerceAtLeast(0L))
        }
    }

    private val TAG = "DashMateMediaListener"
    private var mediaSessionManager: MediaSessionManager? = null
    private val activeCallbacks = mutableMapOf<MediaController, MediaController.Callback>()
    private val latestNotifIconMap = ConcurrentHashMap<String, Bitmap>()
    private val pollHandler = Handler(Looper.getMainLooper())

    private val progressPoller = object : Runnable {
        override fun run() {
            try {
                val controller = activeController
                if (controller != null) {
                    val state = controller.playbackState
                    if (state != null && state.state == PlaybackState.STATE_PLAYING) {
                        val pos = state.position
                        val lastUpdate = state.lastPositionUpdateTime
                        val speed = if (state.playbackSpeed > 0f) state.playbackSpeed else 1.0f
                        val elapsed = if (lastUpdate > 0) SystemClock.elapsedRealtime() - lastUpdate else 0L
                        val currentPos = (pos + (elapsed * speed).toLong()).coerceAtLeast(0L)
                        val duration = controller.metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION)
                            ?: DashMateStateBridge.playbackDurationMs
                        DashMateStateBridge.updatePlaybackProgress(currentPos, duration, speed)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error polling media progress: ${e.message}")
            }
            if (DashMateStateBridge.isPlaying) {
                pollHandler.postDelayed(this, 1000L)
            }
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Notification Listener connected!")
        instance = this
        // Android Auto's connection notification is DashMate's live "connected since" signal.
        aaConnectionPostTime()?.takeIf { it > 0L }?.let { DashMateCarLife.noteGearheadNotification(applicationContext, it) }
        initMediaSessionManager()
        checkActiveSessions()
    }

    private fun initMediaSessionManager() {
        try {
            mediaSessionManager = getSystemService(MEDIA_SESSION_SERVICE) as? MediaSessionManager
            val componentName = ComponentName(this, DashMateMediaListenerService::class.java)
            mediaSessionManager?.addOnActiveSessionsChangedListener(
                { controllers -> handleControllers(controllers) },
                componentName,
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to register active sessions listener: ${e.message}")
        }
    }

    private fun checkActiveSessions() {
        try {
            val componentName = ComponentName(this, DashMateMediaListenerService::class.java)
            val controllers = mediaSessionManager?.getActiveSessions(componentName)
            handleControllers(controllers)
        } catch (e: Exception) {
            Log.w(TAG, "Failed getting active sessions: ${e.message}")
        }
    }

    private fun isOwnPackage(pkg: String?): Boolean =
        pkg == packageName 

    private fun handleControllers(controllers: List<MediaController>?) {
        if (controllers == null) return

        var playingController: MediaController? = null
        var pausedController: MediaController? = null
        for (controller in controllers) {
            if (isOwnPackage(controller.packageName)) continue

            if (!activeCallbacks.containsKey(controller)) {
                val cb = object : MediaController.Callback() {
                    override fun onPlaybackStateChanged(state: PlaybackState?) {
                        updateFromController(controller)
                    }

                    override fun onMetadataChanged(metadata: MediaMetadata?) {
                        updateFromController(controller)
                    }
                }
                controller.registerCallback(cb)
                activeCallbacks[controller] = cb
            }

            val st = controller.playbackState?.state
            if (st == PlaybackState.STATE_PLAYING) {
                playingController = controller
            } else if (playingController == null &&
                (st == PlaybackState.STATE_PAUSED || st == PlaybackState.STATE_BUFFERING)
            ) {
                pausedController = controller
            }
        }

        val target = playingController
            ?: pausedController
            ?: controllers.firstOrNull { !isOwnPackage(it.packageName) }
        if (target != null) {
            updateFromController(target)
        }
    }

    // RECONSTRUCTED: jadx failed on this method; logic rebuilt from the partial
    // bad-code output (its null-check branches were inverted by the decompiler).
    private fun updateFromController(controller: MediaController) {
        val pkg = controller.packageName
        if (isOwnPackage(pkg)) return
        activeController = controller

        val metadata = controller.metadata
        val state = controller.playbackState
        val isPlaying = state != null && state.state == PlaybackState.STATE_PLAYING

        val title = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)
        val artist = metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
            ?: ""
        val duration = metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
        val rawPos = state?.position ?: 0L
        val updateTime = state?.lastPositionUpdateTime ?: 0L
        val speed = state?.playbackSpeed?.takeIf { it > 0f } ?: 1.0f
        val elapsed = if (isPlaying && updateTime > 0) SystemClock.elapsedRealtime() - updateTime else 0L
        val currentPosition = (rawPos + (elapsed * speed).toLong()).coerceAtLeast(0L)

        var artDataUrl = ""
        val artBitmap: Bitmap? = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)
            ?: latestNotifIconMap[pkg]

        if (artBitmap != null) {
            artDataUrl = bitmapToDataUrl(artBitmap)
            DashMateStateBridge.currentArtBitmap = artBitmap
            val savedUri = CarArtProvider.saveArt(this, "current_art.png", artBitmap)
            DashMateStateBridge.currentArtUri = savedUri ?: CarArtProvider.getArtUri("current_art.png")
        } else {
            val artUriStr = metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI)
                ?: metadata?.getString(MediaMetadata.METADATA_KEY_ART_URI)
            if (!artUriStr.isNullOrBlank()) {
                artDataUrl = loadUriToDataUrl(artUriStr)
                DashMateStateBridge.currentArtUri = Uri.parse(artUriStr)
            }
        }

        val appName = getFriendlyAppName(pkg)
        if (title.isNullOrBlank()) return

        Log.d(
            TAG,
            "[$appName] Active Controller: $title - $artist (art=${artDataUrl.length}b, " +
                "playing=$isPlaying, pos=$currentPosition, dur=$duration)"
        )
        DashMateStateBridge.updateMediaInfo(
            this,
            title,
            artist,
            isPlaying,
            if (artDataUrl.isNotBlank()) artDataUrl else DashMateStateBridge.songCoverUrl,
            appName,
            duration,
            currentPosition,
            SystemClock.elapsedRealtime(),
            speed,
        )
        pollHandler.removeCallbacks(progressPoller)
        if (isPlaying) {
            pollHandler.postDelayed(progressPoller, 1000L)
        }
    }

    // RECONSTRUCTED: jadx failed on this method; logic rebuilt from the partial
    // bad-code output (its null-check / prayer-filter conditions were inverted).
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return
        val pkg = sbn.packageName
        if (isAaConnection(sbn)) DashMateCarLife.noteGearheadNotification(applicationContext, sbn.postTime)
        if (isOwnPackage(pkg) || pkg == "com.android.systemui") return
        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val hasMediaSession = extras.containsKey(Notification.EXTRA_MEDIA_SESSION)
        val template = extras.getString(Notification.EXTRA_TEMPLATE)
        val isMedia = hasMediaSession || (template != null && template.contains("MediaStyle"))
        if (!isMedia) return

        var notifArtDataUrl = ""
        val largeIcon = notification.getLargeIcon()
        if (largeIcon != null) {
            try {
                val drawable = largeIcon.loadDrawable(this)
                if (drawable != null) {
                    val bmp: Bitmap? = if (drawable is BitmapDrawable) {
                        drawable.bitmap
                    } else {
                        val w = drawable.intrinsicWidth.coerceAtLeast(1)
                        val h = drawable.intrinsicHeight.coerceAtLeast(1)
                        val b = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                        val canvas = Canvas(b)
                        drawable.setBounds(0, 0, w, h)
                        drawable.draw(canvas)
                        b
                    }
                    if (bmp != null) {
                        latestNotifIconMap[pkg] = bmp
                        DashMateStateBridge.currentArtBitmap = bmp
                        val savedUri = CarArtProvider.saveArt(this, "current_art.png", bmp)
                        DashMateStateBridge.currentArtUri = savedUri ?: CarArtProvider.getArtUri("current_art.png")
                        notifArtDataUrl = bitmapToDataUrl(bmp)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error loading notification large icon: ${e.message}")
            }
        }

        val token: MediaSession.Token? = if (Build.VERSION.SDK_INT >= 33) {
            extras.getParcelable(Notification.EXTRA_MEDIA_SESSION, MediaSession.Token::class.java)
        } else {
            @Suppress("DEPRECATION")
            extras.getParcelable(Notification.EXTRA_MEDIA_SESSION)
        }
        if (token != null) {
            try {
                val controller = MediaController(this, token)
                activeController = controller
                updateFromController(controller)
                return
            } catch (e: Exception) {
                Log.w(TAG, "Error creating controller from session token: ${e.message}")
            }
        }

        // Fallback: scrape title/text from the notification itself.
        val rawTitle = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val rawArtist = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
            ?: ""

        // Ignore our own prayer-time style notifications from other apps.
        if (rawTitle.startsWith("Zohor") || rawTitle.startsWith("Subuh") ||
            rawTitle.startsWith("Asar") || rawTitle.startsWith("Maghrib") ||
            rawTitle.startsWith("Isyak")
        ) {
            return
        }

        var cleanT = rawTitle.trim()
        if (cleanT.startsWith("♪")) {
            cleanT = cleanT.substring(1).trim()
        }
        val findingLyrics = Regex("(?i)\\s*[·•-]\\s*finding\\s+lyrics.*")
        cleanT = findingLyrics.replace(cleanT, "").trim()
        var cleanA = findingLyrics.replace(rawArtist.trim(), "").trim()
        if (cleanA.isBlank()) {
            cleanA = "Playing"
        }
        if (cleanT.isBlank() || cleanT == "♪" || cleanT == "♪ ♪ ♪") return

        val appName = getFriendlyAppName(pkg)
        Log.d(TAG, "[$appName] Captured Notification Now Playing: $cleanT - $cleanA (art=${notifArtDataUrl.length}b)")
        DashMateStateBridge.updateMediaInfo(
            this,
            cleanT,
            cleanA,
            true,
            coverUrl = if (notifArtDataUrl.isNotBlank()) notifArtDataUrl else DashMateStateBridge.songCoverUrl,
            app = appName,
        )
    }

    override fun onListenerDisconnected() {
        if (instance === this) instance = null
        super.onListenerDisconnected()
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        if (sbn == null) return
        if (isAaConnection(sbn)) DashMateCarLife.onAaNotificationRemoved()
        val pkg = sbn.packageName
        if (isOwnPackage(pkg)) return
        val extras = sbn.notification?.extras ?: return
        if (extras.containsKey(Notification.EXTRA_MEDIA_SESSION)) {
            pollHandler.removeCallbacks(progressPoller)
            DashMateStateBridge.isPlaying = false
            DashMateStateBridge.notifyStateChanged(this)
        }
    }

    private fun bitmapToDataUrl(bitmap: Bitmap): String {
        return try {
            val scaled = if (bitmap.width > 384 || bitmap.height > 384) {
                val ratio = 384f / maxOf(bitmap.width, bitmap.height)
                Bitmap.createScaledBitmap(
                    bitmap,
                    (bitmap.width * ratio).toInt(),
                    (bitmap.height * ratio).toInt(),
                    true,
                )
            } else {
                bitmap
            }
            val stream = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 80, stream)
            val base64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
            "data:image/jpeg;base64,$base64"
        } catch (e: Exception) {
            Log.w(TAG, "Failed encoding bitmap to data url: ${e.message}")
            ""
        }
    }

    private fun loadUriToDataUrl(uriStr: String): String {
        if (uriStr.startsWith("http://", ignoreCase = true) || uriStr.startsWith("https://", ignoreCase = true)) {
            return uriStr
        }
        return try {
            val uri = Uri.parse(uriStr)
            contentResolver.openInputStream(uri)?.use { input ->
                val bmp = BitmapFactory.decodeStream(input)
                if (bmp != null) bitmapToDataUrl(bmp) else ""
            } ?: ""
        } catch (e: Exception) {
            ""
        }
    }

    private fun getFriendlyAppName(pkg: String): String {
        return try {
            val pm = packageManager
            val info = pm.getApplicationInfo(pkg, 0)
            val label = pm.getApplicationLabel(info).toString()
            if (label.isNotBlank()) label else mapPackageFallback(pkg)
        } catch (e: Exception) {
            mapPackageFallback(pkg)
        }
    }

    private fun mapPackageFallback(pkg: String): String {
        val lower = pkg.lowercase(Locale.ROOT)
        return when {
            lower.contains("youtube.music") -> "YouTube Music"
            lower.contains("spotify") -> "Spotify"
            lower.contains("apple.android.music") -> "Apple Music"
            lower.contains("tidal") -> "Tidal"
            lower.contains("deezer") -> "Deezer"
            lower.contains("soundcloud") -> "SoundCloud"
            lower.contains("amazon.mp3") -> "Amazon Music"
            lower.contains("qobuz") -> "Qobuz"
            lower.contains("audiomack") -> "Audiomack"
            else -> "Media Player"
        }
    }
}
