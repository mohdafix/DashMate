import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';

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

  static const MethodChannel _browserChannel = MethodChannel('drivedeck/car_browser');

  // Today's times from MainActivity (getPrayerData: JAKIM for the chosen zone). Empty until loaded.
  List<Map<String, dynamic>> _times = [];
  String _currentName = '';
  int _currentEpochMs = 0;
  String _nextName = '';
  String _nextTime = '';
  int _nextEpochMs = 0;


  @override
  void initState() {
    super.initState();
    _loadZones();
    _loadAlertSettings();
    _loadPrayerData();
    _browserChannel.invokeMethod<bool>('getShowPrayer').then((v) {
      if (v != null && mounted) setState(() => _showPrayer = v);
    }).catchError((_) {});
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_rollPrayers);
    });
  }

  Future<void> _loadPrayerData() async {
    try {
      _applyPrayerJson(await _channel.invokeMethod('getPrayerData'));
    } catch (_) {}
  }

  /// Reads the JSON from getPrayerData / setPrayerZone: times[], current, next, zone "CODE · name".
  void _applyPrayerJson(Object? raw) {
    if (raw is! String || !mounted) return;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return;
      final times = (m['times'] as List?)
              ?.whereType<Map>()
              .map((e) => <String, dynamic>{
                    'name': (e['name'] ?? '').toString(),
                    'time': (e['time'] ?? '').toString(),
                    'epochMs': (e['epochMs'] as num?)?.toInt() ?? 0,
                  })
              .toList() ??
          [];
      final cur = m['current'], next = m['next'];
      setState(() {
        if (times.isNotEmpty) _times = times;
        if (cur is Map) {
          _currentName = (cur['name'] ?? '').toString();
          _currentEpochMs = (cur['epochMs'] as num?)?.toInt() ?? 0;
        }
        if (next is Map) {
          _nextName = (next['name'] ?? '').toString();
          _nextTime = (next['time'] ?? '').toString();
          _nextEpochMs = (next['epochMs'] as num?)?.toInt() ?? 0;
        }
        final zone = (m['zone'] ?? '').toString();
        final i = zone.indexOf(' · ');
        if (i > 0) {
          _zoneCode = zone.substring(0, i);
          _zoneName = zone.substring(i + 3);
        }
      });
    } catch (_) {}
  }

  /// Moves on to the next prayer when its time passes (the 1 s timer calls this).
  void _rollPrayers() {
    if (_nextEpochMs <= 0 || DateTime.now().millisecondsSinceEpoch < _nextEpochMs) return;
    final upcoming = _times.where((p) => (p['epochMs'] as int) > _nextEpochMs).toList();
    _currentName = _nextName;
    _currentEpochMs = _nextEpochMs;
    if (upcoming.isNotEmpty) {
      _nextName = upcoming.first['name'] as String;
      _nextTime = upcoming.first['time'] as String;
      _nextEpochMs = upcoming.first['epochMs'] as int;
    } else {
      _nextEpochMs = 0;
      _loadPrayerData(); // after Isyak: tomorrow's Subuh comes from MainActivity
    }
  }

  String get _countdown {
    if (_nextEpochMs <= 0) return '--:--';
    final d = Duration(milliseconds: max(0, _nextEpochMs - DateTime.now().millisecondsSinceEpoch));
    return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String get _countdownWords {
    if (_nextEpochMs <= 0) return '';
    final d = Duration(milliseconds: max(0, _nextEpochMs - DateTime.now().millisecondsSinceEpoch));
    return d.inHours > 0 ? 'in ${d.inHours}h ${d.inMinutes % 60}m' : 'in ${max(1, d.inMinutes)}m';
  }

  double get _progress {
    final span = _nextEpochMs - _currentEpochMs;
    if (_nextEpochMs <= 0 || _currentEpochMs <= 0 || span <= 0) return 0;
    return ((DateTime.now().millisecondsSinceEpoch - _currentEpochMs) / span).clamp(0.0, 1.0);
  }


  static String _gregorianToday() {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'];
    final d = DateTime.now();
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _loadAlertSettings() async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('getPrayerAlerts');
      if (m != null && mounted) {
        setState(() {
          _playAzan = m['azan'] as bool? ?? true;
          _notificationsEnabled = m['remind'] as bool? ?? true;
          _notifyMinutes = m['minutes'] as int? ?? 10;
        });
      }
    } catch (_) {}
  }

  void _saveAlertSettings() {
    _channel.invokeMethod('setPrayerAlerts', {
      'azan': _playAzan,
      'remind': _notificationsEnabled,
      'minutes': _notifyMinutes,
    });
  }

  void _pickReminderMinutes() async {
    final t = context.tokens;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: t.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Remind me before each prayer', style: TextStyle(fontWeight: FontWeight.bold, color: t.ink)),
            ),
            for (final m in const [5, 10, 15, 20, 30])
              ListTile(
                title: Text('$m minutes', style: TextStyle(color: t.ink)),
                trailing: m == _notifyMinutes ? Icon(Icons.check, color: t.accent) : null,
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _notifyMinutes = picked);
      _saveAlertSettings();
    }
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
    final t = context.tokens;
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Select Prayer Zone / Zon Solat JAKIM',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.ink),
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
                          color: isSel ? t.accent.withValues(alpha: 0.12) : t.surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? t.accent : Colors.transparent),
                        ),
                        child: Text(
                          z['code']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSel ? t.accent : t.ink2,
                          ),
                        ),
                      ),
                      title: Text(z['name']!, style: TextStyle(fontSize: 13, color: t.ink)),
                      trailing: isSel ? Icon(Icons.check, color: t.accent, size: 20) : null,
                      onTap: () {
                        setState(() {
                          _zoneCode = z['code']!;
                          _zoneName = z['name']!.split(':')[1].trim();
                        });
                        Navigator.pop(ctx);
                        _channel
                            .invokeMethod('setPrayerZone', {'zone': z['code']})
                            .then(_applyPrayerJson)
                            .catchError((_) {});
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
        final t = context.tokens;
        return AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.explore_outlined, color: t.accent),
              const SizedBox(width: 8),
              Text('Qibla Compass / Arah Kiblat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.ink)),
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
                  border: Border.all(color: t.accent.withValues(alpha: 0.4), width: 3),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.navigation, color: t.accent, size: 72),
                    Positioned(
                      top: 10,
                      child: Text('292° WNW', style: TextStyle(fontWeight: FontWeight.bold, color: t.ink, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Kiblat dari Malaysia: ~292°', style: TextStyle(color: t.ink2, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Pastikan GPS diaktifkan dan telefon rata.', style: TextStyle(color: t.ink3, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Tutup', style: TextStyle(color: t.accent)),
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
      backgroundColor: context.tokens.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final t = context.tokens;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: t.accent, size: 20),
                  const SizedBox(width: 8),
                  Text('Asmaul Husna / 99 Names of Allah', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.ink)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: names.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: t.border),
                  itemBuilder: (context, i) {
                    final n = names[i];
                    return ListTile(
                      title: Text(n['my']!, style: TextStyle(fontWeight: FontWeight.bold, color: t.ink)),
                      subtitle: Text(n['en']!, style: TextStyle(color: t.ink2, fontSize: 12)),
                      trailing: Text(n['ar']!, style: TextStyle(fontSize: 20, color: t.accent, fontWeight: FontWeight.bold)),
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
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: t.ink),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text('Prayer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: t.ink)),
        actions: [
          IconButton(
            icon: Icon(Icons.explore_outlined, color: t.accent),
            tooltip: 'Qibla',
            onPressed: _showQiblaCompass,
          ),
          IconButton(
            icon: Icon(Icons.auto_awesome, color: t.accent),
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
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.border),
                boxShadow: t.cardShadow,
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: t.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Prayer Zone (JAKIM e-Solat)', style: TextStyle(fontSize: 11, color: t.ink2)),
                        const SizedBox(height: 2),
                        Text('$_zoneCode · $_zoneName', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: t.ink)),
                      ],
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: t.accent),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Top Radial Countdown Card (Matches Screenshot 4)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border),
              boxShadow: t.cardShadow,
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
                        painter: _RadialCountdownPainter(progress: _progress, track: t.surface2, arc: t.accent),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_countdown, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.ink)),
                          const SizedBox(height: 2),
                          Text('remaining', style: TextStyle(fontSize: 11, color: t.ink2)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Next Prayer Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Next prayer', style: TextStyle(fontSize: 13, color: t.ink2)),
                      const SizedBox(height: 4),
                      Text(
                        _nextName.isEmpty ? '—' : _nextName,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: t.accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(_nextTime, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: t.ink)),
                      const SizedBox(height: 2),
                      Text(_countdownWords, style: TextStyle(fontSize: 13, color: t.ink2)),
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
                    color: t.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.border),
                    boxShadow: t.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hijri', style: TextStyle(fontSize: 11, color: t.ink2)),
                      const SizedBox(height: 4),
                      Text(hijriDate(DateTime.now()), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: t.ink)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.border),
                    boxShadow: t.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gregorian', style: TextStyle(fontSize: 11, color: t.ink2)),
                      const SizedBox(height: 4),
                      Text(_gregorianToday(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: t.ink)),
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
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border),
              boxShadow: t.cardShadow,
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.mosque_outlined, color: t.accent),
                  title: Text('Show prayer times', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink)),
                  subtitle: Text('Prayer tab, car Prayer screen, home countdown and greeting', style: TextStyle(fontSize: 11, color: t.ink2)),
                  value: _showPrayer,
                  onChanged: (val) {
                    setState(() => _showPrayer = val);
                    _browserChannel.invokeMethod('setShowPrayer', {'show_prayer': val});
                  },
                ),
                Divider(height: 1, color: t.border),
                SwitchListTile(
                  secondary: Icon(Icons.volume_up, color: t.accent),
                  title: Text('Alert at prayer time', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink)),
                  subtitle: Text('In the car: chime + "Telah masuk waktu …" through the car speakers (music dips, then resumes). On the phone: a notification. Tap the 🕌 tile in the car for the nearest masjid.', style: TextStyle(fontSize: 11, color: t.ink2)),
                  value: _playAzan,
                  onChanged: (val) {
                    setState(() => _playAzan = val);
                    _saveAlertSettings();
                  },
                ),
                Divider(height: 1, color: t.border),
                SwitchListTile(
                  secondary: Icon(Icons.notifications_active, color: t.accent),
                  title: Text('Prayer reminders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink)),
                  subtitle: Text('Spoken reminder $_notifyMinutes minutes before each prayer time', style: TextStyle(fontSize: 11, color: t.ink2)),
                  value: _notificationsEnabled,
                  onChanged: (val) {
                    setState(() => _notificationsEnabled = val);
                    _saveAlertSettings();
                  },
                ),
                if (_notificationsEnabled)
                  ListTile(
                    leading: Icon(Icons.timer_outlined, color: t.accent),
                    title: Text('Remind me', style: TextStyle(fontSize: 14, color: t.ink)),
                    trailing: Text('$_notifyMinutes min before', style: TextStyle(fontSize: 12, color: t.accent)),
                    onTap: _pickReminderMinutes,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Full Prayer Timetable List Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border),
              boxShadow: t.cardShadow,
            ),
            child: Column(
              children: _times.map((item) {
                final isNow = item['name'] == _currentName;
                final isNext = item['name'] == _nextName && item['epochMs'] == _nextEpochMs;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isNow ? t.accent.withValues(alpha: 0.10) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isNow || isNext ? t.accent : t.border,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        item['name'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isNow || isNext ? FontWeight.bold : FontWeight.w500,
                          color: isNow ? t.accent : t.ink,
                        ),
                      ),
                      const Spacer(),
                      if (isNow)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text('now', style: TextStyle(fontSize: 12, color: t.accent, fontWeight: FontWeight.w600)),
                        ),
                      if (isNext)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text('next', style: TextStyle(fontSize: 12, color: t.accent, fontWeight: FontWeight.w600)),
                        ),
                      Text(
                        item['time'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isNow ? t.accent : t.ink,
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
  final Color track;
  final Color arc;

  _RadialCountdownPainter({required this.progress, required this.track, required this.arc});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final bgPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    final arcPaint = Paint()
      ..color = arc
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
  bool shouldRepaint(covariant _RadialCountdownPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.track != track || oldDelegate.arc != arc;
}

/// Today's Hijri date by the tabular Islamic calendar (may differ by a day from the
/// official moon-sighting date).
String hijriDate(DateTime g) {
  const months = ['Muharram', 'Safar', 'Rabiulawal', 'Rabiulakhir', 'Jamadilawal', 'Jamadilakhir',
    'Rejab', 'Syaaban', 'Ramadan', 'Syawal', 'Zulkaedah', 'Zulhijjah'];
  final int y = g.year, m = g.month, d = g.day;
  final int a = (m - 14) ~/ 12;
  final int jd = (1461 * (y + 4800 + a)) ~/ 4 + (367 * (m - 2 - 12 * a)) ~/ 12 -
      (3 * ((y + 4900 + a) ~/ 100)) ~/ 4 + d - 32075;
  int l = jd - 1948440 + 10632;
  final int n = (l - 1) ~/ 10631;
  l = l - 10631 * n + 354;
  final int j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) + (l ~/ 5670) * ((43 * l) ~/ 15238);
  l = l - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) - (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
  final int hm = (24 * l) ~/ 709;
  final int hd = l - (709 * hm) ~/ 24;
  final int hy = 30 * n + j - 30;
  return '$hd ${months[hm - 1]} $hy';
}
