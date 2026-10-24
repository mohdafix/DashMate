import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/localization.dart';
import 'background_screen.dart';
import 'button_size_screen.dart';
import 'car_card_screen.dart';
import 'floating_menu_screen.dart';
import 'football_settings_screen.dart';
import 'prayer_screen.dart';
import 'welcome_sound_screen.dart';
import 'widgets_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');
  static const MethodChannel _browserChannel = MethodChannel('drivedeck/car_browser');

  String _bgMode = 'Cover';
  String _activeFont = 'Orbitron';
  final String _sound = 'Chime';
  double _buttonSize = 100.0;
  bool _is24Hour = true;
  bool _useKmh = true;
  bool _mediaButtonsOverride = true;

  void _showFontPicker() {
    const fonts = ['orbitron', 'bebas', 'audiowide', 'monoton', 'teko', 'poiret'];
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
              const Text('Clock & Speedometer Font', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              ...fonts.map((f) => ListTile(
                title: Text(f.toUpperCase(), style: const TextStyle(color: Colors.white, letterSpacing: 1.2)),
                trailing: _activeFont.toLowerCase() == f ? const Icon(Icons.check, color: AppColors.tealAccent) : null,
                onTap: () {
                  setState(() => _activeFont = f[0].toUpperCase() + f.substring(1));
                  _channel.invokeMethod('setFont', {'font': f});
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        );
      },
    );
  }

  void _clearBrowserCache() async {
    try {
      await _browserChannel.invokeMethod('clearBrowserData');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Browser data cleared / Data penyemak imbas dipadam'),
            backgroundColor: Color(0xFF16253B),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Account Card (Matches AutoDeck)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF132D44), Color(0xFF0F1E2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(color: AppColors.tealAccent, shape: BoxShape.circle),
                  child: const Center(
                    child: Text('M', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AutoDeck Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      SizedBox(height: 2),
                      Text('Mohamad Afix · All features unlocked', style: TextStyle(fontSize: 12, color: AppColors.tealAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('Car Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              children: [
                _buildSettingTile(
                  icon: Icons.grid_view,
                  title: 'Car home widgets',
                  subtitle: '10 widgets available · Drag to reorder',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WidgetsScreen())),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.glassBorder),
                _buildSettingTile(
                  icon: Icons.menu_open,
                  title: 'Car menu',
                  subtitle: '5 · shown in the floating menu',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FloatingMenuScreen())),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.glassBorder),
                _buildSettingTile(
                  icon: Icons.wallpaper_outlined,
                  title: 'Car home background',
                  subtitle: _bgMode,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackgroundScreen())),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.glassBorder),
                _buildSettingTile(
                  icon: Icons.credit_card_outlined,
                  title: 'Car card (next to the map)',
                  subtitle: 'Auto · Music, Prayer, Weather, Sports',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CarCardScreen())),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.glassBorder),
                _buildSettingTile(
                  icon: Icons.font_download_outlined,
                  title: 'Clock font',
                  subtitle: _activeFont,
                  onTap: _showFontPicker,
                ),
                const Divider(height: 1, indent: 56, color: AppColors.glassBorder),
                _buildSettingTile(
                  icon: Icons.graphic_eq,
                  title: 'Welcome sound',
                  subtitle: 'A chime when AutoDeck opens in the car · $_sound',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WelcomeSoundScreen())),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.glassBorder),
                _buildSettingTile(
                  icon: Icons.touch_app_outlined,
                  title: 'Car button size',
                  subtitle: '${_buttonSize.toInt()}% · Bigger car buttons, easier to tap while driving',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ButtonSizeScreen())),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.glassBorder),
                SwitchListTile(
                  secondary: const Icon(Icons.access_time, color: AppColors.textDim, size: 20),
                  title: const Text('24-hour clock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                  subtitle: Text(_is24Hour ? '13:00' : '1:00 PM', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  value: _is24Hour,
                  activeColor: AppColors.tealAccent,
                  onChanged: (val) => setState(() => _is24Hour = val),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.glassBorder),
                SwitchListTile(
                  secondary: const Icon(Icons.speed, color: AppColors.textDim, size: 20),
                  title: const Text('Speedometer unit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                  subtitle: Text(_useKmh ? 'km/h' : 'mph', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  value: _useKmh,
                  activeColor: AppColors.tealAccent,
                  onChanged: (val) => setState(() => _useKmh = val),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.glassBorder),
                SwitchListTile(
                  secondary: const Icon(Icons.radio_button_checked, color: AppColors.textDim, size: 20),
                  title: const Text('Dashboard media buttons', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                  subtitle: const Text('Turn off if your car\'s dashboard / meter map or media buttons stop working while AutoDeck is open', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  value: _mediaButtonsOverride,
                  activeColor: AppColors.tealAccent,
                  onChanged: (val) => setState(() => _mediaButtonsOverride = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('Apps Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              children: [
                _buildSettingTile(
                  icon: Icons.mosque_outlined,
                  title: 'Prayer settings',
                  subtitle: 'Show prayer times, JAKIM zone, and Azan notifications',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrayerScreen())),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.glassBorder),
                _buildSettingTile(
                  icon: Icons.sports_soccer_outlined,
                  title: 'Football settings',
                  subtitle: 'Followed competitions, favourite teams, and API key',
                  isLast: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FootballSettingsScreen())),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('Permissions & Storage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              children: [
                _buildSettingTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Media Listener Access',
                  subtitle: 'Captures Spotify & YouTube Music artwork and live now playing',
                  onTap: () => _channel.invokeMethod('openNotificationSettings'),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.glassBorder),
                _buildSettingTile(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Clear browser data',
                  subtitle: 'Deletes cached pages, cookies and web storage',
                  onTap: _clearBrowserCache,
                ),
                const Divider(height: 1, indent: 56, color: AppColors.glassBorder),
                _buildSettingTile(
                  icon: Icons.language,
                  title: 'Language / Bahasa',
                  subtitle: AppLocalizations.isMs ? 'Bahasa Melayu' : 'English',
                  isLast: true,
                  onTap: () {
                    final next = AppLocalizations.isMs ? 'en' : 'ms';
                    AppLocalizations.setLocale(next);
                    _channel.invokeMethod('setLanguage', {'lang': next});
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Legal Disclaimers verbatim from AutoDeck
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1424),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.tealAccent),
                    SizedBox(width: 8),
                    Text('Legal Disclaimer / Penafian Undang-undang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'AutoDeck is a personal, unofficial app. It is not affiliated with or endorsed by Google, Android Auto, Spotify, YouTube, Netflix, RTM, JAKIM, LRCLIB or football-data.org.\n\n'
                  'AutoDeck ialah aplikasi peribadi dan tidak rasmi. Ia tidak bergabung dengan atau disokong oleh Google, Android Auto, Spotify, YouTube, Netflix, RTM, JAKIM, LRCLIB atau football-data.org.\n\n'
                  'Prayer times, lyrics, weather and football data come from third-party sources and may be late, incomplete or wrong. Check official sources when it matters. Always obey traffic laws and never operate the screen while driving.',
                  style: TextStyle(fontSize: 10, color: AppColors.textDim, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Center(
            child: Text(
              'AutoDeck 2.0.0 (Personal Build)\nBuilt for Android Auto',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textDim, height: 1.4),
            ),
          ),
          const SizedBox(height: 24),
        ],
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
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: AppColors.textDim),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
