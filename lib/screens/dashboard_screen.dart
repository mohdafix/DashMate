import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../channels/platform_channels.dart';
import '../models/media_state.dart';
import '../theme/app_colors.dart';
import '../theme/localization.dart';
import 'background_screen.dart';
import 'browse_screen.dart';
import 'button_size_screen.dart';
import 'calendar_screen.dart';
import 'car_card_screen.dart';
import 'custom_page_screen.dart';
import 'floating_menu_screen.dart';
import 'lyrics_screen.dart';
import 'parking_screen.dart';
import 'prayer_screen.dart';
import 'sports_screen.dart';
import 'welcome_sound_screen.dart';
import 'widgets_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');
  static const MethodChannel _browserChannel = MethodChannel('drivedeck/car_browser');

  int _currentTabIndex = 0;
  Timer? _statusPoller;

  // Car Connection State
  bool _isCarConnected = false;
  String _bgMode = "Cover";
  double _buttonSize = 100.0;
  String _carCard = "Auto";
  String _prayerTime = "Maghrib 6:59 PM";
  String _parkingSubtitle = "3:49 PM";
  String _headUnitName = "Android Auto Head Unit";
  String _headUnitRes = "1190×480";
  String _customPageSubtitle = "Sports";
  final String _browseSubtitle = "youtube.com";
  String _dockPosition = "Bottom Right";
  String _activeFont = "Orbitron";
  bool _is24Hour = true;
  bool _useKmh = true;
  String _welcomeSound = "Chime";
  bool _autoStart = true;
  String _layoutMode = "Wide Display (Landscape)";
  String _driverName = "Mohamad Afix";
  String _themeMode = "auto";

  String _getDriverInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'DM';
    if (parts.length == 1) {
      final w = parts[0];
      return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _loadDriverName() async {
    try {
      final name = await _channel.invokeMethod<String>('getDriverName');
      if (name != null && name.isNotEmpty && mounted) {
        setState(() => _driverName = name);
        return;
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('driver_name');
      if (name != null && name.isNotEmpty && mounted) {
        setState(() => _driverName = name);
      }
    } catch (_) {}
  }

  Future<void> _updateDriverName(String name) async {
    setState(() => _driverName = name);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_name', name);
    } catch (_) {}
    try {
      await _channel.invokeMethod('setDriverName', {'name': name});
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Driver profile updated to $name'),
          backgroundColor: const Color(0xFF16253B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showEditDriverNameDialog() {
    final controller = TextEditingController(text: _driverName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.person_rounded, color: AppColors.accentTeal),
            SizedBox(width: 10),
            Text(
              'Edit Driver Profile',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter driver name. This name is used for car welcome greetings and profile display.',
              style: TextStyle(color: AppColors.textSub, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Driver Name',
                labelStyle: const TextStyle(color: AppColors.accentTeal),
                hintText: 'e.g. Mohamad Afix',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.accentTeal),
                filled: true,
                fillColor: const Color(0xFF1E2838),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accentTeal, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await _updateDriverName(newName);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAutoStart() async {
    try {
      final res = await _channel.invokeMethod<bool>('getAutoStart');
      if (res != null && mounted) setState(() => _autoStart = res);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _autoStart = prefs.getBool('pref_auto_start') ?? true);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString('dashmate_layout_mode') ?? 'auto';
      if (mounted) {
        setState(() => _layoutMode = mode == 'tall' ? 'Tall Display (Portrait)' : 'Wide Display (Landscape)');
      }
    } catch (_) {}
  }

  Future<void> _toggleAutoStart(bool val) async {
    setState(() => _autoStart = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_auto_start', val);
    try {
      await _channel.invokeMethod('setAutoStart', {'enabled': val});
    } catch (_) {}
  }

  
  Future<void> _updateThemeMode(String mode) async {
    setState(() => _themeMode = mode);
    await PlatformChannels.setThemeMode(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode);
    } catch (_) {}
    if (mounted) {
      final label = mode == 'day' ? 'Day (Light)' : mode == 'night' ? 'Night (Dark)' : 'Auto (Headlights)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Car display theme set to $label'),
          backgroundColor: const Color(0xFF16253B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.palette_outlined, color: AppColors.accentTeal, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Car Display Theme',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose whether the car display stays in day or night mode, or adapts automatically.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSub),
                ),
                const SizedBox(height: 16),
                _buildThemeOptionTile(
                  keyName: 'auto',
                  title: 'Auto',
                  subtitle: 'Adapts to car headlights & day / sunset signals',
                  icon: Icons.brightness_auto,
                  color: AppColors.accentTeal,
                ),
                const Divider(height: 1, color: Colors.white10),
                _buildThemeOptionTile(
                  keyName: 'day',
                  title: 'Day',
                  subtitle: 'Forced light theme · High daytime visibility',
                  icon: Icons.light_mode_rounded,
                  color: const Color(0xFFFFB86C),
                ),
                const Divider(height: 1, color: Colors.white10),
                _buildThemeOptionTile(
                  keyName: 'night',
                  title: 'Night',
                  subtitle: 'Forced dark theme · Soft charcoal, reduces glare',
                  icon: Icons.dark_mode_rounded,
                  color: const Color(0xFFBA68C8),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOptionTile({
    required String keyName,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _themeMode == keyName;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSub),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.accentTeal, size: 22)
          : null,
      onTap: () {
        Navigator.pop(context);
        _updateThemeMode(keyName);
      },
    );
  }

  void _showCarLayoutDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Car Screen Layout Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              const Text('Optimized for tall portrait screens (1080×1920) or wide landscape head units.', style: TextStyle(fontSize: 13, color: AppColors.textSub)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.stay_current_portrait, color: AppColors.accentTeal),
                title: const Text('Tall Display (Portrait 1080×1920)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Top dock bar, optimized music & widget sizing for portrait display', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
                trailing: _layoutMode.contains('Tall') ? const Icon(Icons.check, color: AppColors.accentTeal) : null,
                onTap: () async {
                  setState(() => _layoutMode = 'Tall Display (Portrait)');
                  _loadLayout();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('dashmate_layout_mode', 'tall');
                  try {
                    await _browserChannel.invokeMethod('setLayoutMode', {'mode': 'tall'});
                  } catch (_) {}
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1, color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: Color(0xFF5EBEFF)),
                title: const Text('Wide Display (Landscape)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Adapts dynamically to wide landscape screens reported by Android Auto', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
                trailing: !_layoutMode.contains('Tall') ? const Icon(Icons.check, color: AppColors.accentTeal) : null,
                onTap: () async {
                  setState(() => _layoutMode = 'Wide Display (Landscape)');
                  _loadLayout();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('dashmate_layout_mode', 'auto');
                  try {
                    await _browserChannel.invokeMethod('setLayoutMode', {'mode': 'auto'});
                  } catch (_) {}
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showKeyboardInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.border)),
        title: const Row(
          children: [
            Icon(Icons.keyboard_rounded, color: Color(0xFFBA68C8)),
            SizedBox(width: 10),
            Text('Car On-Screen Keyboard', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your car display now has a built-in keyboard!\n\n'
              '• Tapping any text box (such as YouTube search, Google, Waze address, or sign-in) automatically brings up the keyboard on your car display.\n'
              '• Real-time typing syncs straight into the browser without needing to type on your phone.\n'
              '• Tap "Go" to search, or tap outside the keyboard to dismiss it.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: AppColors.accentTeal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Media
  MediaState _mediaState = MediaState();
  bool _notifGranted = false;

  // Active placed widgets for Live Preview
  List<Map<String, dynamic>> _widgets = [
    {'id': 'clock', 'x': 1, 'y': 1, 'w': 6, 'h': 4},
    {'id': 'prayer', 'x': 7, 'y': 1, 'w': 3, 'h': 2},
    {'id': 'weather', 'x': 10, 'y': 1, 'w': 3, 'h': 2},
    {'id': 'sports', 'x': 7, 'y': 3, 'w': 6, 'h': 2},
    {'id': 'music', 'x': 1, 'y': 5, 'w': 8, 'h': 2},
    {'id': 'speed', 'x': 9, 'y': 5, 'w': 2, 'h': 2},
    {'id': 'shortcuts', 'x': 11, 'y': 5, 'w': 2, 'h': 2},
    {'id': 'fuel', 'x': 1, 'y': 7, 'w': 6, 'h': 2},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDriverName();
      _loadState();
      _loadLayout();
      _refreshMedia();
      _loadAutoStart();
    });

    _statusPoller = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _checkCarConnection();
    });
  }

  @override
  void dispose() {
    _statusPoller?.cancel();
    super.dispose();
  }

  void _checkCarConnection() async {
    try {
      final res = await _channel.invokeMethod<bool>('isCarConnected');
      if (res != null && mounted && res != _isCarConnected) {
        setState(() => _isCarConnected = res);
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _defaultPortraitWidgets() => [
    {'id': 'clock', 'x': 1, 'y': 1, 'w': 12, 'h': 3},
    {'id': 'music', 'x': 1, 'y': 4, 'w': 12, 'h': 4},
    {'id': 'prayer', 'x': 1, 'y': 8, 'w': 6, 'h': 3},
    {'id': 'weather', 'x': 7, 'y': 8, 'w': 6, 'h': 3},
    {'id': 'sports', 'x': 1, 'y': 11, 'w': 12, 'h': 2},
    {'id': 'fuel', 'x': 1, 'y': 13, 'w': 12, 'h': 3},
    {'id': 'speed', 'x': 1, 'y': 16, 'w': 5, 'h': 3},
    {'id': 'shortcuts', 'x': 6, 'y': 16, 'w': 7, 'h': 3},
  ];

  List<Map<String, dynamic>> _defaultLandscapeWidgets() => [
    {'id': 'clock', 'x': 1, 'y': 1, 'w': 6, 'h': 4},
    {'id': 'prayer', 'x': 7, 'y': 1, 'w': 3, 'h': 2},
    {'id': 'weather', 'x': 10, 'y': 1, 'w': 3, 'h': 2},
    {'id': 'sports', 'x': 7, 'y': 3, 'w': 6, 'h': 2},
    {'id': 'music', 'x': 1, 'y': 5, 'w': 8, 'h': 2},
    {'id': 'speed', 'x': 9, 'y': 5, 'w': 2, 'h': 2},
    {'id': 'shortcuts', 'x': 11, 'y': 5, 'w': 2, 'h': 2},
    {'id': 'fuel', 'x': 1, 'y': 7, 'w': 6, 'h': 2},
  ];

  void _loadLayout() async {
    final bool isTall = _layoutMode.contains('Tall');
    try {
      final res = await _channel.invokeMethod('getLayoutSettings', {'tall': isTall});
      if (res != null && mounted) {
        final parsed = jsonDecode(res as String);
        if (parsed['widgets'] != null && (parsed['widgets'] as List).isNotEmpty) {
          setState(() {
            _widgets = List<Map<String, dynamic>>.from(
              (parsed['widgets'] as List).map((e) => Map<String, dynamic>.from(e)),
            );
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _widgets = isTall ? _defaultPortraitWidgets() : _defaultLandscapeWidgets();
      });
    }
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

        if (parsed['driverName'] != null && (parsed['driverName'] as String).isNotEmpty) {
          _driverName = parsed['driverName'] as String;
        }
        setState(() {
          _isCarConnected = parsed['carConnected'] == true || parsed['connected'] == true;
          if (parsed['scr_name'] != null && (parsed['scr_name'] as String).isNotEmpty) {
            _headUnitName = parsed['scr_name'] as String;
          }
          if (parsed['scr_w'] != null && parsed['scr_h'] != null) {
            _headUnitRes = '${parsed['scr_w']}×${parsed['scr_h']}';
          }
          if (parsed['buttonSize'] != null) {
            _buttonSize = (parsed['buttonSize'] as num).toDouble();
          }
          if (parsed['customPage'] != null) {
            final cp = (parsed['customPage'] as String).toLowerCase();
            if (cp == 'weather') {
              _customPageSubtitle = 'Weather';
            } else if (cp == 'calendar') {
              _customPageSubtitle = 'Calendar';
            } else if (cp == 'sports') {
              _customPageSubtitle = 'Sports';
            } else if (cp == 'radar') {
              _customPageSubtitle = 'Rain radar';
            } else if (cp == 'ev') {
              _customPageSubtitle = 'EV charging';
            }
          }

          // Clean prayer time string formatting (no raw Map prints)
          if (prayer != null) {
            String pName = 'Next Solat';
            String pTime = '';
            if (prayer['next'] is Map) {
              pName = prayer['next']['name'] ?? 'Next Solat';
              pTime = prayer['next']['time'] ?? '';
            } else if (prayer['next'] is String) {
              pName = prayer['next'];
              pTime = prayer['time']?.toString() ?? '';
            }
            if (pTime.isEmpty && prayer['time'] != null) {
              pTime = prayer['time'].toString();
            }
            _prayerTime = pTime.isNotEmpty ? '$pName $pTime' : pName;
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
          if (parsed['bgMode'] != null) _bgMode = parsed['bgMode'];
          if (parsed['carCard'] != null) _carCard = parsed['carCard'];
          if (parsed['font'] != null) _activeFont = parsed['font'];
          if (parsed['is24Hour'] != null) _is24Hour = parsed['is24Hour'] == true;
          if (parsed['useKmh'] != null) _useKmh = parsed['useKmh'] == true;
          if (parsed['dockPosition'] != null) {
            final pos = parsed['dockPosition'] as String;
            _dockPosition = _formatPos(pos);
          }
          if (parsed['sound'] != null) _welcomeSound = parsed['sound'];
        });
      }
    } catch (_) {}

    try {
      final themeMode = await PlatformChannels.getThemeMode();
      if (mounted) setState(() => _themeMode = themeMode);
      final granted = await PlatformChannels.isNotificationAccessGranted();
      if (mounted) setState(() => _notifGranted = granted);
    } catch (_) {}
  }

  String _formatPos(String raw) {
    switch (raw.toLowerCase()) {
      case 'top_left': return 'Top Left';
      case 'top_right': return 'Top Right';
      case 'bottom_left': return 'Bottom Left';
      case 'bottom_right': return 'Bottom Right';
      default: return 'Bottom Right';
    }
  }

  void _refreshMedia() async {
    try {
      final state = await PlatformChannels.getNowPlayingState();
      if (mounted) setState(() => _mediaState = state);
    } catch (_) {}
  }

  void _showFontPicker() {
    const fonts = ['orbitron', 'bebas', 'audiowide', 'monoton', 'teko', 'poiret'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Clock & Speedometer Font', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              const Text('Select typography for your car HUD', style: TextStyle(fontSize: 13, color: AppColors.textSub)),
              const SizedBox(height: 16),
              ...fonts.map((f) => ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(f.toUpperCase(), style: const TextStyle(color: Colors.white, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                trailing: _activeFont.toLowerCase() == f ? const Icon(Icons.check_circle, color: AppColors.accentTeal) : null,
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
          SnackBar(
            content: const Text('Car browser cache & cookies cleared'),
            backgroundColor: const Color(0xFF16253B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: IndexedStack(
          index: _currentTabIndex,
          children: [
            _buildDeckTab(),
            _buildAppsTab(),
            _buildLayoutTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ==========================================
  // TAB 1: 🚗 DECK (CAR STATUS & LIVE HUB)
  // ==========================================
  Widget _buildDeckTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Top Header
        Row(
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DashMate',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Colors.white),
                ),
                SizedBox(height: 2),
                Text(
                  'Connected Head Unit',
                  style: TextStyle(fontSize: 12, color: AppColors.textSub),
                ),
              ],
            ),
            const Spacer(),
            // Connection Status Pill: Connected / Disconnected
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isCarConnected ? const Color(0x1F5EF2D6) : const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isCarConnected ? const Color(0x405EF2D6) : const Color(0x1FFFFFFF),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isCarConnected ? Icons.circle : Icons.circle_outlined,
                    size: 8,
                    color: _isCarConnected ? const Color(0xFF5EF2D6) : Colors.white38,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isCarConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      color: _isCarConnected ? const Color(0xFF5EF2D6) : Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Premium Obsidian Executive Driver Welcome Card
        InkWell(
          onTap: _showEditDriverNameDialog,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF141C2B), Color(0xFF0C111C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x335EF2D6), width: 1.2),
              boxShadow: const [
                BoxShadow(color: Color(0x145EF2D6), blurRadius: 16, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF8C5C26), Color(0xFFD4B892)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _getDriverInitials(_driverName),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _isCarConnected ? const Color(0xFF5EF2D6) : const Color(0xFFFFB800),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF0C111C), width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DRIVER PROFILE',
                            style: TextStyle(
                              color: AppColors.accentTeal,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _driverName,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.edit_outlined, color: AppColors.accentTeal, size: 16),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x1F5EF2D6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x335EF2D6)),
                      ),
                      child: const Text(
                        'DashMate',
                        style: TextStyle(color: Color(0xFF5EF2D6), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isCarConnected ? Icons.directions_car_filled : Icons.directions_car_outlined,
                      size: 16,
                      color: _isCarConnected ? const Color(0xFF5EF2D6) : Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isCarConnected ? 'Active Android Auto projection · 1190×480' : 'Vehicle disconnected · Ready to connect',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.verified_user_rounded,
                      size: 15,
                      color: _isCarConnected ? const Color(0xFF5EF2D6) : Colors.white38,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),

        const SizedBox(height: 16),

        // Live Car Screen Canvas (Exact live view like in the editor)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tv_rounded, size: 16, color: AppColors.accentTeal),
                      const SizedBox(width: 8),
                      Text(_headUnitName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  Text(_headUnitRes, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                ],
              ),
              const SizedBox(height: 12),

              // Live Display Canvas (Dynamically adapts to Tall Portrait vs Wide Landscape)
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WidgetsScreen())).then((_) {
                  _loadLayout();
                  _loadState();
                }),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: _layoutMode.contains('Tall') ? 340 : 180,
                    ),
                    child: AspectRatio(
                      aspectRatio: _layoutMode.contains('Tall') ? (1080 / 1850) : (1190 / 480),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF060911),
                          borderRadius: BorderRadius.circular(_layoutMode.contains('Tall') ? 22 : 14),
                          border: Border.all(color: const Color(0xFF1E2838), width: 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final int rows = _layoutMode.contains('Tall') ? 18 : 8;
                            final double wUnit = constraints.maxWidth / 12;
                            final double hUnit = constraints.maxHeight / rows;

                            return Stack(
                              children: [
                                // 1. Subtle Background Grid Cells
                                for (int r = 0; r < rows; r++)
                                  for (int c = 0; c < 12; c++)
                                    Positioned(
                                      left: c * wUnit + 1,
                                      top: r * hUnit + 1,
                                      width: wUnit - 2,
                                      height: hUnit - 2,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F1522).withValues(alpha: 0.55),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),

                                // 2. Placed Live Widgets from Editor
                                ..._widgets.map((w) {
                                  final double left = ((w['x'] as int) - 1) * wUnit + 1.5;
                                  final double top = ((w['y'] as int) - 1) * hUnit + 1.5;
                                  final double width = (w['w'] as int) * wUnit - 3;
                                  final double height = (w['h'] as int) * hUnit - 3;

                                  return Positioned(
                                    left: left,
                                    top: top,
                                    width: width,
                                    height: height,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF121824).withValues(alpha: 0.95),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF222C3C)),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: ClipRect(
                                        child: Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.center,
                                            child: _buildMiniWidget(w['id'] as String),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Single Full-Width Action: Edit Widgets
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WidgetsScreen())).then((_) {
                    _loadLayout();
                    _loadState();
                  }),
                  icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.accentTeal),
                  label: const Text('Edit widgets & layout', style: TextStyle(color: AppColors.accentTeal, fontWeight: FontWeight.bold, fontSize: 13)),
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

        const SizedBox(height: 18),

        // Quick Driving Status (Clean 2x2 Grid, Auto-collapse switch removed)
        const Text('Quick Driving Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildGlanceCard(
                icon: Icons.mosque_outlined,
                iconColor: const Color(0xFF14E0C1),
                title: 'Next Prayer',
                subtitle: _prayerTime,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrayerScreen())).then((_) => _loadState()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildGlanceCard(
                icon: Icons.local_parking,
                iconColor: const Color(0xFFBA68C8),
                title: 'Parking Spot',
                subtitle: _parkingSubtitle,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParkingScreen())).then((_) => _loadState()),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildGlanceCard(
                icon: Icons.touch_app_outlined,
                iconColor: const Color(0xFF5EBEFF),
                title: 'Floating Button',
                subtitle: _dockPosition,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ButtonSizeScreen())).then((_) => _loadState()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildGlanceCard(
                icon: Icons.wallpaper_outlined,
                iconColor: const Color(0xFFFFB86C),
                title: 'Car Wallpaper',
                subtitle: _bgMode,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackgroundScreen())).then((_) => _loadState()),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildGlanceCard(
                icon: Icons.play_circle_filled_rounded,
                iconColor: _autoStart ? AppColors.accentTeal : Colors.white38,
                title: 'Auto-Start AA',
                subtitle: _autoStart ? 'Enabled (Auto)' : 'Manual (Tap)',
                onTap: () => _toggleAutoStart(!_autoStart),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildGlanceCard(
                icon: Icons.stay_current_portrait_rounded,
                iconColor: const Color(0xFF5EBEFF),
                title: 'Car Layout',
                subtitle: _layoutMode,
                onTap: _showCarLayoutDialog,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // Mini live widget renderer matching the editor canvas
  Widget _buildMiniWidget(String id) {
    switch (id) {
      case 'clock':
        final timeStr = DateFormat('HH:mm').format(DateTime.now());
        final dateStr = DateFormat('EEE, d MMM').format(DateTime.now());
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(timeStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1)),
                Text(dateStr, style: const TextStyle(fontSize: 8, color: Colors.white70)),
              ],
            ),
          ),
        );
      case 'music':
        final title = _mediaState.title.isNotEmpty ? _mediaState.title : 'Waiting for music...';
        final artist = _mediaState.artist.isNotEmpty ? _mediaState.artist : 'Spotify / YouTube';
        return Padding(
          padding: const EdgeInsets.all(4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                  clipBehavior: Clip.antiAlias,
                  child: _mediaState.coverUrl.isNotEmpty
                      ? Image.network(_mediaState.coverUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.music_note, color: Colors.white54, size: 16))
                      : const Icon(Icons.music_note, color: Colors.white54, size: 16),
                ),
                const SizedBox(width: 6),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1),
                    Text(artist, style: const TextStyle(fontSize: 7, color: Colors.white70), maxLines: 1),
                  ],
                ),
              ],
            ),
          ),
        );
      case 'prayer':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Icon(Icons.mosque_outlined, size: 14, color: Color(0xFF1BE3B0)),
                const SizedBox(width: 4),
                Text(_prayerTime, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        );
      case 'weather':
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(Icons.cloud_outlined, size: 14, color: Color(0xFF5EBEFF)),
                SizedBox(width: 4),
                Text('29°C · Rain', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        );
      case 'speed':
        return const Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('0', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1BE3B0), height: 1.0)),
                Text('km/h', style: TextStyle(fontSize: 7, color: Colors.white54)),
              ],
            ),
          ),
        );
      case 'sports':
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(Icons.sports_soccer, size: 14, color: Color(0xFFFF9800)),
                SizedBox(width: 4),
                Text('EPL · Live Match', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        );
      case 'fuel':
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(Icons.local_gas_station, size: 14, color: Color(0xFF4ADE80)),
                SizedBox(width: 4),
                Text('RON95 RM2.05', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        );
      case 'shortcuts':
        return const Center(
          child: Icon(Icons.apps_rounded, size: 16, color: Colors.white70),
        );
      default:
        return const Center(
          child: Icon(Icons.widgets, size: 16, color: Colors.white38),
        );
    }
  }

  Widget _buildGlanceCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSub), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: 📱 APPS (IN-CAR SERVICES HUB)
  // ==========================================
  Widget _buildAppsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        const Text(
          'In-Car Apps',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          'Apps and services available on your car display',
          style: TextStyle(fontSize: 13, color: AppColors.textSub),
        ),
        const SizedBox(height: 16),

        _buildAppFeatureCard(
          icon: Icons.mosque_outlined,
          iconBg: const Color(0xFF0F3230),
          iconColor: const Color(0xFF14E0C1),
          title: 'Prayer Times (Waktu Solat)',
          subtitle: '$_prayerTime · JAKIM zones & Azan alert chime',
          badge: 'Active',
          badgeColor: const Color(0xFF14E0C1),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrayerScreen())).then((_) => _loadState()),
        ),

        const SizedBox(height: 10),

        _buildAppFeatureCard(
          icon: Icons.public,
          iconBg: const Color(0xFF132A44),
          iconColor: const Color(0xFF5EBEFF),
          title: 'Web Browser & Media',
          subtitle: '$_browseSubtitle · YouTube, desktop mode & fullscreen',
          badge: 'Media',
          badgeColor: const Color(0xFF5EBEFF),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrowseScreen())).then((_) => _loadState()),
        ),

        const SizedBox(height: 10),

        _buildAppFeatureCard(
          icon: Icons.ev_station,
          iconBg: const Color(0xFF163828),
          iconColor: const Color(0xFF4ADE80),
          title: 'Charging & Petrol Stations',
          subtitle: '⚡ Gentari, ChargEV · ⛽ Petronas, Shell · $_customPageSubtitle',
          badge: 'Fuel/EV',
          badgeColor: const Color(0xFF4ADE80),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomPageScreen())).then((_) => _loadState()),
        ),

        const SizedBox(height: 10),

        _buildAppFeatureCard(
          icon: Icons.sports_soccer,
          iconBg: const Color(0xFF3B2514),
          iconColor: const Color(0xFFFF9800),
          title: 'Live Sports Hub',
          subtitle: 'Premier League, Champions League & live score ticker',
          badge: 'Scores',
          badgeColor: const Color(0xFFFF9800),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SportsScreen())).then((_) => _loadState()),
        ),

        const SizedBox(height: 10),

        _buildAppFeatureCard(
          icon: Icons.speaker_notes,
          iconBg: const Color(0xFF381A25),
          iconColor: const Color(0xFFFF6584),
          title: 'Synchronized Lyrics',
          subtitle: 'Floating real-time synced lyrics over car deck',
          badge: 'Music',
          badgeColor: const Color(0xFFFF6584),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LyricsScreen())),
        ),

        const SizedBox(height: 10),

        _buildAppFeatureCard(
          icon: Icons.local_parking,
          iconBg: const Color(0xFF281838),
          iconColor: const Color(0xFFBA68C8),
          title: 'Parking Location Pin',
          subtitle: 'Saved spot at $_parkingSubtitle · Notes & directions',
          badge: 'GPS',
          badgeColor: const Color(0xFFBA68C8),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParkingScreen())).then((_) => _loadState()),
        ),

        const SizedBox(height: 10),

        _buildAppFeatureCard(
          icon: Icons.calendar_today_outlined,
          iconBg: const Color(0xFF1E2838),
          iconColor: const Color(0xFF818CF8),
          title: 'Calendar & Agenda',
          subtitle: 'Daily appointments and driving schedule',
          badge: 'Calendar',
          badgeColor: const Color(0xFF818CF8),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAppFeatureCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSub),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: 🎨 LAYOUT & CAR SCREEN CUSTOMIZER
  // ==========================================
  Widget _buildLayoutTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        const Text(
          'Car Screen Customizer',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          'Fine-tune the layout, buttons and display on your car',
          style: TextStyle(fontSize: 13, color: AppColors.textSub),
        ),
        const SizedBox(height: 18),

        // Group 1: Floating Dock Controls
        const Text('FLOATING CONTROLS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDim, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildSettingTile(
                icon: Icons.touch_app_outlined,
                iconColor: const Color(0xFF5EBEFF),
                title: 'Floating Button & Dock',
                subtitle: '$_dockPosition (${_buttonSize.toInt()}%) · Scale, opacity & idle timer',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ButtonSizeScreen())).then((_) => _loadState()),
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildSettingTile(
                icon: Icons.segment,
                iconColor: const Color(0xFF14E0C1),
                title: 'Car Dock Menu Apps',
                subtitle: 'Choose which 5 apps appear in the floating bar',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FloatingMenuScreen())),
                isLast: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Group 2: Display & Visuals
        const Text('DISPLAY & WIDGETS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDim, letterSpacing: 1.1)),
        const SizedBox(height: 8),
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
                iconColor: const Color(0xFFFFB800),
                title: 'Car Home Widgets',
                subtitle: 'Clock, Speedometer, Weather & Radar placement',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WidgetsScreen())).then((_) {
                  _loadLayout();
                  _loadState();
                }),
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildSettingTile(
                icon: Icons.wallpaper_outlined,
                iconColor: const Color(0xFFBA68C8),
                title: 'Car Wallpaper & Glow',
                subtitle: 'Mode: $_bgMode · Dynamic album glow or AMOLED dark',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackgroundScreen())).then((_) => _loadState()),
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildSettingTile(
                icon: Icons.featured_video_outlined,
                iconColor: const Color(0xFF4ADE80),
                title: 'Car Card (Next to Map)',
                subtitle: 'Mode: $_carCard · Auto-switching card for wide displays',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CarCardScreen())).then((_) => _loadState()),
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildSettingTile(
                icon: Icons.font_download_outlined,
                iconColor: const Color(0xFFFF6584),
                title: 'HUD Typography & Font',
                subtitle: 'Active font: $_activeFont',
                onTap: _showFontPicker,
                isLast: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ==========================================
  // TAB 4: ⚙️ SETTINGS & PREFERENCES
  // ==========================================
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        const Text(
          'Settings & Preferences',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          'Driving units, chime audio and system configuration',
          style: TextStyle(fontSize: 13, color: AppColors.textSub),
        ),
        const SizedBox(height: 18),

        // Android Auto & Car Connection (Top Highlight)
        const Text('ANDROID AUTO & CAR DISPLAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDim, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                secondary: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F352E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.play_circle_filled_rounded, color: AppColors.accentTeal, size: 22),
                ),
                title: const Text('Auto-start on Connect', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text(_autoStart ? 'Opens DashMate automatically when car connects' : 'Quiet mode · Stays on car home until tapped', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                value: _autoStart,
                activeThumbColor: AppColors.accentTeal,
                onChanged: (val) => _toggleAutoStart(val),
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildSettingTile(
                icon: Icons.stay_current_portrait_rounded,
                iconColor: const Color(0xFF5EBEFF),
                title: 'Car Screen Layout',
                subtitle: _layoutMode,
                onTap: _showCarLayoutDialog,
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildSettingTile(
                icon: Icons.keyboard_rounded,
                iconColor: const Color(0xFFBA68C8),
                title: 'Car On-Screen Keyboard',
                subtitle: 'Active · Tap YouTube / search box on car to type',
                onTap: _showKeyboardInfoDialog,
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildSettingTile(
                icon: _themeMode == 'day'
                    ? Icons.light_mode_rounded
                    : _themeMode == 'night'
                        ? Icons.dark_mode_rounded
                        : Icons.brightness_auto,
                iconColor: _themeMode == 'day'
                    ? const Color(0xFFFFB86C)
                    : _themeMode == 'night'
                        ? const Color(0xFFBA68C8)
                        : AppColors.accentTeal,
                title: 'Car Display Theme',
                subtitle: _themeMode == 'day'
                    ? 'Day · Forced light'
                    : _themeMode == 'night'
                        ? 'Night · Forced dark'
                        : 'Auto · Follows headlights',
                onTap: _showThemePicker,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Audio & Chimes
        const Text('AUDIO & CHIMES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDim, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildSettingTile(
                icon: Icons.waving_hand_outlined,
                iconColor: const Color(0xFFFFB86C),
                title: 'Welcome Sound',
                subtitle: '$_welcomeSound chime when Android Auto connects',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WelcomeSoundScreen())).then((_) => _loadState()),
              ),
              const Divider(height: 1, color: Colors.white10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2838),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.music_note, color: Color(0xFF5EF2D6), size: 20),
                ),
                title: const Text('Media Notification Access', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text(_notifGranted ? 'Granted · Syncing title & artist' : 'Tap to grant permission', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                trailing: Icon(_notifGranted ? Icons.check_circle : Icons.warning_amber_rounded, color: _notifGranted ? AppColors.accentTeal : Colors.amber, size: 20),
                onTap: () async {
                  await PlatformChannels.openNotificationAccessSettings();
                  _loadState();
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Regional & Units
        const Text('REGIONAL & UNITS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDim, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                secondary: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2C3D),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.speed, color: Color(0xFF5EBEFF), size: 20),
                ),
                title: const Text('Speedometer Unit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text(_useKmh ? 'Kilometers per hour (km/h)' : 'Miles per hour (mph)', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                value: _useKmh,
                activeThumbColor: AppColors.accentTeal,
                onChanged: (val) {
                  setState(() => _useKmh = val);
                  _channel.invokeMethod('setUnit', {'unit': val ? 'kmh' : 'mph'});
                },
              ),
              const Divider(height: 1, color: Colors.white10),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                secondary: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF281E38),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.access_time, color: Color(0xFFBA68C8), size: 20),
                ),
                title: const Text('24-Hour Time Format', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text(_is24Hour ? '24-hour clock (18:30)' : '12-hour clock (6:30 PM)', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                value: _is24Hour,
                activeThumbColor: AppColors.accentTeal,
                onChanged: (val) {
                  setState(() => _is24Hour = val);
                  _channel.invokeMethod('setTimeFormat', {'format': val ? '24h' : '12h'});
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // System & Maintenance
        const Text('SYSTEM & STORAGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDim, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildSettingTile(
                icon: Icons.cleaning_services_outlined,
                iconColor: const Color(0xFFFF6584),
                title: 'Clear Car Browser Storage',
                subtitle: 'Delete cached cookies & YouTube sign-in session',
                onTap: _clearBrowserCache,
              ),
              const Divider(height: 1, color: Colors.white10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/app_icon.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: const Text('About DashMate', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: const Text('Version 1.0 (Build 30) · Private Edition', style: TextStyle(fontSize: 12, color: AppColors.textSub)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24),
      onTap: onTap,
    );
  }

  // ==========================================
  // BOTTOM NAVIGATION BAR
  // ==========================================
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C101A),
        border: Border(top: BorderSide(color: Color(0x1FFFFFFF), width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.directions_car_rounded, 'Deck'),
              _buildNavItem(1, Icons.grid_view_rounded, 'Apps'),
              _buildNavItem(2, Icons.tune_rounded, 'Layout'),
              _buildNavItem(3, Icons.settings_rounded, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x1F5EF2D6) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.accentTeal : AppColors.textDim,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.accentTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
