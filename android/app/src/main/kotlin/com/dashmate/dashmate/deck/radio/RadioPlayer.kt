package com.dashmate.dashmate.deck.radio

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Metadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.extractor.metadata.icy.IcyInfo
import androidx.media3.extractor.metadata.id3.TextInformationFrame
import com.dashmate.dashmate.deck.RadioStation

/**
 * Thin ExoPlayer wrapper for live radio streams (mp3 / aac / HLS).
 *
 * - Audio focus is handled by ExoPlayer (USAGE_MEDIA / CONTENT_TYPE_MUSIC): it ducks for
 *   navigation prompts, pauses on transient loss and resumes afterwards.
 * - Network errors (tunnels!) are retried with backoff before surfacing [Status.ERROR].
 * - Must be used from the main thread.
 */
@OptIn(UnstableApi::class)
class RadioPlayer(private val context: Context, private val listener: Listener) {

    enum class Status { IDLE, BUFFERING, PLAYING, PAUSED, RECONNECTING, ERROR }

    interface Listener {
        /** Status, station or now-playing text changed. */
        fun onRadioStateChanged()

        /** Another app took audio focus permanently (e.g. user started Spotify). */
        fun onRadioFocusLostPermanently()
    }

    companion object {
        private const val TAG = "DashMateRadio"
        private val RETRY_DELAYS_MS = longArrayOf(2_000L, 5_000L, 10_000L)
        private const val USER_AGENT = "DashMate/1.0 (Android; Radio)"
        private const val NAME_LAG_MS = 800L
    }

    private val handler = Handler(Looper.getMainLooper())
    private var player: ExoPlayer? = null
    private var retryCount = 0
    private var reconnecting = false

    var station: RadioStation? = null
        private set
    /** ICY / ID3 "now playing" text, if the stream provides it. */
    /**
     * True when the current song started while we were listening (its name changed in the stream,
     * which the player reports in step with the audio). False for the song that was already playing
     * when the station was tuned: we don't know how far into it we are, so its lyrics can't be timed.
     */
    var songStartKnown: Boolean = false
        private set
    private var tunedAtMs = 0L
    /** Player position (ms) where the current song started, or -1 when unknown. */
    private var songStartPosMs = -1L

    /**
     * How far into the current song we are, from the player's own clock (stops while paused or
     * buffering), or -1 when unknown. Measured on Hitz: the song name changes in the stream about
     * 0.8 s after the new song begins, hence [NAME_LAG_MS].
     */
    fun songPositionMs(): Long {
        val p = player ?: return -1L
        if (!songStartKnown || songStartPosMs < 0) return -1L
        return (p.currentPosition - songStartPosMs).coerceAtLeast(0L)
    }
    var nowPlaying: String? = null
        private set
    var errorMessage: String? = null
        private set
    var status: Status = Status.IDLE
        private set

    val isPlaying: Boolean get() = status == Status.PLAYING
    /** True when the user wants audio (playing, buffering or reconnecting). */
    val wantsToPlay: Boolean get() = player?.playWhenReady == true && status != Status.ERROR

