package com.dashmate.dashmate.deck.radio

import android.util.Log
import java.net.HttpURLConnection
import java.net.URL

/**
 * Estimates when the current song started on a Revma station (Astro, Media Prima), for the song that
 * was already playing when the radio was tuned (the stream itself only says "now playing").
 *
 * Revma also offers each station as HLS: 10 s pieces, each tagged with the song name, and the
 * last ~2.5 minutes of pieces can still be fetched. Walking back from the newest piece to the first
 * one with the current song name gives the song's start to within ~5 s. Songs that started earlier
 * than that history can't be placed (returns null).
 */
object RadioSongStart {
    private const val TAG = "DashMateSongStart"
    private const val SEGMENT_MS = 10_000L
    private const val MAX_BACK = 20

    /**
     * Wall-clock time (epoch ms, on the station's clock as heard live) when the song named [title]
     * started, or null when it can't be found. Blocking: call off the main thread.
     */
    fun estimate(streamUrl: String, title: String): Long? {
        val mount = Regex("""rcs\.revma\.com/([a-z0-9]+)""").find(streamUrl)?.groupValues?.get(1) ?: return null
        val want = letters(title)
        if (want.length < 2) return null
        return try {
            val master = get("https://stream.rcs.revma.com/$mount/hls.m3u8") ?: return null
            val media = master.lines().firstOrNull { it.isNotBlank() && !it.startsWith("#") }?.trim() ?: return null
            // 1. Walk back right away (some stations keep only ~40 s) to the first piece of this song.
            val (top, base, seenAt) = newestPiece(media) ?: return null
            var firstOfSong = -1L
            for (back in 0..MAX_BACK) {
                val n = top - back
                val t = pieceTitle("$base/$n.aac")
                if (t == null) { Log.i(TAG, "\"$title\": started before the station's history (${back * 10}s)"); return null }
                Log.i(TAG, "piece $n: \"$t\" want=$want")
                if (matches(letters(t), want)) firstOfSong = n
                else if (firstOfSong >= 0) break
                else if (back > 2) { Log.i(TAG, "\"$title\": newest pieces are \"$t\""); return null }
            }
            if (firstOfSong < 0) return null
            // 2. Then time the playlist: wait for the next piece, so we know when the newest appeared.
            var newest = top
            var appearedAt = -1L
            val waitUntil = System.currentTimeMillis() + 12_000L
            while (System.currentTimeMillis() < waitUntil) {
                Thread.sleep(700L)
                val p = newestPiece(media) ?: continue
                if (p.first > top) { newest = p.first; appearedAt = p.third; break }
            }
            if (appearedAt < 0) appearedAt = seenAt - SEGMENT_MS / 2   // never saw it change: on average 5 s before we saw it
            val firstAppeared = appearedAt - (newest - firstOfSong) * SEGMENT_MS
            (firstAppeared + PIECE_TO_START_MS).also {
                Log.i(TAG, "\"$title\": first piece $firstOfSong (newest $newest), started ${(System.currentTimeMillis() - it) / 1000}s ago")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Estimate failed: ${e.message}")
            null
        }
    }

    /**
     * From "first piece with the new name appeared in the playlist" to "the song started, as heard
     * live". Measured on Hitz, 26 Oct: Billie Eilish "Wildflower" changed name live 14.3 s before its
     * first piece appeared; the change can fall anywhere in the 10 s piece before, so ~15 s on average.
     */
    private const val PIECE_TO_START_MS = -15_000L

    private fun matches(have: String, want: String) = have.isNotEmpty() && (have == want || have.contains(want) || want.contains(have))

    /** Newest piece number, the pieces' base URL and when we saw it. */
    private fun newestPiece(media: String): Triple<Long, String, Long>? {
        val pl = get(media) ?: return null
        val now = System.currentTimeMillis()
        val url = pl.lines().lastOrNull { it.trim().endsWith(".aac") }?.trim() ?: return null
        val m = Regex("""^(.*)/(\d+)\.aac$""").find(url) ?: return null
        return Triple(m.groupValues[2].toLong(), m.groupValues[1], now)
    }

    /** The song name in a piece's ID3 tag (first ~600 bytes), or null if the piece is gone. */
    private fun pieceTitle(url: String): String? {
        val c = URL(url).openConnection() as HttpURLConnection
        c.connectTimeout = 6000; c.readTimeout = 6000
        c.setRequestProperty("Range", "bytes=0-599")
        c.setRequestProperty("User-Agent", "DashMate/1.0 (Android; Radio)")
        if (c.responseCode !in 200..299) { c.disconnect(); return null }
        val b = c.inputStream.use { ins ->
            val buf = java.io.ByteArrayOutputStream(); val tmp = ByteArray(600); var left = 600
            while (left > 0) { val r = ins.read(tmp, 0, left); if (r <= 0) break; buf.write(tmp, 0, r); left -= r }
            buf.toByteArray()
        }
        c.disconnect()
        val i = indexOf(b, "TIT2".toByteArray())
        if (i < 0 || i + 11 > b.size) return ""
        val size = ((b[i + 4].toInt() and 0xFF) shl 24) or ((b[i + 5].toInt() and 0xFF) shl 16) or
            ((b[i + 6].toInt() and 0xFF) shl 8) or (b[i + 7].toInt() and 0xFF)
        val start = i + 11                                               // header (10) + text encoding (1)
        val end = (start + size - 1).coerceAtMost(b.size)
        return if (end > start) String(b, start, end - start, Charsets.UTF_8).trim('\u0000', ' ') else ""
    }

    private fun indexOf(h: ByteArray, n: ByteArray): Int {
        outer@ for (i in 0..h.size - n.size) { for (j in n.indices) if (h[i + j] != n[j]) continue@outer; return i }
        return -1
    }

    private fun get(url: String): String? {
        val c = URL(url).openConnection() as HttpURLConnection
        c.connectTimeout = 6000; c.readTimeout = 6000
        c.setRequestProperty("User-Agent", "DashMate/1.0 (Android; Radio)")
        return try { if (c.responseCode in 200..299) c.inputStream.bufferedReader().use { it.readText() } else null } finally { c.disconnect() }
    }

    private fun letters(s: String) = java.text.Normalizer.normalize(s, java.text.Normalizer.Form.NFD)
        .replace(Regex("\\p{M}+"), "").lowercase().filter { it.isLetterOrDigit() }
}
