import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../channels/platform_channels.dart';
import '../core/weather_service.dart';
import '../theme/app_colors.dart';
import 'football_settings_screen.dart';

class CustomPageScreen extends StatefulWidget {
  const CustomPageScreen({super.key});

  @override
  State<CustomPageScreen> createState() => _CustomPageScreenState();
}

class _CustomPageScreenState extends State<CustomPageScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');
  static const MethodChannel _permsChannel = MethodChannel('drivedeck/permissions');

  // Multi-item selection: which items are enabled to show on the car display
  Set<String> _enabledModes = {'weather'};

  // Currently focused item for top preview & options underneath
  String _focusedMode = 'weather';

  // Sub-tabs in previews
  String _sportsTab = 'games'; // 'games', 'my_teams', 'table'
  String _calTab = 'week'; // 'day', 'week', 'month'

  // Weather data
  WeatherData? _weatherData;
  bool _isLoadingWeather = true;

  // Calendar access state
  bool _hasCalendarAccess = false;

  // Sports config filters
  bool _filterFootball = true;
  bool _filterMotorsport = true;

  // Weather config
  bool _tempInCelsius = true;
  bool _airAlerts = true;

  // Radar config
  String _radarRange = '100 km';

  // EV config
  bool _evCcs2 = true;
  bool _evType2 = true;
  bool _evChademo = false;
  String _evRadius = '10 km';

  final List<Map<String, dynamic>> _modes = [
    {
      'id': 'weather',
      'title': 'Weather',
      'desc': 'Forecast, rain radar and air quality, full screen',
      'icon': Icons.wb_sunny_outlined,
    },
    {
      'id': 'calendar',
      'title': 'Calendar',
      'desc': 'Month and your next 7 days of events',
      'icon': Icons.calendar_month_outlined,
    },
    {
      'id': 'sports',
      'title': 'Sports',
      'desc': "Live scores and today's games",
      'icon': Icons.emoji_events_outlined,
    },
    {
      'id': 'radar',
      'title': 'Rain radar',
      'desc': 'Big live rain map around you',
      'icon': Icons.radar_outlined,
    },
    {
      'id': 'ev',
      'title': 'EV charging',
      'desc': 'Nearest chargers: plugs, power, distance',
      'icon': Icons.ev_station_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedModes();
    _loadWeather();
    _checkCalendarAccess();
  }

  Future<void> _loadSavedModes() async {
    try {
      final res = await _channel.invokeMethod<String>('getCustomPageMode');
      if (res != null && res.isNotEmpty && mounted) {
        final items = res.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
        if (items.isNotEmpty) {
          setState(() {
            _enabledModes = items;
            _focusedMode = items.first;
          });
          return;
        }
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('custom_page_modes');
      if (saved != null && saved.isNotEmpty && mounted) {
        final items = saved.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
        if (items.isNotEmpty) {
          setState(() {
            _enabledModes = items;
            _focusedMode = items.first;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveModes() async {
    final modeStr = _enabledModes.join(',');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_page_modes', modeStr);
      await prefs.setString('customPage', modeStr);
    } catch (_) {}
    try {
      await PlatformChannels.setCustomPageMode(modeStr);
    } catch (_) {}
  }

  Future<void> _checkCalendarAccess() async {
    try {
      final granted = await _permsChannel.invokeMethod<bool>('checkCalendar') ??
          await _channel.invokeMethod<bool>('checkCalendar') ?? false;
      if (mounted) setState(() => _hasCalendarAccess = granted);
    } catch (_) {}
  }

  Future<void> _requestCalendarAccess() async {
    try {
      await _permsChannel.invokeMethod('requestCalendarPermission');
    } catch (_) {
      try {
        await _channel.invokeMethod('requestCalendarPermission');
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 600));
    _checkCalendarAccess();
  }

  Future<void> _loadWeather({bool force = false}) async {
    setState(() => _isLoadingWeather = true);
    final data = await WeatherService.fetchWeather(forceRefresh: force);
    if (mounted) {
      setState(() {
        _weatherData = data;
        _isLoadingWeather = false;
      });
    }
  }

  void _toggleMode(String id) {
    setState(() {
      _focusedMode = id;
      if (_enabledModes.contains(id)) {
        if (_enabledModes.length > 1) {
          _enabledModes.remove(id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('At least one item must remain selected for the car display.'),
              backgroundColor: Color(0xFF16253B),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        _enabledModes.add(id);
      }
    });
    _saveModes();
  }

  void _focusMode(String id) {
    setState(() {
      _focusedMode = id;
      if (!_enabledModes.contains(id)) {
        _enabledModes.add(id);
      }
    });
    _saveModes();
  }

  IconData _getWeatherIcon(int code, int isDay) {
    if (code == 0) return isDay == 1 ? Icons.wb_sunny : Icons.nightlight_round;
    if (code == 1 || code == 2) return isDay == 1 ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined;
    if (code == 3) return Icons.cloud;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 51 && code <= 55) return Icons.grain;
    if (code >= 61 && code <= 82) return Icons.water_drop;
    if (code >= 95) return Icons.flash_on;
    return Icons.cloud_queue;
  }

  Color _getAqiColor(int aqi) {
    if (aqi <= 50) return AppColors.accentTeal;
    if (aqi <= 100) return const Color(0xFFF1C40F);
    if (aqi <= 150) return const Color(0xFFE67E22);
    return AppColors.accentRed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Custom page', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              _loadWeather(force: true);
              _checkCalendarAccess();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 1. Dynamic Top Preview Card based on focused item
          _buildDynamicPreviewCard(),

          const SizedBox(height: 24),

          // 2. "Shows on the car" section title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Shows on the car',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_enabledModes.length} selected',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentTeal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose which to display on the car screen. Tap an item to preview and configure.',
            style: TextStyle(fontSize: 12, color: AppColors.textSub),
          ),
          const SizedBox(height: 14),

          // 3. Selection Grid (Weather, Calendar, Sports, Rain radar, EV charging)
          _buildModesGrid(),

          const SizedBox(height: 24),

          // 4. Options Underneath to Config (Matching Screenshots)
          _buildFocusedConfigSection(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==========================================
  // TOP DYNAMIC PREVIEW CARD
  // ==========================================
  Widget _buildDynamicPreviewCard() {
    switch (_focusedMode) {
      case 'sports':
        return _buildSportsPreview();
      case 'radar':
        return _buildRadarPreview();
      case 'calendar':
        return _buildCalendarPreview();
      case 'ev':
        return _buildEvPreview();
      case 'weather':
      default:
        return _buildWeatherPreview();
    }
  }

  // --- Sports Preview (Matching Screenshot 1) ---
  Widget _buildSportsPreview() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D251D), Color(0xFF091410)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with segmented tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Row(
                children: [
                  _buildSubTabPill('Games', _sportsTab == 'games', () => setState(() => _sportsTab = 'games')),
                  const SizedBox(width: 4),
                  _buildSubTabPill('My teams', _sportsTab == 'my_teams', () => setState(() => _sportsTab = 'my_teams')),
                  const SizedBox(width: 4),
                  _buildSubTabPill('Table', _sportsTab == 'table', () => setState(() => _sportsTab = 'table')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Games columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Malaysia Super League
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Malaysia Super League', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                    const SizedBox(height: 6),
                    _buildGameCard(
                      team1: 'Kuching',
                      score: '1 - 0',
                      badge: 'FT',
                      team2: 'Kuala Lumpur',
                    ),
                    const SizedBox(height: 6),
                    _buildGameCard(
                      team1: 'Selangor',
                      score: '6 - 0',
                      badge: 'FT',
                      team2: 'PDRM',
                      icon1: Icons.shield_rounded,
                      icon2: Icons.shield_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Column 2: Formula 1
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Formula 1', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'MSC Cruises United States GP',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Final', style: TextStyle(fontSize: 9, color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required String team1,
    required String score,
    required String badge,
    required String team2,
    IconData? icon1,
    IconData? icon2,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon1 != null) Icon(icon1, size: 13, color: const Color(0xFFF1C40F)),
              if (icon1 != null) const SizedBox(width: 4),
              Text(team1, style: const TextStyle(fontSize: 11, color: Colors.white)),
            ],
          ),
          Column(
            children: [
              Text(score, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                child: Text(badge, style: const TextStyle(fontSize: 8, color: Colors.white70)),
              ),
            ],
          ),
          Row(
            children: [
              Text(team2, style: const TextStyle(fontSize: 11, color: Colors.white)),
              if (icon2 != null) const SizedBox(width: 4),
              if (icon2 != null) Icon(icon2, size: 13, color: const Color(0xFF5EBEFF)),
            ],
          ),
        ],
      ),
    );
  }

  // --- Rain Radar Preview (Matching Screenshot 2) ---
  Widget _buildRadarPreview() {
    final nowStr = DateFormat('HH:mm').format(DateTime.now());
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Map canvas with satellite & radar tiles simulation
          Positioned.fill(
            child: CustomPaint(painter: _FullRadarMapPainter()),
          ),
          // Top bar timestamp
          Positioned(
            left: 14,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Rain radar · $nowStr',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          // Center GPS locator
          const Center(
            child: Icon(Icons.my_location, size: 20, color: AppColors.accentTeal),
          ),
          // Rain intensity legend at bottom
          Positioned(
            bottom: 10,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text('Rain: ', style: TextStyle(fontSize: 9, color: Colors.white70)),
                  Container(width: 10, height: 6, color: Colors.lightBlueAccent),
                  Container(width: 10, height: 6, color: Colors.greenAccent),
                  Container(width: 10, height: 6, color: Colors.yellowAccent),
                  Container(width: 10, height: 6, color: Colors.orangeAccent),
                  Container(width: 10, height: 6, color: Colors.redAccent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Weather Preview (Matching Screenshot 3) ---
  Widget _buildWeatherPreview() {
    final w = _weatherData ?? WeatherData.initial();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2E4A), Color(0xFF121B2D)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: _isLoadingWeather
          ? const SizedBox(
              height: 140,
              child: Center(child: CircularProgressIndicator(color: AppColors.accentTeal)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('${w.temp.round()}°', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(width: 8),
                              Icon(_getWeatherIcon(w.weatherCode, w.isDay), size: 30, color: AppColors.accentTeal),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(w.condition, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('Feels like ${w.apparentTemp.round()}° · UV ${w.uvIndex.round()} · H ${(w.temp + 2).round()}° L ${(w.temp - 3).round()}°', style: const TextStyle(fontSize: 11, color: AppColors.textSub)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                            child: Text(w.rainSummary, style: const TextStyle(fontSize: 11, color: AppColors.accentTeal)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text('Air quality ', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                              Text('${w.aqi} ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _getAqiColor(w.aqi))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getAqiColor(w.aqi).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(w.aqiCategory, style: TextStyle(fontSize: 9, color: _getAqiColor(w.aqi), fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 140,
                            height: 75,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1E2E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: 0.8,
                                    child: CustomPaint(painter: _RadarWavesPainter()),
                                  ),
                                ),
                                Positioned(
                                  left: 6,
                                  top: 4,
                                  child: Text('Rain radar · ${w.radarTime}', style: const TextStyle(fontSize: 9, color: Colors.white70)),
                                ),
                                const Center(
                                  child: Icon(Icons.my_location, size: 14, color: AppColors.accentTeal),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (w.hourly.isNotEmpty)
                  SizedBox(
                    height: 58,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: w.hourly.length,
                      itemBuilder: (ctx, idx) {
                        final h = w.hourly[idx];
                        return _buildHourlyItem(h.time, _getWeatherIcon(h.weatherCode, h.isDay), '${h.temp.round()}°');
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  // --- Calendar Preview (Matching Screenshot 4) ---
  Widget _buildCalendarPreview() {
    final now = DateTime.now();
    final monthYear = DateFormat('MMMM yyyy').format(now);
    final dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final monday = now.subtract(Duration(days: now.weekday - 1));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141F32), Color(0xFF0E1522)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text('${now.day}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(monthYear, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(
                        _hasCalendarAccess ? 'Synced · Next 7 days' : 'Allow calendar access in DashMate',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSub),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  _buildSubTabPill('Day', _calTab == 'day', () => setState(() => _calTab = 'day')),
                  const SizedBox(width: 4),
                  _buildSubTabPill('Week', _calTab == 'week', () => setState(() => _calTab = 'week')),
                  const SizedBox(width: 4),
                  _buildSubTabPill('Month', _calTab == 'month', () => setState(() => _calTab = 'month')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 7-day columns
          Row(
            children: List.generate(7, (i) {
              final d = monday.add(Duration(days: i));
              final isToday = d.day == now.day && d.month == now.month;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.accentTeal.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isToday ? AppColors.accentTeal : Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Text(dayNames[i], style: const TextStyle(fontSize: 9, color: AppColors.textSub)),
                      const SizedBox(height: 4),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isToday ? AppColors.accentTeal : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- EV Charging Preview ---
  Widget _buildEvPreview() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2626), Color(0xFF091414)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('EV charging', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Nearest chargers', style: TextStyle(fontSize: 11, color: AppColors.accentTeal)),
            ],
          ),
          const SizedBox(height: 10),
          _buildEvStationTile('Shell Recharge Pavilion KL', '1.2 km', 'CCS2 (50 kW) · Type 2 (22 kW)', true),
          const SizedBox(height: 6),
          _buildEvStationTile('ChargEV Menara Maybank', '3.5 km', 'CCS2 (50 kW) · 2 of 4 free', true),
          const SizedBox(height: 6),
          _buildEvStationTile('BHPetrol Sungai Besi', '3.2 km', 'Infiniti 95 / 97 · Diesel · AC 22kW', false),
        ],
      ),
    );
  }

  Widget _buildEvStationTile(String name, String dist, String plugs, bool isEv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(isEv ? Icons.ev_station : Icons.local_gas_station, color: isEv ? AppColors.accentTeal : const Color(0xFFFFB86C), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(plugs, style: const TextStyle(fontSize: 10, color: AppColors.textSub)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
            child: Text(dist, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabPill(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.accentTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SELECTION GRID (SHOWS ON THE CAR)
  // ==========================================
  Widget _buildModesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemCount: _modes.length,
      itemBuilder: (ctx, i) {
        final m = _modes[i];
        final id = m['id'] as String;
        final isEnabled = _enabledModes.contains(id);
        final isFocused = _focusedMode == id;

        return GestureDetector(
          onTap: () => _focusMode(id),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isFocused
                    ? AppColors.accentTeal
                    : (isEnabled ? AppColors.accentTeal.withValues(alpha: 0.5) : AppColors.border),
                width: isFocused ? 2.0 : (isEnabled ? 1.5 : 1.0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(m['icon'], color: isFocused || isEnabled ? AppColors.accentTeal : Colors.white70, size: 24),
                    // Tappable checkmark toggle for "Shows on the car"
                    GestureDetector(
                      onTap: () => _toggleMode(id),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isEnabled ? AppColors.accentTeal : Colors.transparent,
                          border: Border.all(
                            color: isEnabled ? AppColors.accentTeal : Colors.white30,
                            width: 1.5,
                          ),
                        ),
                        child: isEnabled
                            ? const Icon(Icons.check, size: 16, color: Colors.black)
                            : null,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(m['title'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 3),
                Text(
                  m['desc'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSub, height: 1.2),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // OPTIONS UNDERNEATH TO CONFIG (PER SCREENSHOTS)
  // ==========================================
  Widget _buildFocusedConfigSection() {
    switch (_focusedMode) {
      case 'sports':
        return _buildSportsConfig();
      case 'calendar':
        return _buildCalendarConfig();
      case 'radar':
        return _buildRadarConfig();
      case 'ev':
        return _buildEvConfig();
      case 'weather':
      default:
        return _buildWeatherConfig();
    }
  }

  // --- Sports Config (Matching Screenshot 1) ---
  Widget _buildSportsConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
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
              const Text('Sport', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildConfigFilterChip(
                    label: 'Football · 2',
                    selected: _filterFootball,
                    onTap: () => setState(() => _filterFootball = !_filterFootball),
                  ),
                  const SizedBox(width: 8),
                  _buildConfigFilterChip(
                    label: 'Motorsport · 1',
                    selected: _filterMotorsport,
                    onTap: () => setState(() => _filterMotorsport = !_filterMotorsport),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.glassBorder),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.settings_outlined, color: AppColors.accentTeal, size: 22),
                title: const Text('Football & Scores Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('Followed leagues, favourite teams & API key', style: TextStyle(fontSize: 12, color: AppColors.textSub)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textDim),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FootballSettingsScreen())),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Calendar Config (Matching Screenshot 4) ---
  Widget _buildCalendarConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Calendar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_today_rounded, color: AppColors.accentTeal, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Allow calendar access', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 3),
                        Text(
                          'Shows your next 7 days of events on the car. Read-only: DashMate never changes your calendar.',
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasCalendarAccess ? const Color(0xFF1E2E4A) : AppColors.accentTeal,
                      foregroundColor: _hasCalendarAccess ? AppColors.accentTeal : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _hasCalendarAccess ? null : _requestCalendarAccess,
                    child: Text(
                      _hasCalendarAccess ? 'Synced' : 'Allow',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.glassBorder),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Default Car View', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  Row(
                    children: [
                      _buildConfigFilterChip(label: 'Day', selected: _calTab == 'day', onTap: () => setState(() => _calTab = 'day')),
                      const SizedBox(width: 6),
                      _buildConfigFilterChip(label: 'Week', selected: _calTab == 'week', onTap: () => setState(() => _calTab = 'week')),
                      const SizedBox(width: 6),
                      _buildConfigFilterChip(label: 'Month', selected: _calTab == 'month', onTap: () => setState(() => _calTab = 'month')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Weather Config (Matching Screenshot 3) ---
  Widget _buildWeatherConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Weather', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
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
              Text(
                'For your prayer zone. Forecast and air quality from Open-Meteo, radar from RainViewer (updates every 10 min). Free, no account.',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65), height: 1.4),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.glassBorder),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Temperature in Celsius (°C)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: Text(_tempInCelsius ? 'Metric unit (°C)' : 'Fahrenheit (°F)', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                value: _tempInCelsius,
                activeThumbColor: AppColors.accentTeal,
                onChanged: (val) => setState(() => _tempInCelsius = val),
              ),
              const Divider(height: 1, color: AppColors.glassBorder),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Air Quality Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('Alerts if AQI reaches Unhealthy levels', style: TextStyle(fontSize: 12, color: AppColors.textSub)),
                value: _airAlerts,
                activeThumbColor: AppColors.accentTeal,
                onChanged: (val) => setState(() => _airAlerts = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Rain Radar Config (Matching Screenshot 2) ---
  Widget _buildRadarConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rain radar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
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
              Text(
                'For your prayer zone. Forecast and air quality from Open-Meteo, radar from RainViewer (updates every 10 min). Free, no account.',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65), height: 1.4),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.glassBorder),
              const SizedBox(height: 12),
              const Text('Radar Zoom Range', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildConfigFilterChip(label: '50 km', selected: _radarRange == '50 km', onTap: () => setState(() => _radarRange = '50 km')),
                  const SizedBox(width: 8),
                  _buildConfigFilterChip(label: '100 km', selected: _radarRange == '100 km', onTap: () => setState(() => _radarRange = '100 km')),
                  const SizedBox(width: 8),
                  _buildConfigFilterChip(label: '250 km', selected: _radarRange == '250 km', onTap: () => setState(() => _radarRange = '250 km')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- EV Config ---
  Widget _buildEvConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('EV charging', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
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
              const Text('Plug & Connector Types', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildConfigFilterChip(label: 'CCS2', selected: _evCcs2, onTap: () => setState(() => _evCcs2 = !_evCcs2)),
                  const SizedBox(width: 8),
                  _buildConfigFilterChip(label: 'Type 2', selected: _evType2, onTap: () => setState(() => _evType2 = !_evType2)),
                  const SizedBox(width: 8),
                  _buildConfigFilterChip(label: 'Chademo', selected: _evChademo, onTap: () => setState(() => _evChademo = !_evChademo)),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.glassBorder),
              const SizedBox(height: 12),
              const Text('Search Radius', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildConfigFilterChip(label: '5 km', selected: _evRadius == '5 km', onTap: () => setState(() => _evRadius = '5 km')),
                  const SizedBox(width: 8),
                  _buildConfigFilterChip(label: '10 km', selected: _evRadius == '10 km', onTap: () => setState(() => _evRadius = '10 km')),
                  const SizedBox(width: 8),
                  _buildConfigFilterChip(label: '25 km', selected: _evRadius == '25 km', onTap: () => setState(() => _evRadius = '25 km')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentTeal.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accentTeal : Colors.white12,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) const Icon(Icons.check, size: 14, color: AppColors.accentTeal),
            if (selected) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyItem(String time, IconData icon, String temp) {
    return Container(
      width: 52,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(time, style: const TextStyle(fontSize: 10, color: AppColors.textSub)),
          const SizedBox(height: 2),
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(height: 2),
          Text(temp, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

// Map painter for live rain radar preview
class _FullRadarMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width * 0.5, size.height * 0.5);
    canvas.drawCircle(center, 30, ringPaint);
    canvas.drawCircle(center, 65, ringPaint);
    canvas.drawCircle(center, 100, ringPaint);

    // Simulated radar cloud bands
    final rain1 = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.45, size.height * 0.35), 45, rain1);

    final rain2 = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.48, size.height * 0.38), 28, rain2);

    final rain3 = Paint()
      ..color = Colors.yellowAccent.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.52, size.height * 0.42), 16, rain3);

    final rain4 = Paint()
      ..color = Colors.orangeAccent.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.65), 32, rain4);

    final rain5 = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.77, size.height * 0.67), 18, rain5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RadarWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentTeal.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 12, paint);
    canvas.drawCircle(center, 24, paint);
    canvas.drawCircle(center, 36, paint);

    final rainPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.4), 16, rainPaint);
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.6), 12, rainPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
