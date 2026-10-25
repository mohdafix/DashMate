import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';
import '../theme/localization.dart';

class ParkingScreen extends StatefulWidget {
  const ParkingScreen({super.key});

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  static const _channel = MethodChannel('com.dashmate.dashmate/channel');
  final TextEditingController _bayController = TextEditingController();
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  Map<dynamic, dynamic>? _savedSpot;
  Timer? _timer;
  String _elapsedString = '';
  String _parkedTimeStr = '';
  bool _autoPark = true;

  @override
  void initState() {
    super.initState();
    _loadSpot();
    _channel.invokeMethod<bool>('getAutoPark').then((v) {
      if (v != null && mounted) setState(() => _autoPark = v);
    }).catchError((_) {});
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _updateElapsed());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bayController.dispose();
    _levelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadSpot() async {
    try {
      final raw = await _channel.invokeMethod('getParkingSpot');
      // MainActivity answers with a JSON string (or null when nothing is saved).
      final res = raw is String ? jsonDecode(raw) : raw;
      if (!mounted) return;
      if (res != null && res is Map) {
        setState(() {
          _savedSpot = res;
          _bayController.text = res['bay'] ?? '';
          _levelController.text = res['level'] ?? '';
          _notesController.text = res['notes'] ?? '';
          final int ts = (res['timestamp'] as num?)?.toInt() ?? 0;
          if (ts > 0) {
            final d = DateTime.fromMillisecondsSinceEpoch(ts);
            final hour = d.hour.toString().padLeft(2, '0');
            final min = d.minute.toString().padLeft(2, '0');
            _parkedTimeStr = '$hour:$min';
          }
        });
        _updateElapsed();
      } else {
        setState(() {
          _savedSpot = null;
          _parkedTimeStr = '';
          _elapsedString = '';
        });
      }
    } catch (_) {}
  }

  void _updateElapsed() {
    if (_savedSpot == null) {
      setState(() => _elapsedString = '');
      return;
    }
    final int timestamp = (_savedSpot!['timestamp'] as num?)?.toInt() ?? 0;
    if (timestamp == 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestamp;
    if (diff < 0) return;

    final hours = diff ~/ (1000 * 60 * 60);
    final minutes = (diff % (1000 * 60 * 60)) ~/ (1000 * 60);

    setState(() {
      if (hours > 0) {
        _elapsedString = '${hours}h ${minutes}m';
      } else {
        _elapsedString = '${minutes}m';
      }
    });
  }

  void _saveCurrentLocation() async {
    try {
      // No lat/lng: MainActivity uses the phone's current location.
      await _channel.invokeMethod('saveParkingSpot', {
        'bay': _bayController.text.trim(),
        'level': _levelController.text.trim(),
        'notes': _notesController.text.trim(),
      });
      _loadSpot();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parking location saved & synced with car screen!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'no_permission'
          ? 'Allow DashMate to use your location, then tap Save again.'
          : 'Can\'t find your location yet. Turn on location (GPS) and try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
      );
    } catch (_) {}
  }

  void _removeParkingSpot() async {
    try {
      await _channel.invokeMethod('clearParkingSpot');
      _loadSpot();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parking spot removed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {}
  }

  void _walkThereWithGoogleMaps() async {
    try {
      final ok = await _channel.invokeMethod('navigateParking');
      if (ok == false && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save your parking spot first.'), duration: Duration(seconds: 2)),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasSpot = _savedSpot != null;
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.get('parking'),
          style: TextStyle(fontWeight: FontWeight.w600, color: t.ink),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AutoDeck-style Disconnect Explanation Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.border),
                boxShadow: t.cardShadow,
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: t.accent, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'DashMate saves where you parked when Android Auto disconnects, and clears it when you drive away. You can also save it here.',
                      style: TextStyle(fontSize: 12, color: t.ink2, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text('Save automatically when the car disconnects', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink)),
              subtitle: Text('Uses your last location while DashMate Deck was open in the car. Shows a "Car parked" notification with a timer and Navigate back.', style: TextStyle(fontSize: 11, color: t.ink2)),
              value: _autoPark,
              onChanged: (v) {
                setState(() => _autoPark = v);
                _channel.invokeMethod('setAutoPark', {'enabled': v});
              },
            ),

            const SizedBox(height: 12),

            // Active Spot Card or Empty State
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasSpot ? t.accent.withValues(alpha: 0.5) : t.border,
                ),
                boxShadow: t.cardShadow,
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (hasSpot ? t.accent : t.ink3).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.local_parking,
                              color: hasSpot ? t.accent : t.ink3,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasSpot ? 'Parked at $_parkedTimeStr' : 'No parking spot yet',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: t.ink),
                              ),
                              if (hasSpot && _elapsedString.isNotEmpty)
                                Text(
                                  'Parked for $_elapsedString',
                                  style: TextStyle(color: t.accent, fontSize: 12),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (hasSpot)
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: t.danger),
                          tooltip: 'Remove parking spot',
                          onPressed: _removeParkingSpot,
                        ),
                    ],
                  ),

                  if (hasSpot) ...[
                    const SizedBox(height: 16),
                    Divider(height: 1, color: t.border),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            'Level / Floor',
                            _savedSpot!['level']?.toString().isNotEmpty == true ? _savedSpot!['level'] : '–',
                          ),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            'Bay Number',
                            _savedSpot!['bay']?.toString().isNotEmpty == true ? _savedSpot!['bay'] : '–',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      'Pillar / Notes',
                      _savedSpot!['notes']?.toString().isNotEmpty == true ? _savedSpot!['notes'] : 'saved when the car disconnected',
                    ),
                    const SizedBox(height: 20),

                    // Walk There with Google Maps Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.accent,
                          foregroundColor: t.onAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _walkThereWithGoogleMaps,
                        icon: const Icon(Icons.directions_walk, size: 22),
                        label: const Text(
                          'Walk there with Google Maps',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'Save Parking Spot',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: t.ink2),
            ),
            const SizedBox(height: 12),

            // Form Inputs Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.border),
                boxShadow: t.cardShadow,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _levelController,
                          style: TextStyle(color: t.ink, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Level / Floor',
                            labelStyle: TextStyle(color: t.ink2, fontSize: 13),
                            hintText: 'e.g. Level 3A',
                            hintStyle: TextStyle(color: t.ink3),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.accent, width: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _bayController,
                          style: TextStyle(color: t.ink, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Bay Number',
                            labelStyle: TextStyle(color: t.ink2, fontSize: 13),
                            hintText: 'e.g. B-14',
                            hintStyle: TextStyle(color: t.ink3),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.accent, width: 1.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesController,
                    style: TextStyle(color: t.ink, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Pillar / Notes',
                      labelStyle: TextStyle(color: t.ink2, fontSize: 13),
                      hintText: 'e.g. Near Pillar 24, Lift Lobby B',
                      hintStyle: TextStyle(color: t.ink3),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.accent, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: t.accent),
                        foregroundColor: t.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saveCurrentLocation,
                      icon: const Icon(Icons.my_location, size: 20),
                      label: const Text(
                        'Save current location as parked',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: t.ink3, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(color: t.ink, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }
}
