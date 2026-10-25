package com.dashmate.dashmate.deck.radio

/**
 * What Now Playing shows while DashMate's own radio plays.
 *
 * Stations send the song as stream text, usually "Artist - Title". When they do, Now Playing shows
 * the song and lyrics are looked up; otherwise it shows the station and no lyrics are searched
 * (a station name would only find wrong lyrics).
 */
data class RadioNowPlaying(val title: String, val artist: String, val isSong: Boolean) {
    companion object {
        /** [streamText]: the station's "now playing" text (may be null); [stationName] / [stationLine]: fallback. */
        fun from(streamText: String?, stationName: String, stationLine: String): RadioNowPlaying {
            val text = streamText?.trim().orEmpty()
            if (text.isEmpty() || text.equals(stationName, ignoreCase = true)) {
                return RadioNowPlaying(stationName, stationLine, isSong = false)
            }
            // "Artist - Title" (also with an en/em dash). Split on the first separator only.
            val m = Regex("""\s+[-–—]\s+""").find(text)
            if (m != null) {
                val artist = text.substring(0, m.range.first).trim()
                val title = text.substring(m.range.last + 1).trim()
                // "HOT-FM - Masih Nombor 1": the station's own name plus a slogan, not a song.
                val station = letters(stationName)
                val isStationText = letters(artist) == station || letters(title) == station
                if (artist.isNotEmpty() && title.isNotEmpty() && !isStationText) {
                    return RadioNowPlaying(title, artist, isSong = true)
                }
                if (isStationText) {
                    val other = if (letters(artist) == station) title else artist
                    return RadioNowPlaying(other.ifEmpty { stationName }, stationLine, isSong = false)
                }
            }
            // Only a title (or a jingle / programme name): show it, but don't guess lyrics.
            return RadioNowPlaying(text, stationLine, isSong = false)
        }

        /** "HOT-FM", "Hot FM" and "hot fm" all become "hotfm". */
        private fun letters(s: String) = s.lowercase().filter { it.isLetterOrDigit() }
    }
}
