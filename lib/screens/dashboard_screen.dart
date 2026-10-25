import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';
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
  // Measured from the car each time DashMate opens there; null until the first drive.
  String? _carScreenSize;
  String _customPageSubtitle = "Sports";
  String _browseSubtitle = "youtube.com";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadState();
    });
  }

  void _loadCarScreenSize() async {
    try {
      final size = await _channel.invokeMethod<String>('getCarScreenSize');
      if (mounted) setState(() => _carScreenSize = size);
    } catch (_) {}
  }

  void _openCarScreen() async {
    try {
      await _channel.invokeMethod('openCarPreview');
    } catch (_) {}
  }

  void _loadState() async {
    _loadCarScreenSize();
    try {
      final res = await _channel.invokeMethod('getState');
      if (res != null && mounted) {
        final parsed = jsonDecode(res as String);
        final prayer = parsed['prayer'];
        final parking = parsed['parking'];
        final lang = parsed['lang'] ?? 'en';
        AppLocalizations.setLocale(lang);

        setState(() {
          final next = prayer?['next'];
          if (next is Map && next['name'] != null && next['time'] != null) {
            // "next" is {name, time, ...}; show it as "Subuh 05:49".
            _prayerTime = '${next['name']} ${next['time']}';
          } else if (next != null && prayer['time'] != null) {
            _prayerTime = '$next ${prayer['time']}';
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
    final t = context.tokens;
    final sectionStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.ink);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Dashboard',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: t.ink),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: t.ink, size: 22),
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
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border),
              boxShadow: t.cardShadow,
            ),
            child: Column(
              children: [
                Text(
                  'Welcome back',
                  style: TextStyle(color: t.ink2, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text(
                  'Wakjilat',
                  style: TextStyle(color: t.ink, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                // Capsule pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: t.accent.withValues(alpha: 0.12),
                        child: Icon(Icons.person, size: 16, color: t.accent),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Pro',
                          style: TextStyle(color: t.onAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'All features unlocked',
                        style: TextStyle(color: t.ink2, fontSize: 12),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios, size: 12, color: t.ink3),
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
                  t: t,
                  title: 'Car button size',
                  subtitle: 'Bigger car buttons, easier to tap while driving',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ButtonSizeScreen())),
                ),
                const SizedBox(width: 10),
                _buildTopChip(
                  icon: Icons.waving_hand_outlined,
                  t: t,
                  title: 'Welcome sound',
                  subtitle: 'A chime when DashMate opens in the car',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WelcomeSoundScreen())),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Center(
            child: Text(
              '⌄   All car settings · Scroll down to see everything',
              style: TextStyle(fontSize: 11, color: t.ink3),
            ),
          ),

          const SizedBox(height: 20),

          // 3. "Apps" Section
          Text('Apps', style: sectionStyle),
          const SizedBox(height: 12),

          // Full-width Lyrics App Card
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LyricsScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.border),
                boxShadow: t.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.speaker_notes, color: t.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lyrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.ink)),
                        const SizedBox(height: 2),
                        Text('Auto', style: TextStyle(fontSize: 12, color: t.ink2)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: t.ink3, size: 20),
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
                  iconBg: t.accent.withValues(alpha: 0.10),
                  iconColor: t.accent,
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
                  iconBg: t.accent.withValues(alpha: 0.10),
                  iconColor: t.accent,
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
                  iconBg: t.accent.withValues(alpha: 0.10),
                  iconColor: t.accent,
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
                  iconBg: t.accent.withValues(alpha: 0.10),
                  iconColor: t.accent,
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
          Text('Car screen preview', style: sectionStyle),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border),
              boxShadow: t.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Opens the real car screen (same deck Android Auto shows), sideways and fully usable.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openCarScreen,
                    icon: Icon(Icons.directions_car_filled_outlined, size: 18, color: t.onAccent),
                    label: Text('Open car screen',
                        style: TextStyle(color: t.onAccent, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.accent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Jaecoo J7 screen',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: t.ink)),
                const SizedBox(height: 2),
                Text(
                  _carScreenSize != null
                      ? '$_carScreenSize · measured from your car'
                      : 'Not measured yet: open DashMate in the car once (preview uses a 14.8" portrait estimate)',
                  style: TextStyle(fontSize: 12, color: t.ink2),
                ),
                const SizedBox(height: 6),
                Text(
                  'The same screen Android Auto shows, with your data, in the car screen\'s shape (tall on the J7). The red button closes it.',
                  style: TextStyle(fontSize: 12, color: t.ink2, height: 1.3),
                ),
                const SizedBox(height: 14),
                // Outlined "Edit widgets" Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WidgetsScreen())),
                    icon: Icon(Icons.edit_outlined, size: 16, color: t.accent),
                    label: Text('Edit widgets', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: t.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 5. "Car settings" Section (Grouped List of 6 items)
          Text('Car settings', style: sectionStyle),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border),
              boxShadow: t.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildSettingTile(
                  icon: Icons.grid_view,
                  title: 'Car home widgets',
                  subtitle: '1 widgets',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WidgetsScreen())),
                ),
                Divider(height: 1, color: t.border),
                _buildSettingTile(
                  icon: Icons.segment,
                  title: 'Car menu',
                  subtitle: '5 · shown in the floating menu',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FloatingMenuScreen())),
                ),
                Divider(height: 1, color: t.border),
                _buildSettingTile(
                  icon: Icons.wallpaper_outlined,
                  title: 'Car home background',
                  subtitle: _bgMode,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackgroundScreen())),
                ),
                Divider(height: 1, color: t.border),
                _buildSettingTile(
                  icon: Icons.featured_video_outlined,
                  title: 'Car card (next to the map)',
                  subtitle: _carCard,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CarCardScreen())),
                ),
                Divider(height: 1, color: t.border),
                _buildSettingTile(
                  icon: Icons.waving_hand_outlined,
                  title: 'Welcome sound',
                  subtitle: 'Chime',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WelcomeSoundScreen())),
                ),
                Divider(height: 1, color: t.border),
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
    required AppTokens t,
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
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: t.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: t.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: t.ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: t.ink3, size: 12),
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
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
          boxShadow: t.cardShadow,
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
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (hasSettings)
                  GestureDetector(
                    onTap: onSettingsTap ?? onTap,
                    child: Icon(Icons.settings_outlined, color: t.ink3, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: t.ink)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: t.ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
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
    final t = context.tokens;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: t.accent, size: 22),
      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.ink)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: t.ink2)),
      trailing: Icon(Icons.arrow_forward_ios, size: 13, color: t.ink3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
