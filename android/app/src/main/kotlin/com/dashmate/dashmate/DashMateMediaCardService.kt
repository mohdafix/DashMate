package com.dashmate.dashmate

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaDescriptionCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.media.MediaBrowserServiceCompat
import androidx.media.session.MediaButtonReceiver
import com.dashmate.dashmate.deck.RadioStation
import com.dashmate.dashmate.deck.RadioStations
import com.dashmate.dashmate.deck.radio.RadioPlayer
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

/**
 * MediaBrowserService shown in Android Auto as "DashMate Card". It mirrors the
 * now-playing state (with the active lyric line as subtitle) or alternate cards
 * (next prayer / football) next to navigation.
 *
 * It also hosts real Malaysian radio playback ("Radio" folder in the browse tree, voice
 * "play <station> on DashMate"). While radio mode is active the session reflects the radio
 * player; when radio is stopped, loses focus to another app, stays paused for
 * [RADIO_LONG_PAUSE_MS], or the user picks the "DashMate Live" card item, it falls back to the
 * lyrics / prayer / football card.
 */
class DashMateMediaCardService : MediaBrowserServiceCompat(), DashMateStateBridge.StateListener {

    companion object {
        private const val TAG = "DashMateMediaCard"
        /** The "app" Now Playing shows while DashMate's own radio plays. */
        const val RADIO_APP_NAME = "DashMate Radio"
        private const val ROOT_ID = "__DASHMATE_CARD_ROOT__"
        private const val MEDIA_ID = "dashmate_live_card"
        private const val CHANNEL_ID = "dashmate_media_card_channel"
        private const val NOTIFICATION_ID = 2001
        private const val RADIO_FOLDER_ID = "__DASHMATE_RADIO__"
        private const val RADIO_LONG_PAUSE_MS = 10 * 60 * 1000L
        private const val RADIO_ERROR_TIMEOUT_MS = 60 * 1000L

        // Android Auto content-style hints
        private const val CONTENT_STYLE_SUPPORTED = "android.media.browse.CONTENT_STYLE_SUPPORTED"
        private const val CONTENT_STYLE_BROWSABLE_HINT = "android.media.browse.CONTENT_STYLE_BROWSABLE_HINT"
        private const val CONTENT_STYLE_PLAYABLE_HINT = "android.media.browse.CONTENT_STYLE_PLAYABLE_HINT"
        private const val CONTENT_STYLE_LIST = 1
        private const val CONTENT_STYLE_GRID = 2
        private const val SEARCH_SUPPORTED = "android.media.browse.SEARCH_SUPPORTED"

        var instance: DashMateMediaCardService? = null

        fun triggerUpdate() {
            instance?.updateSession()
        }

        // ---- Radio controls for the Deck's Radio page (same paths as the car's media buttons) ----
        private fun controls(): MediaControllerCompat.TransportControls? {
            // Calls from here come from the owner's taps on the Deck's Radio page.
            instance?.lastUserIntentAt = SystemClock.elapsedRealtime()
            return instance?.mediaSession?.controller?.transportControls
        }

        /** Red Exit on the car deck: DashMate leaves nothing playing. */
        fun stopRadioForExit() {
            val svc = instance ?: return
            if (svc.radioMode || svc.radioPlayer != null) {
                Log.i(TAG, "Exit: stopping DashMate Radio")
                svc.exitRadioMode()
            }
            svc.refreshForeground()
            // Not "started" any more: the service lives on only while Android Auto is bound to it.
            if (!DashMateStateBridge.isPlaying) svc.stopSelf()
        }

        /** Window after connect / service start in which an unasked "play" is Android Auto's autoplay. */
        private const val AUTOPLAY_WINDOW_MS = 15_000L
        private const val GEARHEAD = "com.google.android.projection.gearhead"

        fun radioPlay(stationId: String) {
            val st = RadioStations.byId(stationId) ?: return
            controls()?.playFromMediaId(st.mediaId, null)
        }

        fun radioToggle() {
            val svc = instance ?: return
            if (svc.radioMode && svc.radioPlayer?.wantsToPlay == true) controls()?.pause()
            else if (svc.radioMode) controls()?.play()
            else controls()?.playFromSearch("", null) // resume last station
        }

        fun radioNext() { if (instance?.radioMode == true) controls()?.skipToNext() }
        fun radioPrev() { if (instance?.radioMode == true) controls()?.skipToPrevious() }
        fun radioStop() { if (instance?.radioMode == true) controls()?.stop() }

        /** {on, id, name, subtitle, status, nowPlaying, error} for the Radio page. */
        fun radioStateJson(): String {
            val svc = instance
            val p = svc?.radioPlayer
            val st = p?.station ?: svc?.lastRadioStation
            return org.json.JSONObject().apply {
                put("service", svc != null)
                put("on", svc?.radioMode == true)
                put("id", st?.id ?: "")
                put("name", st?.name ?: "")
                put("subtitle", st?.subtitle ?: "")
                put("status", p?.status?.name ?: "IDLE")
                put("nowPlaying", p?.nowPlaying ?: "")
                put("error", p?.errorMessage ?: "")
            }.toString()
        }

        fun radioStationsJson(): String = org.json.JSONArray().apply {
            RadioStations.all.forEach { st ->
                put(org.json.JSONObject().apply {
                    put("id", st.id); put("name", st.name); put("network", st.network); put("band", st.band)
                })
            }
        }.toString()
    }

