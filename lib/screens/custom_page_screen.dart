import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class CustomPageScreen extends StatefulWidget {
  const CustomPageScreen({super.key});

  @override
  State<CustomPageScreen> createState() => _CustomPageScreenState();
}

class _CustomPageScreenState extends State<CustomPageScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');
  String _selectedMode = "weather";

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

  void _selectMode(String id) {
    setState(() => _selectedMode = id);
    _channel.invokeMethod('setCarPage', {'page': id});
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Top Weather & Radar Preview Card (Matches Screenshot 1)
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: 24Â° Drizzle + Air Quality 160
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('24Â°', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              const Icon(Icons.cloud_queue, size: 28, color: Colors.white70),
                            ],
                          ),
                          const Text('Drizzle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          const Text('Feels like 30Â° Â· UV 0', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Raining Â· stops in ~45 min', style: TextStyle(fontSize: 11, color: AppColors.accentTeal)),
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
                              const Text('160 ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accentRed)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentRed.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('Unhealthy', style: TextStyle(fontSize: 9, color: AppColors.accentRed, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Simulated Rain Radar Canvas / Map
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
                                const Positioned(
                                  left: 6,
                                  top: 4,
                                  child: Text('Rain radar Â· 07:20', style: TextStyle(fontSize: 9, color: Colors.white70)),
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
                // Hourly Forecast Strip
                SizedBox(
                  height: 58,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildHourlyItem('Now', Icons.cloud, '24Â°'),
                      _buildHourlyItem('08:00', Icons.cloud_queue, '25Â°'),
                      _buildHourlyItem('09:00', Icons.grain, '26Â°'),
                      _buildHourlyItem('10:00', Icons.wb_sunny_outlined, '26Â°'),
                      _buildHourlyItem('11:00', Icons.wb_sunny_outlined, '27Â°'),
                      _buildHourlyItem('12:00', Icons.wb_sunny_outlined, '28Â°'),
                      _buildHourlyItem('13:00', Icons.cloud_queue, '29Â°'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // "Shows on the car" section title
          const Text(
            'Shows on the car',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),

          // Selection Grid (Matches Screenshot 1)
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
                        style: const TextStyle(fontSize: 11, color: AppColors.textSub, height: 1.2),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Note Card at Bottom (Matches Screenshot 1)
          const Text('Weather', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'For your prayer zone. Forecast and air quality from Open-Meteo, radar from RainViewer (updates every 10 min). Free, no account.',
              style: TextStyle(fontSize: 13, color: AppColors.textSub, height: 1.4),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHourlyItem(String time, IconData icon, String temp) {
    return Container(
      width: 50,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(time, style: const TextStyle(fontSize: 10, color: AppColors.textSub)),
          Icon(icon, size: 16, color: Colors.white70),
          Text(temp, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RadarWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    final p2 = Paint()
      ..color = const Color(0xFFFFEB3B).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.5), 24, p1);
    canvas.drawCircle(Offset(size.width * 0.45, size.height * 0.55), 14, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
