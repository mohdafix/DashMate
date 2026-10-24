import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/localization.dart';
import 'background_screen.dart';
import 'browse_screen.dart';
import 'button_size_screen.dart';
import 'car_card_screen.dart';
import 'custom_page_screen.dart';
import 'floating_menu_screen.dart';
import 'lyrics_screen.dart';
import 'parking_screen.dart';
import 'prayer_screen.dart';
import 'settings_screen.dart';
import 'welcome_sound_screen.dart';
import 'widgets_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');

  String _bgMode = "Cover";
  double _buttonSize = 100.0;
  String _carCard = "Auto";
  String _prayerTime = "Maghrib 6:59 PM";
  String _parkingSubtitle = "3:49 PM";
  String _headUnitName = "Google Desktop Head Unit";
  String _headUnitRes = "1190x480";
  String _customPageSubtitle = "Sports";
  String _browseSubtitle = "youtube.com";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadState();
    });
  }

  void _loadState() async {
    try {
      final res = await _channel.invokeMethod('getState');
      if (res != null && mounted) {
        final parsed = jsonDecode(res as String);
        final prayer = parsed['prayer'];
        final parking = parsed['parking'];
        final lang = parsed['lang'] ?? 'en';
        AppLocalizations.setLocale(lang);

        setState(() {
          if (prayer != null && prayer['next'] != null && prayer['time'] != null) {
            _prayerTime = '${prayer['next']} ${prayer['time']}';
          }
          if (parking != null && parking['saved'] == true) {
            final int ts = parking['time'] ?? 0;
            if (ts > 0) {
              final d = DateTime.fromMillisecondsSinceEpoch(ts);
              final h = d.hour.toString().padLeft(2, '0');
              final m = d.minute.toString().padLeft(2, '0');
              _parkingSubtitle = '$h:$m';
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white, size: 22),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          // 1. Golden Amber Welcome Card (Matches Screenshot 100%)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF5A3912),
                  Color(0xFF261604),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0x33FFB300)),
            ),
            child: Column(
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(color: Color(0xFFD4B892), fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Mohamad Afix',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                // Capsule pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 13,
                        backgroundColor: Color(0xFF8C5C26),
                        child: Icon(Icons.person, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9E5C0D),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Trial',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Free trial · 2d 1h left',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white70),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. Carousel Chips (Car button size & Welcome sound)
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildTopChip(
                  icon: Icons.touch_app_outlined,
                  iconBg: const Color(0xFF162D4A),
                  iconColor: const Color(0xFF5EBEFF),
                  title: 'Car button size',
                  subtitle: 'Bigger car buttons, easier to tap while driving',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ButtonSizeScreen())),
                ),
                const SizedBox(width: 10),
                _buildTopChip(
                  icon: Icons.waving_hand_outlined,
                  iconBg: const Color(0xFF3D2A10),
                  iconColor: const Color(0xFFFFB86C),
                  title: 'Welcome sound',
                  subtitle: 'A chime when AutoDeck opens in the car',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WelcomeSoundScreen())),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Center(
            child: Text(
              '⌄   All car settings · Scroll down to see everything',
              style: TextStyle(fontSize: 11, color: AppColors.textDim),
            ),
          ),

          const SizedBox(height: 20),

          // 3. "Apps" Section
          const Text('Apps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),

          // Full-width Lyrics App Card
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LyricsScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF381A25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.speaker_notes, color: Color(0xFFFF6584), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lyrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 2),
                        Text('Auto', style: TextStyle(fontSize: 12, color: AppColors.textSub)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white38, size: 20),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LyricsScreen())),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 2x2 Grid (Prayer, Browse, Custom page, Parking)
          Row(
            children: [
              Expanded(
                child: _buildAppTile(
                  icon: Icons.mosque_outlined,
                  iconBg: const Color(0xFF0F3230),
                  iconColor: const Color(0xFF14E0C1),
                  title: 'Prayer',
                  subtitle: _prayerTime,
                  hasSettings: true,
                  onSettingsTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrayerScreen())),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrayerScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAppTile(
                  icon: Icons.public,
                  iconBg: const Color(0xFF132A44),
                  iconColor: const Color(0xFF5EBEFF),
                  title: 'Browse',
                  subtitle: _browseSubtitle,
                  hasSettings: true,
                  onSettingsTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrowseScreen())),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrowseScreen())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildAppTile(
                  icon: Icons.grid_view_outlined,
                  iconBg: const Color(0xFF382614),
                  iconColor: const Color(0xFFFFAB40),
                  title: 'Custom page',
                  subtitle: _customPageSubtitle,
                  hasSettings: false,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomPageScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAppTile(
                  icon: Icons.local_parking,
                  iconBg: const Color(0xFF281838),
                  iconColor: const Color(0xFFBA68C8),
                  title: 'Parking',
                  subtitle: _parkingSubtitle,
                  hasSettings: false,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParkingScreen())),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 4. "Car screen preview" Section
          const Text('Car screen preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Car Display Mockup Frame
                Container(
                  height: 120,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080C14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      // Mini album square
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2838),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.music_note, color: Colors.white38, size: 30),
                      ),
                      const SizedBox(width: 14),
                      // Track info & mini controls
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Waiting for music...', style: TextStyle(fontSize: 10, color: Colors.white54)),
                            const SizedBox(height: 2),
                            const Text('Play something in Spotify', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.skip_previous, size: 18, color: Colors.white54),
                                const SizedBox(width: 12),
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white12),
                                  child: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                const Icon(Icons.skip_next, size: 18, color: Colors.white54),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(_headUnitName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Text(_headUnitRes, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                const SizedBox(height: 6),
                const Text(
                  'Live: the same Home page Android Auto shows, with your data. Edit widgets and watch it change.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSub, height: 1.3),
                ),
                const SizedBox(height: 14),
                // Outlined "Edit widgets" Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WidgetsScreen())),
                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.accentTeal),
                    label: const Text('Edit widgets', style: TextStyle(color: AppColors.accentTeal, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accentTeal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 5. "Car settings" Section (Grouped List of 6 items)
          const Text('Car settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildSettingTile(
                  icon: Icons.grid_view,
                  title: 'Car home widgets',
                  subtitle: '1 widgets',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WidgetsScreen())),
                ),
                const Divider(height: 1, color: Colors.white10),
                _buildSettingTile(
                  icon: Icons.segment,
                  title: 'Car menu',
                  subtitle: '5 · shown in the floating menu',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FloatingMenuScreen())),
                ),
                const Divider(height: 1, color: Colors.white10),
                _buildSettingTile(
                  icon: Icons.wallpaper_outlined,
                  title: 'Car home background',
                  subtitle: _bgMode,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackgroundScreen())),
                ),
                const Divider(height: 1, color: Colors.white10),
                _buildSettingTile(
                  icon: Icons.featured_video_outlined,
                  title: 'Car card (next to the map)',
                  subtitle: _carCard,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CarCardScreen())),
                ),
                const Divider(height: 1, color: Colors.white10),
                _buildSettingTile(
                  icon: Icons.waving_hand_outlined,
                  title: 'Welcome sound',
                  subtitle: 'Chime',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WelcomeSoundScreen())),
                ),
                const Divider(height: 1, color: Colors.white10),
                _buildSettingTile(
                  icon: Icons.touch_app_outlined,
                  title: 'Car button size',
                  subtitle: '${_buttonSize.toInt()}%',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ButtonSizeScreen())),
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildTopChip({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textSub), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildAppTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool hasSettings,
    VoidCallback? onSettingsTap,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (hasSettings)
                  GestureDetector(
                    onTap: onSettingsTap ?? onTap,
                    child: const Icon(Icons.settings_outlined, color: Colors.white38, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSub), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.accentTeal, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.white38),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