    private lateinit var mediaSession: MediaSessionCompat
    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastRenderedLyric: String = ""
    @Suppress("unused")
    private var isServiceBound: Boolean = false

    // ---------------------------------------------------------------- radio state
    /** True while the session shows/controls the radio instead of the card. */
    private var radioMode: Boolean = false
    private var lastRadioStation: RadioStation? = null
    private var radioPlayer: RadioPlayer? = null

    // ------------------------------------------------------- autoplay guard
    private var serviceCreatedAt = 0L
    private var gearheadConnectedAt = 0L
    private var lastGearheadRootAt = 0L

    /** Last time the owner did something that asks for audio (deck tap, browsing, voice search). */
    private var lastUserIntentAt = 0L

    /**
     * True when a play command arrives shortly after the phone connected (or after AA started
     * this service) with no sign of the owner asking: that is Android Auto's "start music
     * automatically" or a head-unit PLAY on connect. DashMate then stays quiet.
     */
    private fun isUnaskedAutoplay(command: String): Boolean {
        val now = SystemClock.elapsedRealtime()
        val start = maxOf(serviceCreatedAt, gearheadConnectedAt, DashMateCarLife.projectionSince)
        val caller = try {
            mediaSession.currentControllerInfo.packageName
        } catch (_: Exception) {
            "?"
        }
        val inWindow = now - start < AUTOPLAY_WINDOW_MS
        val asked = lastUserIntentAt > 0L && now - lastUserIntentAt < AUTOPLAY_WINDOW_MS
        val blocked = inWindow && !asked
        Log.i(
            DashMateCarLife.TAG,
            "media $command from $caller: ${now - start}ms after connect/start, asked=$asked -> " +
                if (blocked) "IGNORED (autoplay)" else "ok",
        )
        if (blocked) mainHandler.post { updateSession() } // keep AA showing "paused"
        return blocked
    }

    private val radioListener = object : RadioPlayer.Listener {
        override fun onRadioStateChanged() {
            if (radioMode) {
                renderRadioSession()
                scheduleLongPauseCheck()
                pushRadioToNowPlaying()
            }
        }

        override fun onRadioFocusLostPermanently() {
            // Another player (Spotify etc.) took over - go back to the lyrics card.
            Log.d(TAG, "Radio lost audio focus permanently -> card mode")
            // Post: don't release the player from inside its own listener callback.
            mainHandler.post {
                if (radioMode && radioPlayer?.wantsToPlay != true) exitRadioMode()
            }
        }
    }

    private val radioLongPauseRunnable = Runnable {
        val p = radioPlayer
        if (radioMode && (p == null || !p.wantsToPlay)) {
            Log.d(TAG, "Radio paused/errored for a long time -> card mode")
            exitRadioMode()
        }
    }

    private val transientErrorClear = Runnable { if (!radioMode) updateSession() }

