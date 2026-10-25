import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSpot();
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
      final res = await _channel.invokeMethod('getParkingSpot');
      if (res != null && res is Map) {
        setState(() {
          _savedSpot = res;
          _bayController.text = res['bay'] ?? '';
          _levelController.text = res['level'] ?? '';
          _notesController.text = res['notes'] ?? '';
          final int ts = res['timestamp'] ?? 0;
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
    final int timestamp = _savedSpot!['timestamp'] ?? 0;
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
      await _channel.invokeMethod('saveParkingSpot', {
        'lat': 3.1390,
        'lng': 101.6869,
        'bay': _bayController.text.trim(),
        'level': _levelController.text.trim(),
        'notes': _notesController.text.trim(),
      });
      _loadSpot();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.cardSurface,
            content: Text('Parking location saved & synced with car screen!', style: TextStyle(color: AppColors.tealAccent)),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  void _removeParkingSpot() async {
    try {
      await _channel.invokeMethod('clearParkingSpot');
      _loadSpot();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.cardSurface,
            content: Text('Parking spot removed', style: TextStyle(color: Colors.white70)),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {}
  }

  void _walkThereWithGoogleMaps() async {
    try {
      await _channel.invokeMethod('navigateBackToCar');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasSpot = _savedSpot != null;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.get('parking'),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Disconnect Explanation Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.tealAccent, size: 24),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'DashMate saves where you parked when Android Auto disconnects, and clears it when you drive away. You can also save it here.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Active Spot Card or Empty State
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasSpot
                      ? [const Color(0xFF132D3F), const Color(0xFF0F1E2E)]
                      : [AppColors.cardSurface, const Color(0xFF0D1422)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasSpot ? AppColors.tealAccent.withValues(alpha: 0.5) : AppColors.glassBorder,
                ),
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
                              color: (hasSpot ? AppColors.tealAccent : AppColors.textMuted).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.local_parking,
                              color: hasSpot ? AppColors.tealAccent : AppColors.textMuted,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasSpot ? 'Parked at $_parkedTimeStr' : 'No parking spot yet',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                              ),
                              if (hasSpot && _elapsedString.isNotEmpty)
                                Text(
                                  'Parked for $_elapsedString',
                                  style: const TextStyle(color: AppColors.tealAccent, fontSize: 12),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (hasSpot)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Remove parking spot',
                          onPressed: _removeParkingSpot,
                        ),
                    ],
                  ),

                  if (hasSpot) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.glassBorder),
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
                          backgroundColor: AppColors.tealAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
            const Text(
              'Save Parking Spot',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),

            // Form Inputs Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _levelController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Level / Floor',
                            labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            hintText: 'e.g. Level 3A',
                            hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.glassBorder)),
                            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.tealAccent)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _bayController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Bay Number',
                            labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            hintText: 'e.g. B-14',
                            hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.glassBorder)),
                            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.tealAccent)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Pillar / Notes',
                      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      hintText: 'e.g. Near Pillar 24, Lift Lobby B',
                      hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.glassBorder)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.tealAccent)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.tealAccent),
                        foregroundColor: AppColors.tealAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }
}
