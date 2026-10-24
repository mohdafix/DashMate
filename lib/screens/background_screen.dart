import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class BackgroundScreen extends StatefulWidget {
  const BackgroundScreen({super.key});

  @override
  State<BackgroundScreen> createState() => _BackgroundScreenState();
}

class _BackgroundScreenState extends State<BackgroundScreen> {
  static const MethodChannel _browserChannel = MethodChannel('drivedeck/car_browser');
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');

  String _bgMode = 'cover'; // 'cover', 'plain', 'photo'
  String _selectedPhotoUrl = '';

  final List<Map<String, String>> _curatedPhotos = const [
    {
      'name': 'Midnight Highway',
      'url': 'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'name': 'Neon Cyber City',
      'url': 'https://images.unsplash.com/photo-1519501025264-65ba15a82390?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'name': 'Mountain Mist',
      'url': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'name': 'Dark Horizon',
      'url': 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=1200&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  void _loadPrefs() async {
    try {
      final res = await _channel.invokeMethod('getBgPrefs');
      if (res != null && res is Map && mounted) {
        setState(() {
          _bgMode = (res['mode'] as String?) ?? 'cover';
          _selectedPhotoUrl = (res['url'] as String?) ?? '';
        });
      }
    } catch (_) {}
  }

  void _savePrefs(String mode, [String url = '']) {
    setState(() {
      _bgMode = mode;
      if (url.isNotEmpty) _selectedPhotoUrl = url;
    });
    _browserChannel.invokeMethod('setCarTemplate', {'template': mode});
    _channel.invokeMethod('setBgMode', {'mode': mode, 'url': url});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Car home background',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Subtitle
          const Text(
            'What shows behind your widgets on the car screen. Choose live music album cover, clean plain dark, or landscape photography.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSub,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // 1. Live Car Preview Frame
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF070B14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.3), width: 1.5),
              image: _bgMode == 'photo' && _selectedPhotoUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_selectedPhotoUrl),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.55), BlendMode.darken),
                    )
                  : (_bgMode == 'cover'
                      ? DecorationImage(
                          image: const NetworkImage('https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?auto=format&fit=crop&w=600&q=80'),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.65), BlendMode.darken),
                        )
                      : null),
            ),
            child: Stack(
              children: [
                // Simulated Car HUD widgets
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('10:42 PM', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('Friday · 28°C', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.music_note, color: AppColors.accentTeal, size: 14),
                            SizedBox(width: 6),
                            Text('Midnight City', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 10,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Mode: ${_bgMode.toUpperCase()}',
                      style: const TextStyle(color: AppColors.accentTeal, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Mode Cards
          _buildModeOption(
            mode: 'cover',
            title: 'Cover',
            description: 'Shows the album cover of what is playing right now in Spotify, YouTube Music, or other apps.',
            icon: Icons.album_outlined,
          ),
          const SizedBox(height: 12),

          _buildModeOption(
            mode: 'plain',
            title: 'Plain',
            description: 'A clean, distraction-free pure dark cockpit background for maximum readability.',
            icon: Icons.brightness_2_outlined,
          ),
          const SizedBox(height: 12),

          _buildModeOption(
            mode: 'photo',
            title: 'Photo',
            description: 'Driving landscapes and night city photography behind your widgets.',
            icon: Icons.photo_size_select_actual_outlined,
          ),

          if (_bgMode == 'photo') ...[
            const SizedBox(height: 20),
            const Text(
              'Select Driving Wallpaper',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
              ),
              itemCount: _curatedPhotos.length,
              itemBuilder: (context, idx) {
                final photo = _curatedPhotos[idx];
                final isSelected = _selectedPhotoUrl == photo['url'];

                return GestureDetector(
                  onTap: () => _savePrefs('photo', photo['url']!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          photo['url']!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF161F30)),
                        ),
                        Container(
                          color: isSelected
                              ? AppColors.accentTeal.withValues(alpha: 0.3)
                              : Colors.black38,
                        ),
                        if (isSelected)
                          const Center(
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.accentTeal,
                              child: Icon(Icons.check, size: 16, color: Colors.black),
                            ),
                          ),
                        Positioned(
                          bottom: 6,
                          left: 8,
                          right: 8,
                          child: Text(
                            photo['name']!,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required String mode,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _bgMode == mode;

    return GestureDetector(
      onTap: () => _savePrefs(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accentTeal : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accentTeal.withValues(alpha: 0.15)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.accentTeal : Colors.white70,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSub, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.accentTeal : Colors.white38,
                  width: 2,
                ),
                color: isSelected ? AppColors.accentTeal : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(child: Icon(Icons.check, size: 14, color: Colors.black))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