    private val lyricTicker = object : Runnable {
        override fun run() {
            try {
                if (!radioMode && DashMateStateBridge.isPlaying) {
                    val curLyric = getActiveLyricLine()
                    if (curLyric != lastRenderedLyric) {
                        lastRenderedLyric = curLyric
                        updateMetadataOnly()
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Ticker error: ${e.message}")
            }
            if (!radioMode && DashMateStateBridge.isPlaying) {
                mainHandler.postDelayed(this, 350L)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        serviceCreatedAt = SystemClock.elapsedRealtime()
        Log.d(TAG, "DashMateMediaCardService created!")
        createNotificationChannel()

        mediaSession = MediaSessionCompat(this, "DashMateCard").apply {
            @Suppress("DEPRECATION")
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    Log.d(TAG, "MediaSession: onPlay received (radioMode=$radioMode)")
                    if (isUnaskedAutoplay("onPlay")) return
                    if (radioMode) {
                        radioPlayer?.resume() ?: lastRadioStation?.let { playStation(it) }
                        return
                    }
                    DashMateMediaListenerService.play()
                }

                override fun onPause() {
                    Log.d(TAG, "MediaSession: onPause received (radioMode=$radioMode)")
                    if (radioMode) {
                        radioPlayer?.pause()
                        return
                    }
                    DashMateMediaListenerService.pause()
                }

                override fun onStop() {
                    Log.d(TAG, "MediaSession: onStop received (radioMode=$radioMode)")
                    if (radioMode) exitRadioMode()
                }

                override fun onSkipToNext() {
                    Log.d(TAG, "MediaSession: onSkipToNext received (radioMode=$radioMode)")
                    if (radioMode) {
                        playStation(RadioStations.next(radioPlayer?.station ?: lastRadioStation))
                        return
                    }
                    DashMateMediaListenerService.skipToNext()
                }

                override fun onSkipToPrevious() {
                    Log.d(TAG, "MediaSession: onSkipToPrevious received (radioMode=$radioMode)")
                    if (radioMode) {
                        playStation(RadioStations.previous(radioPlayer?.station ?: lastRadioStation))
                        return
                    }
                    DashMateMediaListenerService.skipToPrevious()
                }

                override fun onPlayFromMediaId(mediaId: String?, extras: Bundle?) {
                    Log.d(TAG, "MediaSession: onPlayFromMediaId $mediaId")
                    if (isUnaskedAutoplay("onPlayFromMediaId $mediaId")) return
                    val station = RadioStations.byMediaId(mediaId)
                    when {
                        station != null -> playStation(station)
                        mediaId == MEDIA_ID -> exitRadioMode() // back to the live card
                    }
                }

                override fun onPlayFromSearch(query: String?, extras: Bundle?) {
                    Log.d(TAG, "MediaSession: onPlayFromSearch '$query'")
                    if (query.isNullOrBlank()) {
                        if (isUnaskedAutoplay("onPlayFromSearch(empty)")) return
                        // "Play DashMate" - resume the last station, else the first one.
                        playStation(radioPlayer?.station ?: lastRadioStation ?: RadioStations.all.first())
                        return
                    }
                    lastUserIntentAt = SystemClock.elapsedRealtime() // spoken / typed station name
                    val station = RadioStations.findBest(query)
                    if (station != null) {
                        playStation(station)
                    } else {
                        showTransientError("No station found for \"$query\"")
                    }
                }

                override fun onSkipToQueueItem(id: Long) {
                    val idx = id.toInt()
                    if (idx in RadioStations.all.indices) playStation(RadioStations.all[idx])
                }

                override fun onFastForward() {
                    if (radioMode) return
                    Log.d(TAG, "MediaSession: onFastForward (+10s) received")
                    DashMateMediaListenerService.fastForward(10000L)
                }

                override fun onRewind() {
                    if (radioMode) return
                    Log.d(TAG, "MediaSession: onRewind (-10s) received")
                    DashMateMediaListenerService.rewind(10000L)
                }

                override fun onSeekTo(pos: Long) {
                    if (radioMode) return
                    Log.d(TAG, "MediaSession: onSeekTo $pos received")
                    DashMateMediaListenerService.seekTo(pos)
                }

                override fun onCustomAction(action: String?, extras: Bundle?) {
                    if (radioMode) return
                    when (action) {
                        "ACTION_REWIND_10" -> DashMateMediaListenerService.rewind(10000L)
                        "ACTION_FAST_FORWARD_10" -> DashMateMediaListenerService.fastForward(10000L)
                    }
                }
            })
            setMediaButtonReceiver(
                PendingIntent.getBroadcast(
                    this@DashMateMediaCardService,
                    0,
                    Intent(Intent.ACTION_MEDIA_BUTTON, null, this@DashMateMediaCardService, MediaButtonReceiver::class.java),
                    PendingIntent.FLAG_IMMUTABLE,
                )
            )
            isActive = true
        }
        sessionToken = mediaSession.sessionToken

        prepareDefaultCardArt()
        DashMateStateBridge.addListener(this)
        updateSession()
    }

    private var isForeground = false

    /**
     * Foreground (with the media notification) only while something plays: DashMate Radio, or the
     * song the lyrics card mirrors. Idle, it drops the notification so nothing looks "running".
     */
    private fun refreshForeground() {
        val wanted = if (radioMode) radioPlayer != null else DashMateStateBridge.isPlaying
        if (wanted) {
            try {
                startForeground(NOTIFICATION_ID, buildForegroundNotification())
                isForeground = true
            } catch (e: Exception) {
                Log.w(TAG, "startForeground error: ${e.message}")
            }
        } else if (isForeground) {
            isForeground = false
            try {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } catch (_: Exception) {
            }
        }
    }

    /**
     * Started by the deck / RadioJsInterface (startForegroundService) or by MediaButtonReceiver
     * (a media key, e.g. the head unit's PLAY on connect). startForeground must follow quickly,
     * or Android kills the app ("isn't responding"); then drop it again if nothing plays.
     */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            startForeground(NOTIFICATION_ID, buildForegroundNotification())
            isForeground = true
        } catch (e: Exception) {
            Log.w(TAG, "onStartCommand startForeground: ${e.message}")
        }
        if (intent?.action == Intent.ACTION_MEDIA_BUTTON) {
            Log.i(DashMateCarLife.TAG, "media button ${intent.extras?.get(Intent.EXTRA_KEY_EVENT)}")
            MediaButtonReceiver.handleIntent(mediaSession, intent)
        }
        mainHandler.post { refreshForeground() }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        DashMateStateBridge.removeListener(this)
        mainHandler.removeCallbacks(lyricTicker)
        mainHandler.removeCallbacks(radioLongPauseRunnable)
        mainHandler.removeCallbacks(transientErrorClear)
        radioMode = false
        radioPlayer?.release()
        radioPlayer = null
        mediaSession.isActive = false
        mediaSession.release()
        if (instance == this) {
            instance = null
        }
        super.onDestroy()
    }

    override fun onGetRoot(clientPackageName: String, clientUid: Int, rootHints: Bundle?): MediaBrowserServiceCompat.BrowserRoot? {
        Log.d(TAG, "onGetRoot called by $clientPackageName hints=${rootHints?.keySet()}")
        // Never offer a "recent" (resumable) root: Android's media resumption and AA's autoplay
        // use it to restart the last media app on boot / connect.
        if (rootHints?.getBoolean(MediaBrowserServiceCompat.BrowserRoot.EXTRA_RECENT) == true) {
            Log.i(DashMateCarLife.TAG, "onGetRoot: refused EXTRA_RECENT from $clientPackageName")
            return null
        }
        if (clientPackageName == GEARHEAD) {
            val now = SystemClock.elapsedRealtime()
            // First AA bind after a gap = a new connection.
            if (lastGearheadRootAt == 0L || now - lastGearheadRootAt > 2 * 60_000L) {
                gearheadConnectedAt = now
                DashMateCarLife.noteConnectSignal("AA media bind")
            }
            lastGearheadRootAt = now
        }
        val extras = Bundle().apply {
            putBoolean(CONTENT_STYLE_SUPPORTED, true)
            putInt(CONTENT_STYLE_BROWSABLE_HINT, CONTENT_STYLE_LIST)
            putInt(CONTENT_STYLE_PLAYABLE_HINT, CONTENT_STYLE_LIST)
            putBoolean(SEARCH_SUPPORTED, true)
        }
        return MediaBrowserServiceCompat.BrowserRoot(ROOT_ID, extras)
    }

    override fun onLoadChildren(parentId: String, result: MediaBrowserServiceCompat.Result<MutableList<MediaBrowserCompat.MediaItem>>) {
        val items = mutableListOf<MediaBrowserCompat.MediaItem>()
        when (parentId) {
            ROOT_ID -> {
                val title = DashMateStateBridge.songTitle
                val desc = MediaDescriptionCompat.Builder()
                    .setMediaId(MEDIA_ID)
                    .setTitle(if (title.isNotBlank()) title else "DashMate Live")
                    .setSubtitle(getActiveLyricLine())
                    .build()
                items.add(MediaBrowserCompat.MediaItem(desc, MediaBrowserCompat.MediaItem.FLAG_PLAYABLE))

                val radioExtras = Bundle().apply {
                    putInt(CONTENT_STYLE_PLAYABLE_HINT, CONTENT_STYLE_LIST)
                }
                val radioFolder = MediaDescriptionCompat.Builder()
                    .setMediaId(RADIO_FOLDER_ID)
                    .setTitle("Radio")
                    .setSubtitle("Malaysian radio stations")
                    .setIconUri(launcherIconUri())
                    .setExtras(radioExtras)
                    .build()
                items.add(MediaBrowserCompat.MediaItem(radioFolder, MediaBrowserCompat.MediaItem.FLAG_BROWSABLE))
            }
            RADIO_FOLDER_ID -> {
                lastUserIntentAt = SystemClock.elapsedRealtime() // the owner opened the Radio folder
                RadioStations.all.forEach { items.add(stationMediaItem(it)) }
            }
        }
        result.sendResult(items)
    }

    override fun onSearch(query: String, extras: Bundle?, result: MediaBrowserServiceCompat.Result<MutableList<MediaBrowserCompat.MediaItem>>) {
        lastUserIntentAt = SystemClock.elapsedRealtime()
        val matches = RadioStations.search(query).ifEmpty {
            // Fall back to a plain substring match so partial typing still shows something.
            RadioStations.all.filter { it.name.contains(query.trim(), ignoreCase = true) }
        }
        result.sendResult(matches.map { stationMediaItem(it) }.toMutableList())
    }

    private fun launcherIconUri(): Uri =
        Uri.parse("android.resource://$packageName/${R.mipmap.ic_launcher}")

    private fun stationMediaItem(st: RadioStation): MediaBrowserCompat.MediaItem {
        val desc = MediaDescriptionCompat.Builder()
            .setMediaId(st.mediaId)
            .setTitle(st.name)
            .setSubtitle(st.subtitle)
            .setIconUri(launcherIconUri())
            .build()
        return MediaBrowserCompat.MediaItem(desc, MediaBrowserCompat.MediaItem.FLAG_PLAYABLE)
    }

    // ================================================================= radio mode

    private fun playStation(station: RadioStation) {
        Log.d(TAG, "Radio: tuning to ${station.name}")
        mainHandler.removeCallbacks(transientErrorClear)
        mainHandler.removeCallbacks(lyricTicker)
        val player = radioPlayer ?: RadioPlayer(applicationContext, radioListener).also { radioPlayer = it }
        val wasRadio = radioMode
        radioMode = true
        lastRadioStation = station
        if (!wasRadio) {
            mediaSession.setQueue(RadioStations.all.mapIndexed { i, st ->
                MediaSessionCompat.QueueItem(stationMediaItem(st).description, i.toLong())
            })
            mediaSession.setQueueTitle("Radio")
        }
        player.play(station)
        mediaSession.isActive = true
        renderRadioSession()
        ensureStartedForRadio()
    }

    /**
     * DashMate's own radio is ignored by the media listener (it skips our package), so feed Now
     * Playing directly: the song when the station sends one (lyrics are then looked up, timed from
     * when the song started), otherwise the station.
     */
    private fun pushRadioToNowPlaying(playingOverride: Boolean? = null) {
        val p = radioPlayer
        val station = p?.station ?: lastRadioStation ?: return
        val np = com.dashmate.dashmate.deck.radio.RadioNowPlaying.from(p?.nowPlaying, station.name, station.subtitle)
        val playing = playingOverride ?: (p?.status == RadioPlayer.Status.PLAYING || p?.status == RadioPlayer.Status.BUFFERING)
        // Cover: the song's album art when found, otherwise the station's badge (never a blank square).
        val badge = com.dashmate.dashmate.deck.radio.RadioArt.stationBadge(station)
        var cover = badge
        if (np.isSong) {
            val found = com.dashmate.dashmate.deck.radio.RadioArt.cachedCover(np.artist, np.title)
            if (found == null) {
                com.dashmate.dashmate.deck.radio.RadioArt.lookUp(np.artist, np.title) {
                    mainHandler.post {
                        val url = com.dashmate.dashmate.deck.radio.RadioArt.cachedCover(np.artist, np.title).orEmpty()
                        // Still the same radio song on screen? Then swap the badge for the cover.
                        if (url.isNotBlank() && DashMateStateBridge.songApp == RADIO_APP_NAME &&
                            DashMateStateBridge.songTitle == np.title && DashMateStateBridge.songArtist == np.artist) {
                            DashMateStateBridge.songCoverUrl = url
                            DashMateStateBridge.notifyStateChanged(applicationContext)
                        }
                    }
                }
            } else if (found.isNotBlank()) {
                cover = found
            }
        }
        DashMateStateBridge.updateMediaInfo(
            applicationContext,
            np.title,
            np.artist,
            playing,
            coverUrl = cover,
            app = RADIO_APP_NAME,
            durationMs = 0L,
            // From the radio player's own clock when the song started while listening (exact, pauses
            // with the radio); -1 = unknown (tuned in mid-song): keep the clock, lyrics show unsynced.
            positionMs = p?.songPositionMs() ?: -1L,
            fetchLyrics = np.isSong,
            syncKnown = p?.songStartKnown == true,
        )
    }

    /** Leave radio mode and fall back to the lyrics / prayer / football card. */
    private fun exitRadioMode() {
        mainHandler.removeCallbacks(radioLongPauseRunnable)
        if (!radioMode && radioPlayer == null) return
        // Now Playing: the radio has stopped (only if it is still the radio being shown).
        if (DashMateStateBridge.songApp == RADIO_APP_NAME) pushRadioToNowPlaying(playingOverride = false)
        radioMode = false
        radioPlayer?.release()
        radioPlayer = null
        mediaSession.setQueue(null)
        mediaSession.setQueueTitle(null)
        updateSession()
    }

    /**
     * The service is normally started by MainActivity/Presentation, but Android Auto may only
     * be bound to it. Make sure it's a started service so it survives an unbind while radio
     * plays (startForeground has already been called in renderRadioSession, so this is allowed
     * from the background).
     */
    private fun ensureStartedForRadio() {
        try {
            startService(Intent(this, DashMateMediaCardService::class.java))
        } catch (e: Exception) {
            Log.w(TAG, "ensureStartedForRadio: ${e.message}")
        }
    }

    private fun scheduleLongPauseCheck() {
        mainHandler.removeCallbacks(radioLongPauseRunnable)
        val p = radioPlayer
        if (radioMode && (p == null || !p.wantsToPlay)) {
            val delay = if (p?.status == RadioPlayer.Status.ERROR) RADIO_ERROR_TIMEOUT_MS else RADIO_LONG_PAUSE_MS
            mainHandler.postDelayed(radioLongPauseRunnable, delay)
        }
    }

    private fun renderRadioSession() {
        val p = radioPlayer ?: return
        val station = p.station ?: lastRadioStation ?: return

        val state = when (p.status) {
            RadioPlayer.Status.PLAYING -> PlaybackStateCompat.STATE_PLAYING
            RadioPlayer.Status.BUFFERING -> PlaybackStateCompat.STATE_BUFFERING
            RadioPlayer.Status.RECONNECTING -> PlaybackStateCompat.STATE_CONNECTING
            RadioPlayer.Status.ERROR -> PlaybackStateCompat.STATE_ERROR
            RadioPlayer.Status.PAUSED -> PlaybackStateCompat.STATE_PAUSED
            RadioPlayer.Status.IDLE -> PlaybackStateCompat.STATE_STOPPED
        }
        val stateBuilder = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                    PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_PLAY_PAUSE or
                    PlaybackStateCompat.ACTION_STOP or
                    PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                    PlaybackStateCompat.ACTION_SKIP_TO_QUEUE_ITEM or
                    PlaybackStateCompat.ACTION_PLAY_FROM_MEDIA_ID or
                    PlaybackStateCompat.ACTION_PLAY_FROM_SEARCH
            )
            .setState(state, PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN, if (state == PlaybackStateCompat.STATE_PLAYING) 1f else 0f, SystemClock.elapsedRealtime())
            .setActiveQueueItemId(RadioStations.indexOf(station).toLong())
        if (state == PlaybackStateCompat.STATE_ERROR) {
            stateBuilder.setErrorMessage(PlaybackStateCompat.ERROR_CODE_APP_ERROR, p.errorMessage ?: "Station unavailable")
        }
        mediaSession.setPlaybackState(stateBuilder.build())

        val artist = when (p.status) {
            RadioPlayer.Status.BUFFERING -> "Tuning in…"
            RadioPlayer.Status.RECONNECTING -> "Reconnecting…"
            RadioPlayer.Status.ERROR -> p.errorMessage ?: "Station unavailable"
            else -> p.nowPlaying ?: station.subtitle
        }
        val iconUri = launcherIconUri().toString()
        val meta = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, station.mediaId)
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, station.name)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_TITLE, station.name)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, artist)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, station.subtitle)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_DESCRIPTION, station.subtitle)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM_ART_URI, iconUri)
            .putString(MediaMetadataCompat.METADATA_KEY_ART_URI, iconUri)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_ICON_URI, iconUri)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, -1L)
            .build()
        mediaSession.setMetadata(meta)

        refreshForeground()
    }

    /** Briefly show an error on the card (e.g. voice search found nothing), then restore it. */
    private fun showTransientError(message: String) {
        if (radioMode) {
            // Keep whatever station is playing; nothing else to do.
            Log.d(TAG, message)
            return
        }
        val st = PlaybackStateCompat.Builder()
            .setActions(PlaybackStateCompat.ACTION_PLAY_FROM_SEARCH or PlaybackStateCompat.ACTION_PLAY_FROM_MEDIA_ID)
            .setState(PlaybackStateCompat.STATE_ERROR, 0L, 0f)
            .setErrorMessage(PlaybackStateCompat.ERROR_CODE_NOT_SUPPORTED, message)
            .build()
        mediaSession.setPlaybackState(st)
        mainHandler.removeCallbacks(transientErrorClear)
        mainHandler.postDelayed(transientErrorClear, 4_000L)
    }

    override fun onStateUpdated(stateJson: String) {
        updateSession()
    }

    override fun onSwitchPage(page: String) {}

    override fun onExecuteScript(script: String) {}

    fun updateSession() {
        if (radioMode) {
            // Radio owns the session; ignore card updates from the state bridge.
            mainHandler.removeCallbacks(lyricTicker)
            renderRadioSession()
            return
        }
        val prefs = getSharedPreferences("dd_car_browser", MODE_PRIVATE)
        val showCard = prefs.getBoolean("car_card_show", true)
        @Suppress("UNUSED_VARIABLE")
        val cardMode = prefs.getString("car_card_mode", "Auto") ?: "Auto"

        if (!showCard) {
            mediaSession.isActive = false
            mainHandler.removeCallbacks(lyricTicker)
            return
        }
        mediaSession.isActive = true

        val isPlaying = DashMateStateBridge.isPlaying
        @Suppress("UNUSED_VARIABLE")
        val durationMs = DashMateStateBridge.playbackDurationMs
        val curPos = DashMateStateBridge.getCurrentPositionMs()
        val speed = DashMateStateBridge.playbackSpeed
        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED

        val stateBuilder = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_PLAY or
                    PlaybackStateCompat.ACTION_REWIND or
                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                    PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                    PlaybackStateCompat.ACTION_FAST_FORWARD or
                    PlaybackStateCompat.ACTION_SEEK_TO or
                    PlaybackStateCompat.ACTION_PLAY_PAUSE or // = 894L
                    PlaybackStateCompat.ACTION_PLAY_FROM_MEDIA_ID or
                    PlaybackStateCompat.ACTION_PLAY_FROM_SEARCH
            )
            .setState(state, curPos, speed, SystemClock.elapsedRealtime())
        stateBuilder.addCustomAction("ACTION_REWIND_10", "-10s", R.drawable.dd_ic_back)
        stateBuilder.addCustomAction("ACTION_FAST_FORWARD_10", "+10s", R.drawable.dd_ic_chevron)
        mediaSession.setPlaybackState(stateBuilder.build())

        updateMetadataOnly()

        refreshForeground()

        mainHandler.removeCallbacks(lyricTicker)
        if (isPlaying) {
            mainHandler.postDelayed(lyricTicker, 350L)
        }
    }

    private fun updateMetadataOnly() {
        val prefs = getSharedPreferences("dd_car_browser", MODE_PRIVATE)
        val cardMode = prefs.getString("car_card_mode", "Auto") ?: "Auto"

        var title = DashMateStateBridge.songTitle
        var subtitle = getActiveLyricLine()
        var album = DashMateStateBridge.songArtist
        var artUri: Uri? = DashMateStateBridge.currentArtUri
        var artBitmap: Bitmap? = DashMateStateBridge.currentArtBitmap

        val nothingPlaying = !DashMateStateBridge.isPlaying && (title.isBlank() || title == "Not Playing")
        if (cardMode.equals("Next prayer", ignoreCase = true) ||
            (cardMode.equals("Auto", ignoreCase = true) && nothingPlaying)
        ) {
            title = "Next Prayer"
            subtitle = "${DashMateStateBridge.nextPrayerName} ${DashMateStateBridge.nextPrayerTime} (in ${DashMateStateBridge.prayerCountdown})"
            album = "DashMate Prayer Times"
            artUri = CarArtProvider.getArtUri("card_prayer.png")
            artBitmap = loadCachedBitmap("card_prayer.png")
        } else if (cardMode.equals("Football", ignoreCase = true)) {
            title = "Football Live"
            subtitle = "Live Scores & Upcoming Fixtures"
            album = "DashMate Sports"
            artUri = CarArtProvider.getArtUri("card_football.png")
            artBitmap = loadCachedBitmap("card_football.png")
        }

        val metaBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, subtitle)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, subtitle)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, album)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_DESCRIPTION, album)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, DashMateStateBridge.playbackDurationMs)
        if (artBitmap != null) {
            metaBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, artBitmap)
            metaBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ART, artBitmap)
        }
        if (artUri != null) {
            metaBuilder.putString(MediaMetadataCompat.METADATA_KEY_ALBUM_ART_URI, artUri.toString())
            metaBuilder.putString(MediaMetadataCompat.METADATA_KEY_ART_URI, artUri.toString())
        }
        mediaSession.setMetadata(metaBuilder.build())
    }

    private fun getActiveLyricLine(): String {
        val lyrics = DashMateStateBridge.currentLyrics
        if (lyrics.isEmpty()) {
            val artist = DashMateStateBridge.songArtist
            return if (artist.isNotBlank()) artist else "DashMate"
        }
        val curPos = DashMateStateBridge.getCurrentPositionMs()
        val activeLine = lyrics.lastOrNull { it.timeMs <= curPos }?.text
        return if (!activeLine.isNullOrBlank()) activeLine else DashMateStateBridge.songArtist
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(CHANNEL_ID, "DashMate Card Audio", NotificationManager.IMPORTANCE_LOW)
        channel.description = "Shows live song lyrics & car cards next to navigation"
        channel.setShowBadge(false)
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildForegroundNotification(): Notification {
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val radioStation = if (radioMode) (radioPlayer?.station ?: lastRadioStation) else null
        val title: String
        val subtitle: String
        val playing: Boolean
        if (radioStation != null) {
            title = radioStation.name
            subtitle = radioPlayer?.nowPlaying ?: radioStation.subtitle
            playing = radioPlayer?.wantsToPlay == true
        } else {
            val songTitle = DashMateStateBridge.songTitle
            title = if (songTitle.isNotBlank()) songTitle else "DashMate Card"
            subtitle = getActiveLyricLine()
            playing = DashMateStateBridge.isPlaying
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(playing)
            .setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(mediaSession.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )

        val prevPending = MediaButtonReceiver.buildMediaButtonPendingIntent(
            this, PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
        )
        builder.addAction(R.drawable.dd_ic_back, "Prev", prevPending)

        val playPauseAction = if (playing) PlaybackStateCompat.ACTION_PAUSE else PlaybackStateCompat.ACTION_PLAY
        val playPausePending = MediaButtonReceiver.buildMediaButtonPendingIntent(this, playPauseAction)
        builder.addAction(
            R.drawable.dd_ic_assistive,
            if (playing) "Pause" else "Play",
            playPausePending,
        )

        val nextPending = MediaButtonReceiver.buildMediaButtonPendingIntent(
            this, PlaybackStateCompat.ACTION_SKIP_TO_NEXT
        )
        builder.addAction(R.drawable.dd_ic_chevron, "Next", nextPending)

        if (radioStation == null) {
            DashMateStateBridge.currentArtBitmap?.let { builder.setLargeIcon(it) }
        }
        return builder.build()
    }

    private fun prepareDefaultCardArt() {
        try {
            val artDir = File(cacheDir, "car_art")
            if (!artDir.exists()) {
                artDir.mkdirs()
            }

            fun copyAsset(assetName: String, destFile: String) {
                val f = File(artDir, destFile)
                if (f.exists()) return
                val stream: InputStream = try {
                    assets.open("flutter_assets/assets/car/$assetName")
                } catch (e: Exception) {
                    assets.open("assets/car/$assetName")
                }
                FileOutputStream(f).use { out -> stream.copyTo(out) }
            }

            copyAsset("card_prayer.png", "card_prayer.png")
            copyAsset("card_football.png", "card_football.png")
        } catch (e: Exception) {
            Log.w(TAG, "Failed preparing default card art: ${e.message}")
        }
    }

    private fun loadCachedBitmap(filename: String): Bitmap? {
        return try {
            val f = File(File(cacheDir, "car_art"), filename)
            if (f.exists()) BitmapFactory.decodeFile(f.absolutePath) else null
        } catch (e: Exception) {
            null
        }
    }
}
