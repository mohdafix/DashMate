import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/localization.dart';
import 'browse_screen.dart';
import 'calendar_screen.dart';
import 'car_card_screen.dart';
import 'custom_page_screen.dart';
import 'floating_menu_screen.dart';
import 'lyrics_screen.dart';
import 'parking_screen.dart';
import 'prayer_screen.dart';
import 'settings_screen.dart';
import 'widgets_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');

  String _bgMode = "Cover";
  final String _sound = "Chime";
  double _buttonSize = 100.0;
  String _activeFont = "Orbitron";
  String _carCard = "Auto";
  String _prayerTime = "Zohor 1:00 PM";
  String _weatherTemp = "24° Drizzle";
  String _parkingSubtitle = "No parking spot yet";
  String _headUnitName = "Google Desktop Head Unit";
  String _headUnitRes = "1190×480";

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
        final weather = parsed['weather'];
        final parking = parsed['parking'];
        final lang = parsed['lang'] ?? 'en';
        AppLocalizations.setLocale(lang);

        setState(() {
          if (prayer != null && prayer['next'] != null && prayer['time'] != null) {
            _prayerTime = '${prayer['next']} ${prayer['time']}';
          }
          if (weather != null && weather['temp'] != null && weather['cond'] != null) {
            _weatherTemp = '${weather['temp']} ${weather['cond']}';
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

  void _showBgPicker() {
    const modes = ['Cover', 'Plain', 'Photo'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Car Home Background', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              ...modes.map((m) => ListTile(
                title: Text(m, style: const TextStyle(color: Colors.white)),
                trailing: _bgMode == m ? const Icon(Icons.check, color: AppColors.tealAccent) : null,
                onTap: () {
                  setState(() => _bgMode = m);
                  _channel.invokeMethod('setBgMode', {'mode': m.toLowerCase(), 'url': ''});
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        );
      },
    );
  }

  void _showButtonSizeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('Car button size', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Bigger car buttons, easier to tap while driving', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 16),
                  Text('${_buttonSize.toInt()}%', style: const TextStyle(color: AppColors.tealAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                  Slider(
                    value: _buttonSize,
                    min: 80,
                    max: 130,
                    divisions: 5,
                    activeColor: AppColors.tealAccent,
                    onChanged: (val) {
                      setDialogState(() => _buttonSize = val);
                      setState(() => _buttonSize = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done', style: TextStyle(color: AppColors.tealAccent)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          // Account Status Card (Matches Screenshot & AutoDeck)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF16253B), Color(0xFF0F1A2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Welcome back', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 4),
                      const Text('Mohamad Afix', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF24364E), borderRadius: BorderRadius.circular(8)),
                            child: const Text('DashMate Pro', style: TextStyle(color: AppColors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          const Text('Active · Android Auto Connected', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.tealAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('M', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Top Horizontal Chips Carousel (Matches Screenshot 2)
          SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildTopChip(
                  icon: Icons.touch_app_outlined,
                  title: 'Car button size',
                  subtitle: 'Bigger car buttons, easier to tap while driving',
                  onTap: _showButtonSizeDialog,
                ),
                const SizedBox(width: 10),
                _buildTopChip(
                  icon: Icons.waving_hand_outlined,
                  title: 'Welcome sound',
                  subtitle: 'A chime when AutoDeck opens in the car',
                  onTap: () {},
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

          // "Apps" Section Header
          const Text('Apps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Full-width Lyrics App Card (Matches Screenshot 2)
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LyricsScreen())),
            child: Container(
              padding: const EdgeInsets.all(16),
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
                      color: const Color(0xFF33202E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lyrics_outlined, color: Color(0xFFFF7A85), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lyrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('Auto', style: TextStyle(fontSize: 12, color: AppColors.textSub)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: AppColors.textDim, size: 20),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LyricsScreen())),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 2x2 Grid: Prayer, Browse, Custom page, Parking (Matches Screenshot 2 & AutoDeck)
          Row(
            children: [
              Expanded(
                child: _buildAppTile(
                  icon: Icons.mosque_outlined,
                  iconBg: const Color(0xFF133A36),
                  iconColor: AppColors.accentTeal,
                  title: 'Prayer',
                  subtitle: _prayerTime,
                  hasSettings: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrayerScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAppTile(
                  icon: Icons.language_outlined,
                  iconBg: const Color(0xFF132D44),
                  iconColor: const Color(0xFF5EBEFF),
                  title: 'Browse',
                  subtitle: 'Web, YouTube, RTM K...',
                  hasSettings: true,
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
                  icon: Icons.dashboard_customize_outlined,
                  iconBg: const Color(0xFF362820),
                  iconColor: const Color(0xFFFFB86C),
                  title: 'Custom page',
                  subtitle: 'Weather',
                  hasSettings: false,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomPageScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAppTile(
                  icon: Icons.local_parking,
                  iconBg: const Color(0xFF2E1C38),
                  iconColor: const Color(0xFFD67BFF),
                  title: 'Parking',
                  subtitle: _parkingSubtitle,
                  hasSettings: false,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParkingScreen())),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // "Car screen preview" Section (Matches Screenshot 2)
          const Text('Car screen preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                // Car Display Mockup Box (Matches Screenshot 2)
                Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFF090E17),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      // Left Music Mini
                      Expanded(
                        flex: 5,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.music_note, color: Colors.white38, size: 28),
                              SizedBox(width: 6),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Waiting for music...', style: TextStyle(fontSize: 9, color: Colors.white54)),
                                  Text('Play in Spotify', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Right Mini Tiles
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                                    child: Text(_weatherTemp, style: const TextStyle(fontSize: 8, color: Colors.white70)),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.wb_sunny_outlined, size: 14, color: AppColors.accentTeal),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Container(width: 16, height: 16, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEA4335))),
                                  Container(width: 16, height: 16, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF34A853))),
                                  Container(width: 16, height: 16, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4285F4))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(_headUnitName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Text(_headUnitRes, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                const SizedBox(height: 6),
                const Text(
                  'Live: the same Home page Android Auto shows, with your data. Edit widgets and watch it change.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSub, height: 1.3),
                ),
                const SizedBox(height: 14),
                // Edit Widgets Button (Matches Screenshot 2)
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

          // "Car settings" Section (Matches Screenshot 2 & AutoDeck)
          const Text('Car settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  subtitle: '8 widgets',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WidgetsScreen())),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.border),
                _buildSettingTile(
                  icon: Icons.menu_open,
                  title: 'Car menu',
                  subtitle: '5 · shown in the floating menu',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FloatingMenuScreen())),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.border),
                _buildSettingTile(
                  icon: Icons.wallpaper_outlined,
                  title: 'Car home background',
                  subtitle: _bgMode,
                  onTap: _showBgPicker,
                ),
                const Divider(height: 1, indent: 56, color: AppColors.border),
                _buildSettingTile(
                  icon: Icons.credit_card_outlined,
                  title: 'Car card (next to the map)',
                  subtitle: _carCard,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CarCardScreen()));
                    _loadState();
                  },
                ),
                const Divider(height: 1, indent: 56, color: AppColors.border),
                _buildSettingTile(
                  icon: Icons.graphic_eq,
                  title: 'Welcome sound',
                  subtitle: _sound,
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56, color: AppColors.border),
                _buildSettingTile(
                  icon: Icons.touch_app_outlined,
                  title: 'Car button size',
                  subtitle: '${_buttonSize.toInt()}%',
                  isLast: true,
                  onTap: _showButtonSizeDialog,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTopChip({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accentTeal, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textSub), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
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
                  const Icon(Icons.settings_outlined, color: AppColors.textDim, size: 18)
                else
                  const Icon(Icons.arrow_forward_ios, color: AppColors.textDim, size: 14),
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
      leading: Icon(icon, color: AppColors.textDim, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: AppColors.textDim),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
