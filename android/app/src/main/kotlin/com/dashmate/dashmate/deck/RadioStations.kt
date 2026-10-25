package com.dashmate.dashmate.deck

import java.util.Locale

/**
 * A built-in Malaysian radio station that DashMate Card can play in Android Auto.
 *
 * @param id       stable id (used in media ids "radio:<id>" - don't rename once shipped)
 * @param name     display title, e.g. "Nasional FM"
 * @param network  broadcaster, e.g. "RTM", "Astro", "Media Prima"
 * @param band     optional frequency/tagline shown after the network ("88.5", "Klang Valley")
 * @param url      stream URL (mp3 / aac / HLS .m3u8, redirects are followed). Prefer https:
 *                 the app targets SDK 35 and has no cleartext-traffic exception.
 * @param keywords extra words for voice search ("play <keyword> on DashMate")
 */
data class RadioStation(
    val id: String,
    val name: String,
    val network: String,
    val band: String = "",
    val url: String,
    val keywords: List<String> = emptyList(),
) {
    /** Subtitle shown in the browse list and as the fallback "artist" line, e.g. "RTM · Nasional FM 92.3". */
    val subtitle: String
        get() = if (band.isBlank()) "$network · $name" else "$network · $name $band"

    val mediaId: String get() = RadioStations.MEDIA_ID_PREFIX + id
}

/**
 * Curated station list - EDIT STATIONS HERE.
 *
 * URLs sourced from radio-browser.info (Oct 2026) and checked with curl to return audio/aac,
 * audio/mpeg or HLS. Revma (Astro / Media Prima) HLS playlist links carry short-lived tokens,
 * so the stable direct mount "https://stream.rcs.revma.com/<mount>" is used instead.
 * StreamTheWorld "livestream-redirect" links are used over https (they redirect to an https
 * edge node).
 */
object RadioStations {
    const val MEDIA_ID_PREFIX = "radio:"

    val all: List<RadioStation> = listOf(
        // ---- RTM ----
        RadioStation(
            id = "nasional_fm", name = "Nasional FM", network = "RTM",
            url = "https://playerservices.streamtheworld.com/api/livestream-redirect/NASIONAL_FM.mp3",
            keywords = listOf("nasional", "national", "radio nasional", "rtm"),
        ),
        RadioStation(
            id = "ai_fm", name = "Ai FM", network = "RTM", band = "89.3",
            url = "https://playerservices.streamtheworld.com/api/livestream-redirect/AI_FMAAC_SC",
            keywords = listOf("ai", "ai fm", "a i fm", "chinese"),
        ),
        RadioStation(
            id = "traxx_fm", name = "TraXX FM", network = "RTM", band = "90.3",
            url = "https://playerservices.streamtheworld.com/api/livestream-redirect/TRAXX_FMAAC_SC",
            keywords = listOf("traxx", "tracks", "trax", "traxx fm"),
        ),
        RadioStation(
            id = "klasik_fm", name = "Klasik FM", network = "RTM",
            url = "https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO_KLASIK.mp3",
            keywords = listOf("klasik", "classic", "radio klasik"),
        ),
        RadioStation(
            id = "asyik_fm", name = "Asyik FM", network = "RTM",
            url = "https://playerservices.streamtheworld.com/api/livestream-redirect/ASYIK_FM.mp3",
            keywords = listOf("asyik", "asik"),
        ),
        // ---- Astro Radio ----
        RadioStation(
            id = "era_fm", name = "ERA FM", network = "Astro", band = "103.3",
            url = "https://stream.rcs.revma.com/crec9cmbv4uvv",
            keywords = listOf("era", "era fm"),
        ),
        RadioStation(
            id = "sinar_fm", name = "Sinar FM", network = "Astro", band = "96.7",
            url = "https://stream.rcs.revma.com/azatk0tbv4uvv",
            keywords = listOf("sinar"),
        ),
        RadioStation(
            id = "hitz", name = "Hitz", network = "Astro", band = "92.9",
            url = "https://stream.rcs.revma.com/488kt4sbv4uvv",
            keywords = listOf("hitz", "hits", "hitz fm", "hits fm"),
        ),
        RadioStation(
            id = "lite_fm", name = "Lite FM", network = "Astro", band = "105.7",
            url = "https://stream.rcs.revma.com/bn4ex8sbv4uvv",
            keywords = listOf("lite", "light", "light fm"),
        ),
        RadioStation(
            id = "melody_fm", name = "Melody FM", network = "Astro", band = "97.3",
            url = "https://stream.rcs.revma.com/2u1n6dtbv4uvv",
            keywords = listOf("melody", "melodi"),
        ),
        RadioStation(
            id = "raaga", name = "Raaga", network = "Astro", band = "99.3",
            url = "https://stream.rcs.revma.com/1ut6qwtbv4uvv",
            keywords = listOf("raaga", "raga", "tamil"),
        ),
        RadioStation(
            id = "zayan", name = "Zayan", network = "Astro",
            url = "https://stream.rcs.revma.com/7ww2a4tbv4uvv",
            keywords = listOf("zayan", "zayan fm", "islamic"),
        ),
        RadioStation(
            id = "gegar", name = "Gegar", network = "Astro",
            url = "https://stream.rcs.revma.com/cn0zcqsbv4uvv",
            keywords = listOf("gegar", "gegar fm", "pantai timur"),
        ),
        // ---- Media Prima ----
        RadioStation(
            id = "hot_fm", name = "Hot FM", network = "Media Prima", band = "97.6",
            url = "https://stream.rcs.revma.com/drakdf8mtd3vv",
            keywords = listOf("hot", "hot fm"),
        ),
        RadioStation(
            id = "fly_fm", name = "Fly FM", network = "Media Prima", band = "95.8",
            url = "https://stream.rcs.revma.com/q17aka9mtd3vv",
            keywords = listOf("fly", "fly fm", "flight"),
        ),
        // ---- Star Media ----
        RadioStation(
            id = "988_fm", name = "988 FM", network = "Star Media", band = "98.8",
            url = "https://28103.live.streamtheworld.com/988_FMAAC.aac",
            keywords = listOf("988", "nine eight eight", "nine double eight", "98.8"),
        ),
    )

