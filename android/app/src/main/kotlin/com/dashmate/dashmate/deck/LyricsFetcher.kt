package com.dashmate.dashmate.deck

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap

object LyricsFetcher {
    private const val TAG = "LyricsFetcher"
    private const val LRCLIB_GET = "https://lrclib.net/api/get"
    private const val LRCLIB_SEARCH = "https://lrclib.net/api/search"
    private const val LYRICS_OVH_BASE = "https://api.lyrics.ovh/v1"
    private const val PREFS_NAME = "DashMateLyricsCache"
    private const val USER_AGENT = "DashMate-AndroidAuto/1.0"

    private val memoryCache = ConcurrentHashMap<String, List<LyricLine>>()

    // RECONSTRUCTED: body rebuilt from --show-bad-code output of LyricsFetcher$fetchLyrics$2.
    suspend fun fetchLyrics(
        artist: String,
        track: String,
        context: Context? = null,
    ): List<LyricLine> = withContext(Dispatchers.IO) {
        if (track.isBlank() || track == "Not Playing") {
            return@withContext emptyList()
        }

        val cleanTrack = cleanTitle(track)
        val cleanArtist = cleanArtist(artist)
        val cacheKey = cleanArtist.lowercase(Locale.ROOT) + "_" + cleanTrack.lowercase(Locale.ROOT)

        memoryCache[cacheKey]?.let { return@withContext it }

        if (context != null) {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val cachedJson = prefs.getString(cacheKey, null)
                if (!cachedJson.isNullOrBlank()) {
                    val arr = JSONArray(cachedJson)
                    val list = ArrayList<LyricLine>()
                    for (i in 0 until arr.length()) {
                        val obj = arr.getJSONObject(i)
                        list.add(LyricLine(obj.getLong("time"), obj.getString("text")))
                    }
                    // Older builds cached the word "null" as a lyric (see text()); ignore that cache.
                    if (list.isNotEmpty() && list.any { !isNullWord(it.text) }) {
                        memoryCache[cacheKey] = list
                        return@withContext list
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed reading lyrics cache: " + e.message)
            }
        }

        var result = fetchFromLrclib(cleanArtist, cleanTrack)
        if (result.isEmpty()) {
            result = searchFromLrclib("$cleanArtist $cleanTrack")
        }
        if (result.isEmpty()) {
            result = fetchFromLyricsOvh(cleanArtist, cleanTrack)
        }

        if (result.isNotEmpty()) {
            memoryCache[cacheKey] = result
            if (context != null) {
                try {
                    val arr = JSONArray()
                    for (line in result) {
                        arr.put(JSONObject().apply {
                            put("time", line.timeMs)
                            put("text", line.text)
                        })
                    }
                    context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        .edit().putString(cacheKey, arr.toString()).apply()
                } catch (ignored: Exception) {
                }
            }
        }
        result
    }

    private fun openGet(urlStr: String): HttpURLConnection {
        val conn = URL(urlStr).openConnection() as HttpURLConnection
        conn.requestMethod = "GET"
        conn.connectTimeout = 4000
        conn.readTimeout = 4000
        conn.setRequestProperty("User-Agent", USER_AGENT)
        return conn
    }

    private fun plainToLines(plain: String): List<LyricLine> =
        plain.lines()
            .filter { it.isNotBlank() }
            .mapIndexed { i, line -> LyricLine((i * 3500).toLong(), line) }

    private fun fetchFromLrclib(artist: String, track: String): List<LyricLine> {
        try {
            val urlStr = "$LRCLIB_GET?artist_name=" + URLEncoder.encode(artist, "UTF-8") +
                "&track_name=" + URLEncoder.encode(track, "UTF-8")
            val conn = openGet(urlStr)
            if (conn.responseCode == 200) {
                val response = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                val json = JSONObject(response)
                val syncedLyrics = json.text("syncedLyrics")
                if (syncedLyrics.isNotBlank()) {
                    return parseLrc(syncedLyrics)
                }
                val plainLyrics = json.text("plainLyrics")
                if (plainLyrics.isNotBlank()) {
                    return plainToLines(plainLyrics)
                }
            }
        } catch (e: Throwable) {
            Log.d(TAG, "LRCLIB get error: " + e.message)
        }
        return emptyList()
    }

    private fun searchFromLrclib(query: String): List<LyricLine> {
        try {
            val urlStr = "$LRCLIB_SEARCH?q=" + URLEncoder.encode(query, "UTF-8")
            val conn = openGet(urlStr)
            if (conn.responseCode == 200) {
                val response = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                val array = JSONArray(response)
                if (array.length() > 0) {
                    val first = array.getJSONObject(0)
                    val synced = first.text("syncedLyrics")
                    if (synced.isNotBlank()) {
                        return parseLrc(synced)
                    }
                    val plain = first.text("plainLyrics")
                    if (plain.isNotBlank()) {
                        return plainToLines(plain)
                    }
                }
            }
        } catch (e: Throwable) {
            Log.d(TAG, "LRCLIB search error: " + e.message)
        }
        return emptyList()
    }

    // RECONSTRUCTED: jadx failed on this method; rebuilt from --show-bad-code output.
    private fun fetchFromLyricsOvh(artist: String, track: String): List<LyricLine> {
        try {
            val encArtist = URLEncoder.encode(artist, "UTF-8").replace("+", "%20")
            val encTrack = URLEncoder.encode(track, "UTF-8").replace("+", "%20")
            val urlStr = "$LYRICS_OVH_BASE/$encArtist/$encTrack"
            val conn = openGet(urlStr)
            if (conn.responseCode == 200) {
                val response = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                val json = JSONObject(response)
                val lyrics = json.text("lyrics")
                if (lyrics.isNotBlank()) {
                    Log.d(TAG, "Fetched fallback lyrics from Lyrics.ovh for $artist - $track")
                    return lyrics.lines()
                        .filter { it.isNotBlank() && !it.startsWith("Paroles de la chanson") }
                        .mapIndexed { i, line -> LyricLine((i * 3500).toLong(), line.trim()) }
                }
            }
        } catch (e: Throwable) {
            Log.d(TAG, "Lyrics.ovh fallback error: " + e.message)
        }
        return emptyList()
    }

    fun parseLrc(lrcText: String): List<LyricLine> {
        val lines = ArrayList<LyricLine>()
        val regex = Regex("\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\](.*)")
        for (rawLine in lrcText.lines()) {
            val match = regex.find(rawLine.trim())
            if (match != null) {
                val min = match.groupValues[1].toLongOrNull() ?: 0L
                val sec = match.groupValues[2].toLongOrNull() ?: 0L
                val fracStr = match.groupValues[3]
                val frac = fracStr.toLongOrNull() ?: 0L
                val ms = if (fracStr.length == 2) frac * 10 else frac
                val timeMs = min * 60 * 1000 + sec * 1000 + ms
                val text = match.groupValues[4].trim()
                if (text.isNotBlank()) {
                    lines.add(LyricLine(timeMs, text))
                }
            } else if (rawLine.isNotBlank() && !rawLine.startsWith("[")) {
                lines.add(LyricLine((lines.size * 3500).toLong(), rawLine.trim()))
            }
        }
        return lines.sortedBy { it.timeMs }
    }

    private fun cleanTitle(title: String): String =
        title
            .replace(Regex("^♪\\s*"), "")
            .replace(Regex("(?i)\\s*[·•-]\\s*finding\\s+lyrics.*"), "")
            .replace(Regex("(?i)\\s*[·•-]\\s*cached.*"), "")
            .replace(Regex("(?i)\\(official\\s+video\\)"), "")
            .replace(Regex("(?i)\\[official\\s+video\\]"), "")
            .replace(Regex("(?i)\\(music\\s+video\\)"), "")
            .replace(Regex("(?i)\\(lyric\\s+video\\)"), "")
            .replace(Regex("(?i)\\(audio\\)"), "")
            .replace(Regex("(?i)\\[.*?\\]"), "")
            .replace(Regex("(?i)ft\\..*"), "")
            .replace(Regex("(?i)feat\\..*"), "")
            .trim()

    private fun cleanArtist(artist: String): String =
        artist
            .replace(Regex("(?i)\\s*[·•-]\\s*finding\\s+lyrics.*"), "")
            .replace(Regex("(?i)\\s*[·•-]\\s*cached.*"), "")
            .replace(Regex("(?i)\\s*-\\s*topic"), "")
            .replace(Regex("(?i)vevo"), "")
            .trim()

    /** JSON null comes back from optString as the word "null": treat it (and blanks) as no lyrics. */
    private fun JSONObject.text(key: String): String =
        if (isNull(key)) "" else optString(key, "").let { if (isNullWord(it)) "" else it }

    private fun isNullWord(s: String) = s.trim().equals("null", ignoreCase = true)
}
