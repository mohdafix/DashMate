import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({super.key});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> with TickerProviderStateMixin {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');

  // Track state
  String _title = "Not Playing";
  String _artist = "Play something in YouTube Music or Spotify";
  String _appSource = "Media Player";
  String? _coverUrl;
  bool _isPlaying = false;
  int _positionMs = 0;
  int _durationMs = 240000;
  List<Map<String, dynamic>> _lyrics = [];
  bool _isLoadingLyrics = false;
  bool _showSearchBar = false;

  // Settings
  String _albumArtSize = "Medium"; // Small, Medium, Large, Off
  String _lyricsSource = "LRCLIB"; // LRCLIB, NetEase, lyrics.ovh
  bool _plainLyricsOnly = false;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _playbackTimer;
  int _activeLineIndex = 0;

  late AnimationController _eqController;

  @override
  void initState() {
    super.initState();
    _eqController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onStateUpdate' && call.arguments != null) {
        _parseStateJson(call.arguments.toString());
      }
    });

    _loadState();
    _startPlaybackProgress();
  }

  @override
  void dispose() {
    _eqController.dispose();
    _playbackTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _startPlaybackProgress() {
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_isPlaying || _lyrics.isEmpty) return;
      setState(() {
        _positionMs += 500;
        if (_positionMs > _durationMs) _positionMs = _durationMs;
        _updateActiveLine();
      });
    });
  }

  void _updateActiveLine() {
    if (_lyrics.isEmpty) return;
    int found = 0;
    for (int i = 0; i < _lyrics.length; i++) {
      final t = (_lyrics[i]['time'] as num).toInt();
      if (_positionMs >= t) {
        found = i;
      } else {
        break;
      }
    }
    if (_activeLineIndex != found) {
      setState(() => _activeLineIndex = found);
      _scrollToActiveLine();
    }
  }

  void _scrollToActiveLine() {
    if (!_scrollController.hasClients) return;
    const itemHeight = 52.0;
    final target = (_activeLineIndex * itemHeight) - 100.0;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadState() async {
    try {
      final String? stateJson = await _channel.invokeMethod<String>('getState');
      if (stateJson != null) {
        _parseStateJson(stateJson);
      }
    } catch (_) {}
  }

  void _parseStateJson(String stateJson) {
    try {
      final map = jsonDecode(stateJson);
      final music = map['music'];
      if (music != null) {
        final title = (music['title'] ?? '').toString().trim();
        final artist = (music['artist'] ?? '').toString().trim();
        final app = (music['app'] ?? '').toString().trim();
        final cover = (music['cover'] ?? music['art'] ?? '').toString().trim();
        final playing = music['playing'] == true || music['isPlaying'] == true;
        final pos = ((music['positionMs'] ?? 0) as num).toInt();
        final dur = ((music['durationMs'] ?? 0) as num).toInt();
        final lyricsList = music['lyrics'];

        if (title.isNotEmpty && title != "Not Playing") {
          final titleChanged = title != _title || artist != _artist;
          setState(() {
            _title = title;
            _artist = artist;
            _appSource = app.isNotEmpty ? app : 'Media Player';
            _coverUrl = cover.isNotEmpty ? cover : null;
            _isPlaying = playing;
            _positionMs = pos;
            if (dur > 0) _durationMs = dur;
            if (lyricsList is List && lyricsList.isNotEmpty) {
              _lyrics = lyricsList.map((e) => {
                'time': ((e['time'] ?? 0) as num).toInt(),
                'text': (e['text'] ?? '').toString(),
              }).toList();
            }
          });
          if (_lyrics.isEmpty && titleChanged) {
            _fetchLyricsLive(artist, title);
          }
          _updateActiveLine();
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchLyricsLive(String artist, String track) async {
    try {
      final res = await _channel.invokeMethod('fetchLyrics', {'artist': artist, 'track': track});
      if (res is List && res.isNotEmpty && mounted) {
        setState(() {
          _lyrics = List<Map<String, dynamic>>.from(
            res.map((e) => Map<String, dynamic>.from(e)),
          );
          _updateActiveLine();
        });
      }
    } catch (_) {}
  }

  Future<void> _searchLyrics(String artist, String track) async {
    HapticFeedback.lightImpact();
    setState(() => _isLoadingLyrics = true);
    try {
      final res = await _channel.invokeMethod('fetchLyrics', {'artist': artist, 'track': track});
      if (res is List && res.isNotEmpty) {
        setState(() {
          _title = track;
          _artist = artist;
          _lyrics = List<Map<String, dynamic>>.from(
            res.map((e) => Map<String, dynamic>.from(e)),
          );
          _positionMs = 0;
          _isLoadingLyrics = false;
          _updateActiveLine();
        });
      } else {
        setState(() => _isLoadingLyrics = false);
      }
    } catch (_) {
      setState(() => _isLoadingLyrics = false);
    }
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    setState(() => _isPlaying = !_isPlaying);
    _channel.invokeMethod('mediaPlayPause');
  }

  void _skipNext() {
    HapticFeedback.selectionClick();
    _channel.invokeMethod('mediaNext');
  }

  void _skipPrev() {
    HapticFeedback.selectionClick();
    _channel.invokeMethod('mediaPrevious');
  }

  void _pushLyricsToCar() {
    HapticFeedback.lightImpact();
    _channel.invokeMethod('setCarPage', {'page': 'lyrics'});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.directions_car, color: Color(0xFF14E0C1), size: 20),
            SizedBox(width: 10),
            Text('Projecting live lyrics to Android Auto screen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF101622),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF14E0C1), width: 1)),
      ),
    );
  }

  Widget _buildCoverImage() {
    if (_coverUrl != null && _coverUrl!.isNotEmpty) {
      if (_coverUrl!.startsWith('data:image/')) {
        try {
          final base64Str = _coverUrl!.contains(',') ? _coverUrl!.split(',').last : _coverUrl!;
          final bytes = base64Decode(base64Str);
          return Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {}
      } else if (_coverUrl!.startsWith('http://') || _coverUrl!.startsWith('https://')) {
        return Image.network(_coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultCoverIcon());
      }
    }
    return _defaultCoverIcon();
  }

  Widget _defaultCoverIcon() {
    return const Center(
      child: Icon(Icons.music_note_rounded, color: Color(0xFF0B0F1A), size: 36),
    );
  }

  String _formatTime(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final remS = s % 60;
    return '${m.toString().padLeft(2, '0')}:${remS.toString().padLeft(2, '0')}';
  }

  void _openSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101622),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Music & Lyrics Settings',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  const Text('Album Art Size', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Small', 'Medium', 'Large', 'Off'].map((s) {
                      final selected = _albumArtSize == s;
                      return ChoiceChip(
                        label: Text(s),
                        selected: selected,
                        selectedColor: const Color(0xFF14E0C1),
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        labelStyle: TextStyle(
                          color: selected ? Colors.black : Colors.white70,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) {
                          setModalState(() => _albumArtSize = s);
                          setState(() => _albumArtSize = s);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Default Lyrics Source', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['LRCLIB', 'NetEase Music', 'Lyrics.ovh'].map((src) {
                      final selected = _lyricsSource == src;
                      return ChoiceChip(
                        label: Text(src),
                        selected: selected,
                        selectedColor: const Color(0xFF14E0C1),
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        labelStyle: TextStyle(
                          color: selected ? Colors.black : Colors.white70,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) {
                          setModalState(() => _lyricsSource = src);
                          setState(() => _lyricsSource = src);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Plain Lyrics Only', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Read full lyrics without auto-karaoke scrolling', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: _plainLyricsOnly,
                    activeThumbColor: const Color(0xFF14E0C1),
                    onChanged: (val) {
                      setModalState(() => _plainLyricsOnly = val);
                      setState(() => _plainLyricsOnly = val);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Proportional album art sizes
    double artDimension = 110.0;
    if (_albumArtSize == "Small") artDimension = 74.0;
    if (_albumArtSize == "Large") artDimension = 145.0;
    final bool showCover = _albumArtSize != "Off";

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      body: Stack(
        children: [
          // 1. Subtle Radial Ambient Glow
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF14E0C1).withValues(alpha: 0.15),
                    const Color(0xFF0B9E8A).withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 2. Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Music Player',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF14E0C1),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'LRCLIB Synced Stage',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF14E0C1), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Search Lyrics',
                        icon: Icon(
                          _showSearchBar ? Icons.search_off_rounded : Icons.search_rounded,
                          color: _showSearchBar ? const Color(0xFF14E0C1) : Colors.white70,
                        ),
                        onPressed: () => setState(() => _showSearchBar = !_showSearchBar),
                      ),
                      IconButton(
                        tooltip: 'Project to Car Display',
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF14E0C1).withValues(alpha: 0.18),
                            border: Border.all(color: const Color(0xFF14E0C1).withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.directions_car_rounded, color: Color(0xFF14E0C1), size: 18),
                        ),
                        onPressed: _pushLyricsToCar,
                      ),
                      IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.tune_rounded, color: Colors.white70),
                        onPressed: _openSettingsDialog,
                      ),
                    ],
                  ),
                ),

                // Collapsible Search Header
                if (_showSearchBar)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161F2E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Artist - Track (e.g. Coldplay - Yellow)',
                              hintStyle: TextStyle(fontSize: 12, color: Colors.white38),
                              isDense: true,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final q = _searchController.text.trim();
                            if (q.contains('-')) {
                              final parts = q.split('-');
                              _searchLyrics(parts[0].trim(), parts[1].trim());
                            } else if (q.isNotEmpty) {
                              _searchLyrics(q, q);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14E0C1),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            elevation: 0,
                          ),
                          child: const Text('Fetch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                // 3. Top Hero Section: Album on top
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      // Square Album Cover with Neon Glow & Rounded Corners
                      if (showCover)
                        Container(
                          width: artDimension,
                          height: artDimension,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF14E0C1), Color(0xFF0B9E8A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.65),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: const Color(0xFF14E0C1).withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(19),
                            child: _buildCoverImage(),
                          ),
                        ),

                      if (showCover) const SizedBox(width: 16),

                      // Track Metadata & Chips
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _artist,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            // Status Chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                                  ),
                                  child: Text(
                                    _appSource,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF14E0C1), Color(0xFF0B9E8A)],
                                    ),
                                    borderRadius: BorderRadius.circular(99),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF14E0C1).withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    _isPlaying ? '▶ Playing' : '⏸ Paused',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0B0F1A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // 4. Middle Stage: Synced Lyrics with Gradient Fade Mask
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.14, 0.82, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: _isLoadingLyrics
                        ? _buildLoadingEqualizer()
                        : _lyrics.isEmpty
                            ? _buildWaitingView()
                            : _buildLyricsList(),
                  ),
                ),

                // 5. Bottom Section: Controls at the bottom
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0F1A),
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress Timeline
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: const Color(0xFF14E0C1),
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
                          thumbColor: const Color(0xFF14E0C1),
                          trackShape: const RoundedRectSliderTrackShape(),
                        ),
                        child: Slider(
                          value: _positionMs.clamp(0, _durationMs).toDouble(),
                          min: 0,
                          max: _durationMs.toDouble(),
                          onChanged: (val) {
                            setState(() {
                              _positionMs = val.toInt();
                              _updateActiveLine();
                            });
                          },
                        ),
                      ),

                      // Timestamps
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTime(_positionMs),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white60),
                            ),
                            Text(
                              _formatTime(_durationMs),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Media Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Previous Button (48x48 Circular Glass)
                          _buildGlassMediaButton(
                            icon: Icons.skip_previous_rounded,
                            size: 48,
                            iconSize: 26,
                            onTap: _skipPrev,
                          ),
                          const SizedBox(width: 24),

                          // Large Solid White Play/Pause Button (58x58 with Glow)
                          GestureDetector(
                            onTap: _togglePlayPause,
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: const Color(0xFF0B0F1A),
                                size: 34,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),

                          // Next Button (48x48 Circular Glass)
                          _buildGlassMediaButton(
                            icon: Icons.skip_next_rounded,
                            size: 48,
                            iconSize: 26,
                            onTap: _skipNext,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassMediaButton({
    required IconData icon,
    required double size,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.14),
              Colors.white.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }

  Widget _buildLyricsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      itemCount: _lyrics.length,
      itemBuilder: (context, index) {
        final line = _lyrics[index];
        final bool isNow = index == _activeLineIndex;
        final bool isPast = index < _activeLineIndex;
        final String text = (line['text'] as String?)?.trim() ?? '';

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _positionMs = (line['time'] as num).toInt();
              _activeLineIndex = index;
            });
          },
          child: Transform.scale(
            scale: isNow ? 1.05 : (isPast ? 0.90 : 0.95),
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                text.isEmpty ? '♪ ♪ ♪' : text,
                style: TextStyle(
                  fontSize: isNow ? 22 : 16,
                  fontWeight: isNow ? FontWeight.w900 : (isPast ? FontWeight.w400 : FontWeight.w600),
                  color: isNow
                      ? Colors.white
                      : (isPast
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.65)),
                  height: 1.35,
                  shadows: isNow
                      ? [
                          Shadow(
                            color: const Color(0xFF14E0C1).withValues(alpha: 0.75),
                            blurRadius: 24,
                          ),
                          const Shadow(
                            color: Colors.black87,
                            offset: Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingEqualizer() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EqualizerWidget(controller: _eqController),
          const SizedBox(height: 18),
          const Text(
            'Finding lyrics…',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Connecting to LRCLIB & NetEase',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EqualizerWidget(controller: _eqController),
          const SizedBox(height: 18),
          const Text(
            'Waiting for music…',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Play something in Spotify, YouTube Music or any app to stream live synced lyrics to your car.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white60, height: 1.4),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => setState(() => _showSearchBar = true),
            icon: const Icon(Icons.search, color: Color(0xFF14E0C1), size: 18),
            label: const Text('Search Lyrics Manually', style: TextStyle(color: Color(0xFF14E0C1), fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF14E0C1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _EqualizerWidget extends StatelessWidget {
  final AnimationController controller;
  const _EqualizerWidget({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final v = controller.value;
        final h1 = 12.0 + 20.0 * (0.5 + 0.5 * (v * 2 * 3.14159).abs());
        final h2 = 12.0 + 26.0 * (0.5 + 0.5 * ((v + 0.3) * 2 * 3.14159).abs());
        final h3 = 12.0 + 18.0 * (0.5 + 0.5 * ((v + 0.6) * 2 * 3.14159).abs());

        return SizedBox(
          height: 38,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(const Color(0xFF14E0C1), h1.clamp(10, 36)),
              const SizedBox(width: 5),
              _buildBar(const Color(0xFF3FC8D8), h2.clamp(10, 36)),
              const SizedBox(width: 5),
              _buildBar(const Color(0xFF0B9E8A), h3.clamp(10, 36)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(Color color, double height) {
    return Container(
      width: 6,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
