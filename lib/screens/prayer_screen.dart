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
  String _hijriDate = "13 Jamadilawal 1448";
  String _gregorianDate = "";

  bool _showPrayer = true;
  int _remindMinutes = 0; // 0 = Off, 5, 10, 15, 20, 30
  Set<String> _azanPrayers = {"Subuh", "Zohor", "Asar", "Maghrib", "Isyak"};

  String _nextPrayerName = "Asar";
  String _nextPrayerTime = "16:19";
  int _nextPrayerEpochMs = 0;

  List<Map<String, String>> _allZones = [];

  List<Map<String, dynamic>> _times = [
    {"name": "Imsak", "time": "05:39", "status": "passed", "epochMs": 0},
    {"name": "Subuh", "time": "05:49", "status": "passed", "epochMs": 0},
    {"name": "Syuruk", "time": "06:56", "status": "passed", "epochMs": 0},
    {"name": "Dhuha", "time": "07:21", "status": "passed", "epochMs": 0},
    {"name": "Zohor", "time": "13:00", "status": "passed", "epochMs": 0},
    {"name": "Asar", "time": "16:19", "status": "next", "epochMs": 0},
    {"name": "Maghrib", "time": "18:59", "status": "future", "epochMs": 0},
    {"name": "Isyak", "time": "20:10", "status": "future", "epochMs": 0},
  ];

  final List<String> _fardPrayers = const ["Subuh", "Zohor", "Asar", "Maghrib", "Isyak"];
  final List<int> _reminderOptions = const [0, 5, 10, 15, 20, 30];

  @override
  void initState() {
    super.initState();
    _loadZones();
    _loadAlertSettings();
    _fetchLivePrayerData();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadZones() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/zones.json');
      final data = jsonDecode(jsonStr);
      final list = data['zones'] as List<dynamic>?;
      if (list != null && mounted) {
        setState(() {
          _allZones = list.map((z) {
            final places = (z['places'] as List<dynamic>?)?.map((p) => p[0].toString()).join(', ') ?? '';
            return {
              "code": z['code'].toString(),
              "name": "${z['state']}: $places",
              "places": places,
            };
          }).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAlertSettings() async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('getPrayerAlerts');
      if (m != null && mounted) {
        setState(() {
          _showPrayer = m['showPrayer'] as bool? ?? true;
          _remindMinutes = m['remindMinutes'] as int? ?? 0;
          final azanList = (m['azanPrayers'] as List<dynamic>?)?.map((e) => e.toString()).toList();
          if (azanList != null) {
            _azanPrayers = azanList.toSet();
          }
        });
      }
    } catch (_) {}
  }

  void _saveAlertSettings() {
    _channel.invokeMethod('setPrayerAlerts', {
      'showPrayer': _showPrayer,
      'azanPrayers': _azanPrayers.toList(),
      'remindMinutes': _remindMinutes,
    });
  }

  Future<void> _fetchLivePrayerData() async {
    try {
      final res = await _channel.invokeMethod<String>('getPrayerData');
      if (res != null && mounted) {
        final data = jsonDecode(res) as Map<String, dynamic>;
        _updateFromPrayerJson(data);
      }
    } catch (_) {}
  }

  void _updateFromPrayerJson(Map<String, dynamic> data) {
    setState(() {
      if (data['zone'] != null) _zoneCode = data['zone'].toString();
      if (data['zoneName'] != null) _zoneName = data['zoneName'].toString();
      if (data['hijri'] != null) _hijriDate = data['hijri'].toString();
      if (data['gregorian'] != null) _gregorianDate = data['gregorian'].toString();

      final nextObj = data['next'] as Map<String, dynamic>?;
      if (nextObj != null) {
        _nextPrayerName = nextObj['name']?.toString() ?? "Asar";
        _nextPrayerTime = nextObj['time']?.toString() ?? "16:19";
        _nextPrayerEpochMs = (nextObj['epochMs'] as num?)?.toInt() ?? 0;
      }

      final timesArr = data['times'] as List<dynamic>?;
      if (timesArr != null && timesArr.isNotEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch;
        _times = timesArr.map((item) {
          final m = Map<String, dynamic>.from(item as Map);
          final pEpoch = (m['epochMs'] as num?)?.toInt() ?? 0;
          String status = "future";
          if (pEpoch <= now) {
            status = "passed";
          }
          if (m['name'] == _nextPrayerName) {
            status = "next";
          }
          return {
            "name": m['name'] ?? "",
            "time": m['time'] ?? "",
            "status": status,
            "epochMs": pEpoch,
          };
        }).toList();
      }
    });
  }

  String _formatCountdown() {
    if (_nextPrayerEpochMs <= 0) return "00:00:00";
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = _nextPrayerEpochMs - now;
    if (diff <= 0) return "00:00:00";

    final totalSeconds = (diff / 1000).floor();
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    final seconds = totalSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatCountdownShort() {
    if (_nextPrayerEpochMs <= 0) return "";
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = _nextPrayerEpochMs - now;
    if (diff <= 0) return "now";

    final totalMins = (diff / 60000).floor();
    final hours = (totalMins / 60).floor();
    final mins = totalMins % 60;

    if (hours > 0) {
      return 'in ${hours}h ${mins}m';
    }
    return 'in ${mins}m';
  }

  void _showZonePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16253B),
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
                      onTap: () async {
                        setState(() {
                          _zoneCode = z['code']!;
                          _zoneName = z['places'] ?? z['name']!;
                        });
                        Navigator.pop(ctx);
                        final res = await _channel.invokeMethod('setPrayerZone', {'zone': z['code']});
                        if (res != null) {
                          try {
                            _updateFromPrayerJson(jsonDecode(res.toString()));
                          } catch (_) {}
                        }
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

  @override
  Widget build(BuildContext context) {
    final countdownStr = _formatCountdown();
    final countdownShort = _formatCountdownShort();

    return Scaffold(
      backgroundColor: const Color(0xFF0C101A),
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
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 1. Top Radial Countdown Card (Matches Screenshot 2)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131A26),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1E2838)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(120, 120),
                        painter: _RadialCountdownPainter(progress: 0.68),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(countdownStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 2),
                          const Text('remaining', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Next prayer', style: TextStyle(fontSize: 13, color: AppColors.textSub)),
                      const SizedBox(height: 4),
                      Text(
                        _nextPrayerName,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accentTeal,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(_nextPrayerTime, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(countdownShort, style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2. Dual Date Cards (Hijri & Gregorian)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A26),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E2838)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hijri', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                      const SizedBox(height: 4),
                      Text(_hijriDate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A26),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E2838)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gregorian', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
                      const SizedBox(height: 4),
                      Text(
                        _gregorianDate.isNotEmpty ? _gregorianDate : "${DateTime.now().day} October ${DateTime.now().year}",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3. Show Prayer Times Switch Card (Matches Screenshot 1 & 2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF131A26),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E2838)),
            ),
            child: Row(
              children: [
                const Icon(Icons.mosque_outlined, color: Colors.white70, size: 24),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Show prayer times', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 3),
                      Text(
                        'Prayer tab, car Prayer screen, home countdown and prayer in the greeting',
                        style: TextStyle(fontSize: 12, color: AppColors.textSub, height: 1.25),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _showPrayer,
                  activeThumbColor: AppColors.accentTeal,
                  onChanged: (val) {
                    setState(() => _showPrayer = val);
                    _saveAlertSettings();
                    _channel.invokeMethod('setShowPrayer', {'show_prayer': val});
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Prayer Zones Header & Card (Matches Screenshot 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Prayer zones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                InkWell(
                  onTap: _showZonePicker,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('+ Add zone', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.accentTeal)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Selected Zone Card (Matches Screenshot 1)
          InkWell(
            onTap: _showZonePicker,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF131A26),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E2838)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accentTeal, width: 2.5),
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentTeal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_zoneName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('$_zoneCode · $_zoneName', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 5. Prayer Reminder Dropdown Card (Matches Screenshot 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF131A26),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E2838)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_none_outlined, color: Colors.white70, size: 22),
                const SizedBox(width: 12),
                const Text('Prayer reminder', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _remindMinutes,
                    dropdownColor: const Color(0xFF1A2333),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    items: _reminderOptions.map((min) {
                      return DropdownMenuItem<int>(
                        value: min,
                        child: Text(min == 0 ? 'Off' : '$min min before'),
                      );
                    }).toList(),
                    onChanged: (newVal) {
                      if (newVal != null) {
                        setState(() => _remindMinutes = newVal);
                        _saveAlertSettings();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 6. Azan Prayer Selection Card (Matches Screenshot 1 & 3)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131A26),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E2838)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.volume_up_outlined, color: Colors.white70, size: 22),
                    SizedBox(width: 10),
                    Text('Azan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Play the azan at these prayer times (phone notification).',
                  style: TextStyle(fontSize: 12, color: AppColors.textSub, height: 1.3),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _fardPrayers.map((prayer) {
                    final bool isChecked = _azanPrayers.contains(prayer);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isChecked) {
                            _azanPrayers.remove(prayer);
                          } else {
                            _azanPrayers.add(prayer);
                          }
                        });
                        _saveAlertSettings();
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isChecked ? const Color(0xFF1B3D37) : const Color(0xFF182232),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isChecked ? AppColors.accentTeal : const Color(0xFF28364A),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isChecked) ...[
                              const Icon(Icons.check, size: 16, color: AppColors.accentTeal),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              prayer,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isChecked ? Colors.white : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 7. Full Prayer Timetable List Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF131A26),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E2838)),
            ),
            child: Column(
              children: _times.map((item) {
                final isNext = item['status'] == 'next';

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isNext ? AppColors.accentTeal.withValues(alpha: 0.16) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isNext ? AppColors.accentTeal : Colors.white24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        item['name'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
                          color: isNext ? AppColors.accentTeal : Colors.white,
                        ),
                      ),
                      const Spacer(),
                      if (isNext)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Text('next', style: TextStyle(fontSize: 12, color: AppColors.accentTeal, fontWeight: FontWeight.bold)),
                        ),
                      Text(
                        item['time'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isNext ? AppColors.accentTeal : Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
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
