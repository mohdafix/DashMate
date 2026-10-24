import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/weather_service.dart';
import '../theme/app_colors.dart';

class CustomPageScreen extends StatefulWidget {
  const CustomPageScreen({super.key});

  @override
  State<CustomPageScreen> createState() => _CustomPageScreenState();
}

class _CustomPageScreenState extends State<CustomPageScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');
  String _selectedMode = "weather";
  WeatherData? _weatherData;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _modes = [
    {
      "id": "weather",
      "title": "Weather",
      "desc": "Forecast, rain radar and air quality, full screen",
      "icon": Icons.wb_sunny_outlined,
    },
    {
      "id": "calendar",
      "title": "Calendar",
      "desc": "Month and your next 7 days of events",
      "icon": Icons.calendar_month_outlined,
    },
    {
      "id": "sports",
      "title": "Sports",
      "desc": "Live scores and today's games",
      "icon": Icons.emoji_events_outlined,
    },
    {
      "id": "radar",
      "title": "Rain radar",
      "desc": "Big live rain map around you",
      "icon": Icons.radar_outlined,
    },
    {
      "id": "ev",
      "title": "EV charging",
      "desc": "Nearest chargers: plugs, power, distance",
      "icon": Icons.ev_station_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  void _loadWeather() async {
    setState(() => _isLoading = true);
    final data = await WeatherService.fetchWeather();
    if (mounted) {
      setState(() {
        _weatherData = data;
        _isLoading = false;
      });
    }
  }

  void _selectMode(String id) {
    setState(() => _selectedMode = id);
    _channel.invokeMethod('setCarPage', {'page': id});
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
    final w = _weatherData ?? WeatherData.initial();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Custom page', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              WeatherService.fetchWeather(forceRefresh: true).then((val) {
                if (mounted) setState(() => _weatherData = val);
              });
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Live Dynamic Weather & Radar Preview Card
          Container(
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
            child: _isLoading
                ? const SizedBox(
                    height: 140,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accentTeal),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Real Temp + Condition + Air Quality
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${w.temp.round()}°',
                                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      _getWeatherIcon(w.weatherCode, w.isDay),
                                      size: 30,
                                      color: AppColors.accentTeal,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  w.condition,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Feels like ${w.apparentTemp.round()}° · UV ${w.uvIndex.round()}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSub),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    w.rainSummary,
                                    style: const TextStyle(fontSize: 11, color: AppColors.accentTeal),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // AQI & Radar Map Box
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text('Air quality ', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                                    Text(
                                      '${w.aqi} ',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _getAqiColor(w.aqi)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getAqiColor(w.aqi).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        w.aqiCategory,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: _getAqiColor(w.aqi),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Rain Radar Canvas / Map
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
                                        child: Text(
                                          'Rain radar · ${w.radarTime}',
                                          style: const TextStyle(fontSize: 9, color: Colors.white70),
                                        ),
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
                      // Dynamic Hourly Forecast Strip
                      if (w.hourly.isNotEmpty)
                        SizedBox(
                          height: 58,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: w.hourly.length,
                            itemBuilder: (ctx, idx) {
                              final h = w.hourly[idx];
                              return _buildHourlyItem(
                                h.time,
                                _getWeatherIcon(h.weatherCode, h.isDay),
                                '${h.temp.round()}°',
                              );
                            },
                          ),
                        ),
                    ],
                  ),
          ),

          const SizedBox(height: 10),

          // Verbatim source attribution from AutoDeck
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'For your prayer zone. Forecast and air quality from Open-Meteo, radar from RainViewer (updates every 10 min). Free, no account.',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),

          const SizedBox(height: 20),

          // "Shows on the car" section title
          const Text(
            'Shows on the car',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),

          // Selection Grid
          GridView.builder(
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
              final isSel = _selectedMode == m['id'];

              return GestureDetector(
                onTap: () => _selectMode(m['id']),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSel ? AppColors.accentTeal : AppColors.border,
                      width: isSel ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(m['icon'], color: AppColors.accentTeal, size: 24),
                          if (isSel)
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accentTeal,
                              ),
                              child: const Icon(Icons.check, size: 14, color: Colors.black),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(m['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
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
          ),

          const SizedBox(height: 24),
        ],
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
          Text(temp, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
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

    // Simulated rain blip
    final rainPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.4), 16, rainPaint);
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.6), 12, rainPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