    private val retryRunnable = Runnable {
        val p = player ?: return@Runnable
        Log.d(TAG, "Retrying ${station?.name} (attempt $retryCount)")
        p.prepare()
        p.playWhenReady = true
    }

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            if (playbackState == Player.STATE_READY) {
                retryCount = 0
                reconnecting = false
                errorMessage = null
            } else if (playbackState == Player.STATE_ENDED && player?.playWhenReady == true) {
                // A live stream should never end - treat it like a dropped connection.
                handleFailure("Stream ended")
                return
            }
            refresh()
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) = refresh()

        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
            refresh()
            if (!playWhenReady && reason == Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_FOCUS_LOSS) {
                listener.onRadioFocusLostPermanently()
            }
        }

        override fun onPlaybackSuppressionReasonChanged(playbackSuppressionReason: Int) = refresh()

        override fun onPlayerError(error: PlaybackException) {
            Log.w(TAG, "Player error on ${station?.name}: ${error.errorCodeName} ${error.message}")
            if (error.errorCode == PlaybackException.ERROR_CODE_BEHIND_LIVE_WINDOW) {
                player?.seekToDefaultPosition()
                player?.prepare()
                return
            }
            handleFailure(error.errorCodeName)
        }

        override fun onMetadata(metadata: Metadata) {
            var text: String? = null
            var id3Title: String? = null
            var id3Artist: String? = null
            for (i in 0 until metadata.length()) {
                when (val entry = metadata.get(i)) {
                    is IcyInfo -> entry.title?.takeIf { it.isNotBlank() }?.let { text = it.trim() }
                    is TextInformationFrame -> when (entry.id) {
                        "TIT2" -> id3Title = entry.values.firstOrNull()
                        "TPE1" -> id3Artist = entry.values.firstOrNull()
                    }
                }
            }
            if (text == null && !id3Title.isNullOrBlank()) {
                text = if (!id3Artist.isNullOrBlank()) "$id3Artist - $id3Title" else id3Title
            }
            val cleaned = text?.trim()?.trim('-')?.trim()
            if (!cleaned.isNullOrBlank() && cleaned != nowPlaying) {
                // The first name after tuning describes a song already under way.
                songStartKnown = nowPlaying != null && SystemClock.elapsedRealtime() - tunedAtMs > 8_000L
                // onMetadata fires when playback reaches the name change, so this is the song's start.
                songStartPosMs = if (songStartKnown) (player?.currentPosition ?: 0L) - NAME_LAG_MS else -1L
                nowPlaying = cleaned
                listener.onRadioStateChanged()
            }
        }
    }

    private fun ensurePlayer(): ExoPlayer {
        player?.let { return it }
        val http = DefaultHttpDataSource.Factory()
            .setUserAgent(USER_AGENT)
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(10_000)
            .setReadTimeoutMs(15_000)
        val mediaSourceFactory = DefaultMediaSourceFactory(DefaultDataSource.Factory(context, http))
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
            .build()
        return ExoPlayer.Builder(context)
            .setMediaSourceFactory(mediaSourceFactory)
            .setAudioAttributes(audioAttributes, /* handleAudioFocus = */ true)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()
            .also {
                it.addListener(playerListener)
                player = it
            }
    }

    fun play(newStation: RadioStation) {
        handler.removeCallbacks(retryRunnable)
        retryCount = 0
        reconnecting = false
        errorMessage = null
        nowPlaying = null
        songStartKnown = false
        songStartPosMs = -1L
        tunedAtMs = SystemClock.elapsedRealtime()
        station = newStation
        val p = ensurePlayer()
        val item = MediaItem.Builder()
            .setUri(newStation.url)
            .setMediaId(newStation.mediaId)
            .apply { if (newStation.url.contains(".m3u8")) setMimeType(MimeTypes.APPLICATION_M3U8) }
            .build()
        p.setMediaItem(item)
        p.prepare()
        p.playWhenReady = true
        refresh()
    }

    fun resume() {
        val p = player
        val st = station
        if (p == null || st == null) return
        if (status == Status.ERROR || p.playbackState == Player.STATE_IDLE || p.playbackState == Player.STATE_ENDED) {
            // Re-tune: live streams can't resume from a stale buffer.
            play(st)
            return
        }
        p.playWhenReady = true
        refresh()
    }

    fun pause() {
        handler.removeCallbacks(retryRunnable)
        if (reconnecting) {
            reconnecting = false
            retryCount = 0
        }
        player?.playWhenReady = false
        refresh()
    }

    /** Stop playback and drop the stream (player instance is kept for reuse). */
    fun stop() {
        handler.removeCallbacks(retryRunnable)
        retryCount = 0
        reconnecting = false
        errorMessage = null
        nowPlaying = null
        player?.stop()
        player?.clearMediaItems()
        player?.playWhenReady = false
        status = Status.IDLE
        listener.onRadioStateChanged()
    }

    fun release() {
        handler.removeCallbacks(retryRunnable)
        player?.removeListener(playerListener)
        player?.release()
        player = null
        station = null
        status = Status.IDLE
    }

    private fun handleFailure(reason: String) {
        handler.removeCallbacks(retryRunnable)
        if (retryCount < RETRY_DELAYS_MS.size && player?.playWhenReady != false) {
            val delay = RETRY_DELAYS_MS[retryCount]
            retryCount++
            reconnecting = true
            Log.d(TAG, "Will retry in ${delay}ms ($reason)")
            handler.postDelayed(retryRunnable, delay)
        } else {
            reconnecting = false
            errorMessage = "Station unavailable"
            player?.playWhenReady = false
        }
        refresh()
    }

    private fun refresh() {
        val p = player
        val newStatus = when {
            p == null || station == null -> Status.IDLE
            errorMessage != null -> Status.ERROR
            reconnecting -> Status.RECONNECTING
            p.isPlaying -> Status.PLAYING
            p.playWhenReady && p.playbackState == Player.STATE_BUFFERING -> Status.BUFFERING
            p.playWhenReady && p.playbackState == Player.STATE_IDLE -> Status.BUFFERING
            else -> Status.PAUSED
        }
        status = newStatus
        listener.onRadioStateChanged()
    }
}
