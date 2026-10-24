import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/localization.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  static const _channel = MethodChannel('com.dashmate.dashmate/channel');
  final TextEditingController _urlController = TextEditingController(text: 'https://m.youtube.com');
  final TextEditingController _streamController = TextEditingController();
  bool _isSignedInToYouTube = true;

  final List<Map<String, dynamic>> _quickLinks = [
    {
      'name': 'YouTube',
      'url': 'https://m.youtube.com',
      'icon': Icons.play_circle_fill,
      'color': const Color(0xFFFF0033),
      'desc': 'Music, Videos & Channels'
    },
    {
      'name': 'RTM Klik',
      'url': 'https://rtmklik.rtm.gov.my',
      'icon': Icons.live_tv,
      'color': const Color(0xFF0072CE),
      'desc': 'TV1, TV2, Okey, Sukan RTM'
    },
    {
      'name': 'Google Search',
      'url': 'https://www.google.com',
      'icon': Icons.search,
      'color': const Color(0xFF4285F4),
      'desc': 'Search Web'
    },
    {
      'name': 'Waze Live Map',
      'url': 'https://www.waze.com/live-map',
      'icon': Icons.navigation,
      'color': const Color(0xFF33CCFF),
      'desc': 'Traffic & Alerts'
    },
  ];

  void _sendUrlToCar(String url) async {
    try {
      await _channel.invokeMethod('setCarPage', {'page': 'browse'});
      await _channel.invokeMethod('loadYoutube', {'videoId': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.cardSurface,
            content: Text(
              'Opened in DashMate Browser on the car screen',
              style: const TextStyle(color: AppColors.tealAccent),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  void _clearBrowserData() async {
    try {
      await _channel.invokeMethod('clearBrowserData');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.cardSurface,
            content: Text('Browser data cleared', style: TextStyle(color: AppColors.tealAccent)),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  void _showStreamDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Stream URL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter a full URL, e.g. HLS (.m3u8), MPD or direct video stream',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _streamController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'https://example.com/manifest.mpd',
                  hintStyle: TextStyle(color: AppColors.textDim, fontSize: 13),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.glassBorder)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.tealAccent)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.tealAccent, foregroundColor: Colors.black),
              onPressed: () {
                final url = _streamController.text.trim();
                Navigator.pop(context);
                if (url.isNotEmpty) _sendUrlToCar(url);
              },
              child: const Text('Stream to Car', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.get('browse'),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.textMuted),
            tooltip: 'Clear browser data',
            onPressed: _clearBrowserData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search / Address Bar Card
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.tealAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search or enter address',
                        hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7)),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (val) {
                        String url = val.trim();
                        if (!url.startsWith('http://') && !url.startsWith('https://')) {
                          url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
                        }
                        _sendUrlToCar(url);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.tealAccent),
                    onPressed: () {
                      String url = _urlController.text.trim();
                      if (!url.startsWith('http://') && !url.startsWith('https://')) {
                        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
                      }
                      _sendUrlToCar(url);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // YouTube Account Status Card (Matches AutoDeck)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0033).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_circle, color: Color(0xFFFF0033), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSignedInToYouTube ? 'Signed in to YouTube' : 'Sign in to YouTube',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isSignedInToYouTube ? 'Sync subscriptions & history to car screen' : 'Log in with your Google account',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.tealAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => _sendUrlToCar('https://accounts.google.com/ServiceLogin?service=youtube'),
                    child: Text(_isSignedInToYouTube ? 'Account' : 'Sign In', style: const TextStyle(color: AppColors.tealAccent, fontSize: 12)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Web, YouTube, RTM Klik on the car',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                ),
                GestureDetector(
                  onTap: _showStreamDialog,
                  child: const Text('Paste Stream URL', style: TextStyle(color: AppColors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Links Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
              ),
              itemCount: _quickLinks.length,
              itemBuilder: (context, index) {
                final link = _quickLinks[index];
                return InkWell(
                  onTap: () {
                    _urlController.text = link['url'];
                    _sendUrlToCar(link['url']);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (link['color'] as Color).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(link['icon'] as IconData, color: link['color'] as Color, size: 20),
                            ),
                            const Icon(Icons.launch, color: AppColors.textMuted, size: 16),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link['name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              link['desc'] as String,
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Safe Parking Advisory Banner (Matches AutoDeck)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF14243B).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E3A5F)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.tealAccent, size: 24),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Videos play only when parked',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Always keep your eyes on the road. Never watch videos or operate screens while driving.',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
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
}
