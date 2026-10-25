package com.dashmate.dashmate

import android.app.Notification
import android.content.ComponentName
import android.content.Context
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
import java.io.ByteArrayOutputStream

class DashMateMediaListenerService : NotificationListenerService() {

    private val TAG = "DashMateMediaListener"
    private var mediaSessionManager: MediaSessionManager? = null
    private val activeCallbacks = mutableMapOf<MediaController, MediaController.Callback>()
    private val latestNotifIconMap = java.util.concurrent.ConcurrentHashMap<String, Bitmap>()

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Notification Listener connected!")
        initMediaSessionManager()
        checkActiveSessions()
    }

    private fun initMediaSessionManager() {
        try {
            mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
            val componentName = ComponentName(this, DashMateMediaListenerService::class.java)
            mediaSessionManager?.addOnActiveSessionsChangedListener({ controllers ->
                handleControllers(controllers)
            }, componentName)
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

    private fun handleControllers(controllers: List<MediaController>?) {
        controllers ?: return
        var playingController: MediaController? = null
        var fallbackController: MediaController? = null

        for (controller in controllers) {
            val pkg = controller.packageName
            if (pkg == packageName) continue

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

            val state = controller.playbackState?.state
            if (state == PlaybackState.STATE_PLAYING) {
                playingController = controller
            } else if (playingController == null && (state == PlaybackState.STATE_PAUSED || state == PlaybackState.STATE_BUFFERING)) {
                fallbackController = controller
            }
        }

        val target = playingController ?: fallbackController ?: controllers.firstOrNull { it.packageName != packageName }
        if (target != null) {
            updateFromController(target)
        }
    }

    companion object {
        var activeController: MediaController? = null

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

    private val pollHandler = Handler(Looper.getMainLooper())
    private val progressPoller = object : Runnable {
        override fun run() {
            try {
                activeController?.let { controller ->
                    val state = controller.playbackState
                    val isPlaying = state?.state == PlaybackState.STATE_PLAYING
                    if (isPlaying) {
                        val rawPos = state.position
                        val updateTime = state.lastPositionUpdateTime
                        val speed = if (state.playbackSpeed > 0f) state.playbackSpeed else 1.0f
                        val elapsed = if (updateTime > 0L) (SystemClock.elapsedRealtime() - updateTime) else 0L
                        val actualPos = (rawPos + (elapsed * speed).toLong()).coerceAtLeast(0L)

                        val meta = controller.metadata
                        val dur = meta?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: DashMateStateBridge.playbackDurationMs

                        DashMateStateBridge.updatePlaybackProgress(actualPos, dur, speed)
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

    private fun updateFromController(controller: MediaController) {
        val pkg = controller.packageName
        if (pkg == packageName) return
        activeController = controller

        val metadata = controller.metadata
        val state = controller.playbackState
        val isPlaying = state?.state == PlaybackState.STATE_PLAYING

        val title = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE)
        val artist = metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
            ?: ""
        val duration = metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L

        val rawPos = state?.position ?: 0L
        val updateTime = state?.lastPositionUpdateTime ?: 0L
        val speed = if (state?.playbackSpeed != null && state.playbackSpeed > 0f) state.playbackSpeed else 1.0f
        val elapsed = if (isPlaying && updateTime > 0L) (SystemClock.elapsedRealtime() - updateTime) else 0L
        val currentPosition = (rawPos + (elapsed * speed).toLong()).coerceAtLeast(0L)

        // Extract album art from MediaMetadata or Notification Icon cache
        var artDataUrl = ""
        val artBitmap = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
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

        if (!title.isNullOrBlank()) {
            Log.d(TAG, "[$appName] Active Controller: $title - $artist (art=${artDataUrl.length}b, playing=$isPlaying, pos=$currentPosition, dur=$duration)")
            DashMateStateBridge.updateMediaInfo(
                context = this,
                title = title,
                artist = artist,
                playing = isPlaying,
                coverUrl = if (artDataUrl.isNotBlank()) artDataUrl else DashMateStateBridge.songCoverUrl,
                app = appName,
                durationMs = duration,
                positionMs = currentPosition,
                lastUpdateTime = SystemClock.elapsedRealtime(),
                speed = speed
            )
            pollHandler.removeCallbacks(progressPoller)
            if (isPlaying) {
                pollHandler.postDelayed(progressPoller, 1000L)
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        sbn ?: return

        val pkg = sbn.packageName
        // Filter out DashMate self, System UI, and non-music notifications
        if (pkg == packageName || pkg == "com.android.systemui") return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val hasMediaSession = extras.containsKey(Notification.EXTRA_MEDIA_SESSION)
        val template = extras.getString(Notification.EXTRA_TEMPLATE)
        val isMedia = hasMediaSession || (template != null && template.contains("MediaStyle"))

        if (isMedia) {
            // Extract album art from notification large icon first so controller callback has it
            var notifArtDataUrl = ""
            val largeIcon = notification.getLargeIcon()
            if (largeIcon != null) {
                try {
                    val drawable = largeIcon.loadDrawable(this)
                    if (drawable != null) {
                        val bmp = when (drawable) {
                            is BitmapDrawable -> drawable.bitmap
                            else -> {
                                val w = drawable.intrinsicWidth.coerceAtLeast(1)
                                val h = drawable.intrinsicHeight.coerceAtLeast(1)
                                val b = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                                val canvas = Canvas(b)
                                drawable.setBounds(0, 0, w, h)
                                drawable.draw(canvas)
                                b
                            }
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

            val token = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
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
            val rawTitle = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            val rawArtist = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
                ?: extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
                ?: ""

            // Filter out prayer reminders or clock alarms if misclassified as media
            if (rawTitle.startsWith("Zohor") || rawTitle.startsWith("Subuh") || rawTitle.startsWith("Asar") || rawTitle.startsWith("Maghrib") || rawTitle.startsWith("Isyak")) {
                return
            }

            var cleanT = rawTitle.trim()
            if (cleanT.startsWith("♪")) cleanT = cleanT.substring(1).trim()
            cleanT = cleanT.replace(Regex("""(?i)\s*[·•-]\s*finding\s+lyrics.*"""), "").trim()
            var cleanA = rawArtist.trim()
            cleanA = cleanA.replace(Regex("""(?i)\s*[·•-]\s*finding\s+lyrics.*"""), "").trim()
            if (cleanA.isBlank()) cleanA = "Playing"

            if (cleanT.isBlank() || cleanT == "♪" || cleanT == "♪ ♪ ♪") return

            val appName = getFriendlyAppName(pkg)

            Log.d(TAG, "[$appName] Captured Notification Now Playing: $cleanT - $cleanA (art=${notifArtDataUrl.length}b)")
            DashMateStateBridge.updateMediaInfo(
                context = this,
                title = cleanT,
                artist = cleanA,
                playing = true,
                coverUrl = if (notifArtDataUrl.isNotBlank()) notifArtDataUrl else DashMateStateBridge.songCoverUrl,
                app = appName
            )
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        sbn ?: return
        val pkg = sbn.packageName
        if (pkg == packageName) return

        val extras = sbn.notification?.extras ?: return
        if (extras.containsKey(Notification.EXTRA_MEDIA_SESSION)) {
            pollHandler.removeCallbacks(progressPoller)
            DashMateStateBridge.isPlaying = false
            DashMateStateBridge.notifyStateChanged(this)
        }
    }

    private fun bitmapToDataUrl(bitmap: Bitmap): String {
        return try {
            val maxDim = 384
            val scaled = if (bitmap.width > maxDim || bitmap.height > maxDim) {
                val ratio = maxDim.toFloat() / Math.max(bitmap.width, bitmap.height)
                Bitmap.createScaledBitmap(bitmap, (bitmap.width * ratio).toInt(), (bitmap.height * ratio).toInt(), true)
            } else {
                bitmap
            }
            val stream = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 80, stream)
            val bytes = stream.toByteArray()
            val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
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
            contentResolver.openInputStream(uri)?.use { stream ->
                val bmp = BitmapFactory.decodeStream(stream)
                if (bmp != null) bitmapToDataUrl(bmp) else ""
            } ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    private fun getFriendlyAppName(pkg: String): String {
        return try {
            val pm = packageManager
            val info = pm.getApplicationInfo(pkg, 0)
            val label = pm.getApplicationLabel(info).toString()
            if (label.isNotBlank()) label else mapPackageFallback(pkg)
        } catch (_: Exception) {
            mapPackageFallback(pkg)
        }
    }

    private fun mapPackageFallback(pkg: String): String {
        val lower = pkg.lowercase()
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