    fun byId(id: String): RadioStation? = all.firstOrNull { it.id == id }

    fun byMediaId(mediaId: String?): RadioStation? {
        if (mediaId == null || !mediaId.startsWith(MEDIA_ID_PREFIX)) return null
        return byId(mediaId.removePrefix(MEDIA_ID_PREFIX))
    }

    fun indexOf(station: RadioStation?): Int = if (station == null) -1 else all.indexOfFirst { it.id == station.id }

    fun next(current: RadioStation?): RadioStation {
        val i = indexOf(current)
        return all[if (i < 0) 0 else (i + 1) % all.size]
    }

    fun previous(current: RadioStation?): RadioStation {
        val i = indexOf(current)
        return all[if (i <= 0) all.size - 1 else i - 1]
    }

    // ------------------------------------------------------------------ fuzzy search

    private val fillerWords = setOf(
        "play", "putar", "pasang", "on", "in", "dashmate", "dash", "mate", "deck", "the",
        "radio", "station", "stesen", "channel", "fm", "please", "app",
    )

    private fun normalize(s: String): String =
        s.lowercase(Locale.ROOT)
            .replace(Regex("[^a-z0-9. ]"), " ")
            .split(Regex("\\s+"))
            .filter { it.isNotBlank() && it !in fillerWords }
            .joinToString(" ")
            .trim()

    /** Best match for a free-form voice/search query, or null if nothing is close enough. */
    fun findBest(query: String?): RadioStation? = search(query).firstOrNull()

    /** Stations matching [query], best first. */
    fun search(query: String?): List<RadioStation> {
        val q = normalize(query ?: "")
        if (q.isEmpty()) return emptyList()
        val qCompact = q.replace(" ", "")
        return all.map { st -> st to score(st, q, qCompact) }
            .filter { it.second >= 55 }
            .sortedByDescending { it.second }
            .map { it.first }
    }

    private fun score(st: RadioStation, q: String, qCompact: String): Int {
        val candidates = (listOf(st.name, st.id.replace('_', ' ')) + st.keywords)
            .map { normalize(it) }
            .filter { it.isNotEmpty() }
            .distinct()
        var best = 0
        for (c in candidates) {
            val cCompact = c.replace(" ", "")
            val s = when {
                cCompact == qCompact -> 100
                qCompact.length >= 3 && cCompact.startsWith(qCompact) -> 85
                cCompact.length >= 3 && qCompact.contains(cCompact) -> 80
                qCompact.length >= 3 && cCompact.contains(qCompact) -> 70
                else -> (similarity(cCompact, qCompact) * 100).toInt()
            }
            if (s > best) best = s
        }
        return best
    }

    private fun similarity(a: String, b: String): Double {
        if (a.isEmpty() || b.isEmpty()) return 0.0
        val d = levenshtein(a, b)
        return 1.0 - d.toDouble() / maxOf(a.length, b.length)
    }

    private fun levenshtein(a: String, b: String): Int {
        var prev = IntArray(b.length + 1) { it }
        var cur = IntArray(b.length + 1)
        for (i in 1..a.length) {
            cur[0] = i
            for (j in 1..b.length) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                cur[j] = minOf(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            val t = prev; prev = cur; cur = t
        }
        return prev[b.length]
    }
}
