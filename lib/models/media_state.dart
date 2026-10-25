class MediaState {
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int positionMs;
  final bool isPlaying;
  final String coverUrl;
  final String currentLyric;
  final String rawLrc;

  MediaState({
    this.title = '',
    this.artist = '',
    this.album = '',
    this.durationMs = 0,
    this.positionMs = 0,
    this.isPlaying = false,
    this.coverUrl = '',
    this.currentLyric = '',
    this.rawLrc = '',
  });

  factory MediaState.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return MediaState();
    return MediaState(
      title: map['title'] as String? ?? '',
      artist: map['artist'] as String? ?? '',
      album: map['album'] as String? ?? '',
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      positionMs: (map['positionMs'] as num?)?.toInt() ?? 0,
      isPlaying: map['playing'] as bool? ?? map['isPlaying'] as bool? ?? false,
      coverUrl: map['coverUrl'] as String? ?? '',
      currentLyric: map['currentLyric'] as String? ?? '',
      rawLrc: map['rawLrc'] as String? ?? '',
    );
  }
}
