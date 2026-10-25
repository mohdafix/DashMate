import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../channels/platform_channels.dart';
import '../models/media_state.dart';

class CarPreviewScreen extends StatefulWidget {
  const CarPreviewScreen({super.key});

  @override
  State<CarPreviewScreen> createState() => _CarPreviewScreenState();
}

class _CarPreviewScreenState extends State<CarPreviewScreen> {
  String _activeTab = 'home';
  MediaState _mediaState = MediaState();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    PlatformChannels.setCarPage('home');
    _refreshState();
    _ticker = Timer.periodic(const Duration(milliseconds: 1000), (_) => _refreshState());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refreshState() async {
    final state = await PlatformChannels.getNowPlayingState();
    if (mounted) setState(() => _mediaState = state);
  }

  void _switchTab(String tab) {
    setState(() => _activeTab = tab);
    PlatformChannels.setCarPage(tab);
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B14),
        elevation: 0,
        title: const Text('Car Screen Preview', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LIVE HEAD-UNIT SIMULATOR (16:9)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.0),
            ),
            const SizedBox(height: 10),

            // 16:9 Car Screen Container
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0F1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Background Deck View
                    Positioned.fill(
                      child: Container(
                        padding: const EdgeInsets.only(left: 60, top: 12, right: 12, bottom: 12),
                        child: _buildDeckContent(timeStr),
                      ),
                    ),

                    // Left Floating Dock Bar
                    Positioned(
                      left: 10,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildDockBtn('home', Icons.dashboard_rounded, const Color(0xFF14E0C1)),
                              _buildDockBtn('lyrics', Icons.lyrics_rounded, const Color(0xFFFF5252)),
                              _buildDockBtn('prayer', Icons.mosque_rounded, const Color(0xFF448AFF)),
                              _buildDockBtn('custom', Icons.grid_view_rounded, const Color(0xFFA78BFA)),
                              _buildDockBtn('web', Icons.public_rounded, const Color(0xFFFFD54F)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Instructions Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.touch_app_rounded, color: Color(0xFF14E0C1)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap the dock icons inside the simulator or switch tabs to preview how DashMate renders on your vehicle screen in real-time.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockBtn(String tab, IconData icon, Color color) {
    final isSelected = _activeTab == tab;
    return GestureDetector(
      onTap: () => _switchTab(tab),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.25) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: isSelected ? color : Colors.white54),
      ),
    );
  }

  Widget _buildDeckContent(String timeStr) {
    if (_activeTab == 'lyrics') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _mediaState.title.isNotEmpty ? _mediaState.title : 'Synchronized Lyrics',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            _mediaState.artist.isNotEmpty ? _mediaState.artist : 'Waiting for track...',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(
            _mediaState.currentLyric.isNotEmpty ? _mediaState.currentLyric : 'Waiting for music to start…',
            style: const TextStyle(color: Color(0xFF14E0C1), fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_activeTab == 'prayer') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('JAKIM Malaysia - WLY01', style: TextStyle(color: Colors.white54, fontSize: 11)),
          SizedBox(height: 4),
          Text('Next: Maghrib (19:15)', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Fajr 05:45 • Dhuhr 13:10 • Asr 16:25 • Maghrib 19:15 • Isha 20:25', style: TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      );
    }

    if (_activeTab == 'custom') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.grid_view_rounded, size: 36, color: Color(0xFFA78BFA)),
          SizedBox(height: 8),
          Text('Custom Full Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('Weather Radar, Calendar, EV Charging & Sports', style: TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      );
    }

    if (_activeTab == 'web') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.public_rounded, size: 36, color: Color(0xFFFFD54F)),
          SizedBox(height: 8),
          Text('DashMate Web Browser', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('YouTube, RTMKlik TV, Rain Radar', style: TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      );
    }

    // Default: Home Dashboard
    return Row(
      children: [
        // Left Column: Clock & Speed
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(timeStr, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
              const SizedBox(height: 2),
              Row(
                children: const [
                  Text('0', style: TextStyle(color: Color(0xFF14E0C1), fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(width: 4),
                  Text('km/h GPS', style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),

        // Right Column: Music & Prayer Widgets
        Expanded(
          flex: 6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1BE3B0).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.music_note_rounded, color: Color(0xFF1BE3B0), size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _mediaState.title.isNotEmpty ? _mediaState.title : 'Waiting for music…',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _mediaState.artist.isNotEmpty ? _mediaState.artist : 'DashMate Player',
                            style: const TextStyle(color: Colors.white54, fontSize: 9),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('🕌 Asr 16:25', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    Text('⛽ RON95 RM 2.05', style: TextStyle(color: Color(0xFF14E0C1), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
