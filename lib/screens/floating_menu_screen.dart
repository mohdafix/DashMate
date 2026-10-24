import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/localization.dart';

class FloatingMenuScreen extends StatefulWidget {
  const FloatingMenuScreen({super.key});

  @override
  State<FloatingMenuScreen> createState() => _FloatingMenuScreenState();
}

class _FloatingMenuScreenState extends State<FloatingMenuScreen> {
  static const _channel = MethodChannel('com.dashmate.dashmate/channel');

  final List<Map<String, String>> _allAvailableShortcuts = [
    {'name': 'YouTube', 'url': 'https://m.youtube.com', 'icon': 'dd_youtube.png'},
    {'name': 'RTM Klik', 'url': 'https://rtmklik.rtm.gov.my', 'icon': 'dd_rtm.png'},
    {'name': 'Google', 'url': 'https://www.google.com', 'icon': 'https://www.google.com/favicon.ico'},
    {'name': 'Waze', 'url': 'https://www.waze.com/live-map', 'icon': 'https://www.waze.com/favicon.ico'},
    {'name': 'Parking', 'url': 'dashmate://parking', 'icon': 'assets/icons/parking.svg'},
    {'name': 'Waktu Solat', 'url': 'dashmate://prayer', 'icon': 'assets/icons/prayer.svg'},
    {'name': 'Lyrics', 'url': 'dashmate://lyrics', 'icon': 'assets/icons/lyrics.svg'},
  ];

  late List<Map<String, String>> _activeShortcuts;

  @override
  void initState() {
    super.initState();
    _activeShortcuts = [
      _allAvailableShortcuts[0],
      _allAvailableShortcuts[1],
      _allAvailableShortcuts[2],
      _allAvailableShortcuts[3],
      _allAvailableShortcuts[4],
    ];
  }

  void _saveShortcuts() async {
    try {
      await _channel.invokeMethod('setShortcuts', {'shortcuts': _activeShortcuts});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.cardSurface,
            content: Text('Car shortcuts updated on vehicle deck!', style: TextStyle(color: AppColors.tealAccent)),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {}
  }

  void _toggleShortcut(Map<String, String> item) {
    setState(() {
      final exists = _activeShortcuts.any((e) => e['name'] == item['name']);
      if (exists) {
        if (_activeShortcuts.length > 1) {
          _activeShortcuts.removeWhere((e) => e['name'] == item['name']);
        }
      } else {
        if (_activeShortcuts.length < 5) {
          _activeShortcuts.add(item);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.cardSurface,
              content: Text('Maximum 5 shortcuts allowed on car deck bar', style: TextStyle(color: Colors.orangeAccent)),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    });
    _saveShortcuts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.get('floating_menu'),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Bar Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Car Screen Dock Preview',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                      Text(
                        '${_activeShortcuts.length} / 5',
                        style: const TextStyle(color: AppColors.tealAccent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070B14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _activeShortcuts.map((item) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.cardSurface,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.tealAccent.withValues(alpha: 0.5)),
                              ),
                              child: const Icon(Icons.apps, color: AppColors.tealAccent, size: 20),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['name'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Customize Shortcuts (Select up to 5)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _allAvailableShortcuts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final sc = _allAvailableShortcuts[index];
                final isSelected = _activeShortcuts.any((e) => e['name'] == sc['name']);

                return InkWell(
                  onTap: () => _toggleShortcut(sc),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.tealAccent : AppColors.glassBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.tealAccent.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                            color: isSelected ? AppColors.tealAccent : AppColors.textMuted,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sc['name'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isSelected ? Colors.white : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                sc['url'] ?? '',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
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
