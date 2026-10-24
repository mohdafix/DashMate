import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/localization.dart';
import 'car_card_screen.dart';
import 'floating_menu_screen.dart';
import 'widgets_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');
  String _bgMode = 'Cover';
  String _activeFont = 'Orbitron';
  String _sound = 'Chime';
  double _buttonSize = 100.0;

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
                title: Text(f.toUpperCase(), style: const TextStyle(color: Colors.white)),
                trailing: _activeFont.toLowerCase() == f ? const Icon(Icons.check, color: AppColors.tealAccent) : null,
                onTap: () {
                  setState(() => _activeFont = f.toUpperCase());
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

  void _showButtonSizeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('Car Button Size', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Account Card
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
                    child: Text('D', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DashMate Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      SizedBox(height: 2),
                      Text('All features unlocked · Lifetime', style: TextStyle(fontSize: 12, color: AppColors.tealAccent)),
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
                  onTap: _showBgPicker,
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
                  subtitle: _sound,
                  onTap: () {
                    _channel.invokeMethod('openNotificationSettings');
                  },
                ),
                const Divider(height: 1, indent: 56, color: AppColors.glassBorder),
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

          const SizedBox(height: 24),
          const Text('Permissions & System', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
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
                  subtitle: 'Captures Spotify & YouTube Music artwork and now playing',
                  onTap: () => _channel.invokeMethod('openNotificationSettings'),
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
          const Center(
            child: Text(
              'DashMate Deck v2.0.0 (Pro Edition)\nBuilt for Android Auto',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textDim, height: 1.4),
            ),
          ),
          const SizedBox(height: 20),
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
