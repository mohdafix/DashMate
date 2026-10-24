import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');
  Timer? _timer;

  String _zoneCode = "WLY01";
  String _zoneName = "Putrajaya";

  final List<Map<String, String>> _zones = [
    {"code": "WLY01", "name": "Kuala Lumpur, Putrajaya"},
    {"code": "SGR01", "name": "Shah Alam, Petaling, Gombak"},
    {"code": "JHR02", "name": "Johor Bahru, Kota Tinggi"},
    {"code": "PNG01", "name": "Pulau Pinang"},
    {"code": "PRK02", "name": "Ipoh, Batu Gajah, Kampar"},
    {"code": "MLK01", "name": "Melaka"},
    {"code": "NSN01", "name": "Seremban, Port Dickson"},
    {"code": "KDH01", "name": "Alor Setar, Kota Setar"},
    {"code": "TRG01", "name": "Kuala Terengganu, Marang"},
    {"code": "KTN01", "name": "Kota Bharu, Bachok"},
    {"code": "PLS01", "name": "Kangar, Perlis"},
    {"code": "PHG02", "name": "Kuantan, Pekan"},
    {"code": "SBH01", "name": "Kota Kinabalu, Ranau"},
    {"code": "SWK01", "name": "Kuching, Bau, Lundu"}
  ];

  final List<Map<String, dynamic>> _times = [
    {"name": "Imsak", "time": "05:39", "status": "passed"},
    {"name": "Subuh", "time": "05:49", "status": "now"},
    {"name": "Syuruk", "time": "06:56", "status": "passed"},
    {"name": "Dhuha", "time": "07:21", "status": "passed"},
    {"name": "Zohor", "time": "13:00", "status": "next"},
    {"name": "Asar", "time": "16:19", "status": "future"},
    {"name": "Maghrib", "time": "18:59", "status": "future"},
    {"name": "Isyak", "time": "20:10", "status": "future"},
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showZonePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.mosque, color: AppColors.accentTeal, size: 20),
                    SizedBox(width: 10),
                    Text('Select Prayer Zone (JAKIM)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(color: AppColors.border),
              Expanded(
                child: ListView.builder(
                  itemCount: _zones.length,
                  itemBuilder: (ctx, i) {
                    final z = _zones[i];
                    final isSel = _zoneCode == z['code'];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.accentTeal.withValues(alpha: 0.15) : Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? AppColors.accentTeal : Colors.transparent),
                        ),
                        child: Text(
                          z['code']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSel ? AppColors.accentTeal : Colors.white70,
                          ),
                        ),
                      ),
                      title: Text(z['name']!, style: const TextStyle(fontSize: 14)),
                      trailing: isSel ? const Icon(Icons.check, color: AppColors.accentTeal, size: 20) : null,
                      onTap: () {
                        setState(() {
                          _zoneCode = z['code']!;
                          _zoneName = z['name']!.split(',')[0].trim();
                        });
                        Navigator.pop(ctx);
                        _channel.invokeMethod('setPrayerZone', {'zone': z['code']});
                      },
                    );
                  },
                ),
              ),
            ],
          ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Prayer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [
          GestureDetector(
            onTap: _showZonePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.accentTeal, size: 16),
                  const SizedBox(width: 4),
                  Text(_zoneName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Top Radial Countdown Card (Matches Screenshot 4)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Circular Progress Dial
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(120, 120),
                        painter: _RadialCountdownPainter(progress: 0.45),
                      ),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('5:29:20', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('remaining', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Next Prayer Details
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Next prayer', style: TextStyle(fontSize: 13, color: AppColors.textSub)),
                      SizedBox(height: 4),
                      Text(
                        'Zohor',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accentTeal,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text('13:00', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('in 5h 29m', style: TextStyle(fontSize: 13, color: AppColors.textSub)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Dual Date Cards (Hijri & Gregorian)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hijri', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                      SizedBox(height: 4),
                      Text('13 Jamadilawal 1448', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saturday', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                      SizedBox(height: 4),
                      Text('24 October 2026', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Full Prayer Timetable List Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: _times.map((item) {
                final isNow = item['status'] == 'now';
                final isNext = item['status'] == 'next';

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isNow ? AppColors.accentTeal.withValues(alpha: 0.16) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isNow || isNext ? AppColors.accentTeal : Colors.white24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        item['name'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isNow || isNext ? FontWeight.bold : FontWeight.w500,
                          color: isNow ? AppColors.accentTeal : Colors.white,
                        ),
                      ),
                      const Spacer(),
                      if (isNow)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Text('now', style: TextStyle(fontSize: 12, color: AppColors.accentTeal, fontWeight: FontWeight.w600)),
                        ),
                      if (isNext)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Text('next', style: TextStyle(fontSize: 12, color: AppColors.accentTeal, fontWeight: FontWeight.w600)),
                        ),
                      Text(
                        item['time'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isNow ? AppColors.accentTeal : Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialCountdownPainter extends CustomPainter {
  final double progress;

  _RadialCountdownPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    final arcPaint = Paint()
      ..color = AppColors.accentTeal
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialCountdownPainter oldDelegate) => oldDelegate.progress != progress;
}
