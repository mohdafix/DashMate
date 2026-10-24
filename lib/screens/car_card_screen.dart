import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/localization.dart';

class CarCardScreen extends StatefulWidget {
  const CarCardScreen({super.key});

  @override
  State<CarCardScreen> createState() => _CarCardScreenState();
}

class _CarCardScreenState extends State<CarCardScreen> {
  static const _channel = MethodChannel('com.dashmate.dashmate/channel');
  String _selectedMode = 'music';

  final List<Map<String, dynamic>> _cardOptions = [
    {
      'id': 'music',
      'title': 'Now Playing Music',
      'subtitle': 'Displays dynamic album artwork, synchronized title and artist in Android Auto side-card.',
      'icon': Icons.music_note,
      'color': AppColors.tealAccent,
    },
    {
      'id': 'prayer',
      'title': 'Waktu Solat JAKIM',
      'subtitle': 'Live prayer countdown meter, current and upcoming prayer times next to navigation map.',
      'icon': Icons.access_time_filled,
      'color': const Color(0xFF10B981),
    },
    {
      'id': 'weather',
      'title': 'Weather & Rain Radar',
      'subtitle': 'RainViewer precipitation mini-radar, real-time temperature, and air quality index.',
      'icon': Icons.cloudy_snowing,
      'color': const Color(0xFF3B82F6),
    },
    {
      'id': 'sports',
      'title': 'Sports & Football',
      'subtitle': 'Live Premier League, Champions League and match scores updated during your journey.',
      'icon': Icons.sports_soccer,
      'color': const Color(0xFFF59E0B),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCardMode();
  }

  void _loadCardMode() async {
    try {
      final res = await _channel.invokeMethod('getCarCardMode');
      if (res != null && mounted) {
        setState(() {
          _selectedMode = res.toString();
        });
      }
    } catch (_) {}
  }

  void _selectMode(String id) async {
    setState(() {
      _selectedMode = id;
    });
    try {
      await _channel.invokeMethod('setCarCardMode', {'mode': id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.cardSurface,
            content: Text('Car card set to ${_cardOptions.firstWhere((e) => e['id'] == id)['title']}', style: const TextStyle(color: AppColors.tealAccent)),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.get('car_card'),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Explanatory Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.dashboard_customize, color: AppColors.tealAccent, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Android Auto Split-Screen Card',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Select which widget is served by CarArtProvider to Android Auto dashboard side-card.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Select Active Card',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cardOptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final opt = _cardOptions[index];
                final isSelected = opt['id'] == _selectedMode;

                return InkWell(
                  onTap: () => _selectMode(opt['id']),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.tealAccent : AppColors.glassBorder,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (opt['color'] as Color).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(opt['icon'] as IconData, color: opt['color'] as Color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt['title'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isSelected ? AppColors.tealAccent : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                opt['subtitle'] as String,
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Radio<String>(
                          value: opt['id'] as String,
                          groupValue: _selectedMode,
                          activeColor: AppColors.tealAccent,
                          onChanged: (val) {
                            if (val != null) _selectMode(val);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
