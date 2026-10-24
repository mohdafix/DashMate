import 'dart:async';
import 'dart:convert';
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
  String _zoneName = "Kuala Lumpur, Putrajaya";
  bool _showPrayer = true;
  bool _playAzan = true;
  bool _notificationsEnabled = true;
  int _notifyMinutes = 10;

  List<Map<String, String>> _allZones = [];

  final List<Map<String, dynamic>> _times = [
    {"name": "Imsak", "time": "05:39", "status": "passed"},
    {"name": "Subuh", "time": "05:49", "status": "passed"},
    {"name": "Syuruk", "time": "06:56", "status": "passed"},
    {"name": "Dhuha", "time": "07:21", "status": "passed"},
    {"name": "Zohor", "time": "13:00", "status": "now"},
    {"name": "Asar", "time": "16:19", "status": "next"},
    {"name": "Maghrib", "time": "18:59", "status": "future"},
    {"name": "Isyak", "time": "20:10", "status": "future"},
  ];

  @override
  void initState() {
    super.initState();
    _loadZones();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _loadZones() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/zones.json');
      final data = jsonDecode(jsonStr);
      final list = data['zones'] as List<dynamic>?;
      if (list != null) {
        setState(() {
          _allZones = list.map((z) {
            final places = (z['places'] as List<dynamic>?)?.map((p) => p[0].toString()).join(', ') ?? '';
            return {
              "code": z['code'].toString(),
              "name": "${z['state']}: $places",
            };
          }).toList();
        });
      }
    } catch (_) {}
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
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Select Prayer Zone / Zon Solat JAKIM',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _allZones.isNotEmpty ? _allZones.length : 1,
                  itemBuilder: (context, idx) {
                    if (_allZones.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final z = _allZones[idx];
                    final isSel = z['code'] == _zoneCode;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.accentTeal.withValues(alpha: 0.2) : Colors.white10,
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
                      title: Text(z['name']!, style: const TextStyle(fontSize: 13, color: Colors.white)),
                      trailing: isSel ? const Icon(Icons.check, color: AppColors.accentTeal, size: 20) : null,
                      onTap: () {
                        setState(() {
                          _zoneCode = z['code']!;
                          _zoneName = z['name']!.split(':')[1].trim();
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

  void _showQiblaCompass() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16253B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.explore_outlined, color: AppColors.tealAccent),
              SizedBox(width: 8),
              Text('Qibla Compass / Arah Kiblat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.tealAccent.withValues(alpha: 0.4), width: 3),
                ),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.navigation, color: AppColors.tealAccent, size: 72),
                    Positioned(
                      top: 10,
                      child: Text('292° WNW', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Kiblat dari Malaysia: ~292°', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Pastikan GPS diaktifkan dan telefon rata.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup', style: TextStyle(color: AppColors.tealAccent)),
            ),
          ],
        );
      },
    );
  }

  void _showAsmaulHusna() {
    final names = [
      {'ar': 'الرَّحْمَنُ', 'my': 'Ar-Rahman', 'en': 'The Most Gracious'},
      {'ar': 'الرَّحِيمُ', 'my': 'Ar-Rahim', 'en': 'The Most Merciful'},
      {'ar': 'الْمَلِكُ', 'my': 'Al-Malik', 'en': 'The King'},
      {'ar': 'الْقُدُّوسُ', 'my': 'Al-Quddus', 'en': 'The Most Holy'},
      {'ar': 'السَّلاَمُ', 'my': 'As-Salam', 'en': 'The Source of Peace'},
      {'ar': 'الْمُؤْمِنُ', 'my': 'Al-Mu\'min', 'en': 'The Guardian of Faith'},
      {'ar': 'الْمُهَيْمِنُ', 'my': 'Al-Muhaymin', 'en': 'The Protector'},
      {'ar': 'الْعَزِيزُ', 'my': 'Al-Aziz', 'en': 'The Almighty'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16253B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.tealAccent, size: 20),
                  SizedBox(width: 8),
                  Text('Asmaul Husna / 99 Names of Allah', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: names.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, i) {
                    final n = names[i];
                    return ListTile(
                      title: Text(n['my']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      subtitle: Text(n['en']!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      trailing: Text(n['ar']!, style: const TextStyle(fontSize: 20, color: AppColors.tealAccent, fontWeight: FontWeight.bold)),
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
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Prayer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.explore_outlined, color: AppColors.tealAccent),
            tooltip: 'Qibla',
            onPressed: _showQiblaCompass,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.tealAccent),
            tooltip: 'Asmaul Husna',
            onPressed: _showAsmaulHusna,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Selected Zone Pill
          GestureDetector(
            onTap: _showZonePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.accentTeal, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Prayer Zone (JAKIM e-Solat)', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                        const SizedBox(height: 2),
                        Text('$_zoneCode · $_zoneName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.accentTeal),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

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
                        painter: _RadialCountdownPainter(progress: 0.65),
                      ),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('2:45:10', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        'Asar',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accentTeal,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text('16:19', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('in 2h 45m', style: TextStyle(fontSize: 13, color: AppColors.textSub)),
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
                      Text('Gregorian', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                      SizedBox(height: 4),
                      Text('24 October 2026', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Prayer Settings Controls (AutoDeck parity)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.mosque_outlined, color: AppColors.accentTeal),
                  title: const Text('Show prayer times', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  subtitle: const Text('Prayer tab, car Prayer screen, home countdown and greeting', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                  value: _showPrayer,
                  activeColor: AppColors.accentTeal,
                  onChanged: (val) {
                    setState(() => _showPrayer = val);
                    _channel.invokeMethod('setShowPrayer', {'show_prayer': val});
                  },
                ),
                const Divider(height: 1, color: Colors.white10),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up, color: AppColors.accentTeal),
                  title: const Text('Play the azan at prayer times', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  subtitle: const Text('Play the azan at these prayer times (phone notification)', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                  value: _playAzan,
                  activeColor: AppColors.accentTeal,
                  onChanged: (val) => setState(() => _playAzan = val),
                ),
                const Divider(height: 1, color: Colors.white10),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active, color: AppColors.accentTeal),
                  title: const Text('Prayer reminders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  subtitle: Text('Reminder $_notifyMinutes minutes before each prayer time', style: const TextStyle(fontSize: 11, color: AppColors.textSub)),
                  value: _notificationsEnabled,
                  activeColor: AppColors.accentTeal,
                  onChanged: (val) => setState(() => _notificationsEnabled = val),
                ),
              ],
            ),
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
          const SizedBox(height: 20),
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
