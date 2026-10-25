package com.dashmate.dashmate.deck.radio

import android.util.Base64
import android.util.Log
import com.dashmate.dashmate.deck.RadioStation
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Cover art while DashMate's radio plays: the song's album cover (iTunes search, free, no key)
 * when a song name is known and found, otherwise a badge with the station's name.
 */
object RadioArt {
    private const val TAG = "DashMateRadioArt"
    private val covers = ConcurrentHashMap<String, String>()   // "artist|title" -> url ("" = none)
    private val pending = ConcurrentHashMap.newKeySet<String>()
    private val pool = Executors.newSingleThreadExecutor()

    /** The cover already found for this song, "" if none was found, or null if not looked up yet. */
    fun cachedCover(artist: String, title: String): String? = covers[key(artist, title)]

    /** Looks the cover up in the background; [done] runs (off the main thread) when it is known. */
    fun lookUp(artist: String, title: String, done: () -> Unit) {
        val k = key(artist, title)
        if (covers.containsKey(k) || !pending.add(k)) return
        pool.execute {
            covers[k] = try { search(artist, title) } catch (e: Exception) {
                Log.w(TAG, "Cover lookup failed: ${e.message}"); ""
            }
            pending.remove(k)
            done()
        }
    }

    private fun key(artist: String, title: String) = "${artist.lowercase().trim()}|${title.lowercase().trim()}"

    private fun search(artist: String, title: String): String {
        val term = URLEncoder.encode("$artist $title", "UTF-8")
        val conn = URL("https://itunes.apple.com/search?term=$term&entity=song&limit=5&country=MY")
            .openConnection() as HttpURLConnection
        conn.connectTimeout = 6000
        conn.readTimeout = 6000
        val body = conn.inputStream.bufferedReader().use { it.readText() }
        val results = JSONObject(body).optJSONArray("results") ?: return ""
        val wantArtist = letters(artist)
        val wantTitle = letters(title)
        for (i in 0 until results.length()) {
            val r = results.getJSONObject(i)
            val a = letters(r.optString("artistName"))
            val t = letters(r.optString("trackName"))
            // Same song only: artist and title must overlap (a wrong cover is worse than a badge).
            val artistOk = a.isNotEmpty() && (a.contains(wantArtist) || wantArtist.contains(a))
            val titleOk = t.isNotEmpty() && (t.contains(wantTitle) || wantTitle.contains(t))
            val art = r.optString("artworkUrl100")
            if (artistOk && titleOk && art.isNotBlank()) return art.replace("100x100bb", "600x600bb")
        }
        return ""
    }

    /** "GIVĒON" and "Giveon" both become "giveon" (accents dropped). */
    private fun letters(s: String) = java.text.Normalizer.normalize(s, java.text.Normalizer.Form.NFD)
        .replace(Regex("\\p{M}+"), "").lowercase().filter { it.isLetterOrDigit() }

    /** A square badge with the station's name in its network's colours, as a data: URL. */
    fun stationBadge(station: RadioStation): String {
        val (c1, c2) = when (station.network.lowercase()) {
            "rtm" -> "#1D4ED8" to "#0EA5E9"
            "astro" -> "#7C3AED" to "#DB2777"
            "media prima" -> "#DC2626" to "#F59E0B"
            "star media" -> "#EA580C" to "#FACC15"
            else -> "#0F766E" to "#14B8A6"
        }
        val name = esc(station.name)
        val sub = esc(listOf(station.network, station.band).filter { it.isNotBlank() }.joinToString(" · "))
        val size = if (station.name.length <= 6) 112 else if (station.name.length <= 10) 84 else 64
        val svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">""" +
            """<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="$c1"/>""" +
            """<stop offset="1" stop-color="$c2"/></linearGradient></defs>""" +
            """<rect width="400" height="400" fill="url(#g)"/>""" +
            """<circle cx="200" cy="200" r="150" fill="none" stroke="#fff" stroke-opacity=".18" stroke-width="10"/>""" +
            """<text x="200" y="215" text-anchor="middle" font-family="sans-serif" font-weight="800" font-size="$size" fill="#fff">$name</text>""" +
            """<text x="200" y="290" text-anchor="middle" font-family="sans-serif" font-weight="600" font-size="30" fill="#fff" fill-opacity=".85">$sub</text>""" +
            "</svg>"
        return "data:image/svg+xml;base64," + Base64.encodeToString(svg.toByteArray(), Base64.NO_WRAP)
    }

    private fun esc(s: String) = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
}
