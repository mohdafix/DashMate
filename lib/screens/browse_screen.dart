import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';
import '../theme/localization.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  static const _browserChannel = MethodChannel('drivedeck/car_browser');
  final TextEditingController _urlController = TextEditingController(text: 'https://m.youtube.com');
  final TextEditingController _streamController = TextEditingController();
  bool _isSignedInToYouTube = true;

  final List<Map<String, dynamic>> _quickLinks = [
    {
      'name': 'YouTube',
      'url': 'https://m.youtube.com',
      'icon': Icons.play_circle_fill,
      'color': Colors.red.shade600,
      'desc': 'Music, Videos & Channels'
    },
    {
      'name': 'RTM Klik',
      'url': 'https://rtmklik.rtm.gov.my',
      'icon': Icons.live_tv,
      'color': Colors.blue.shade700,
      'desc': 'TV1, TV2, Okey, Sukan RTM'
    },
    {
      'name': 'Google Search',
      'url': 'https://www.google.com',
      'icon': Icons.search,
      'color': Colors.blue.shade500,
      'desc': 'Search Web'
    },
    {
      'name': 'Waze Live Map',
      'url': 'https://www.waze.com/live-map',
      'icon': Icons.navigation,
      'color': Colors.lightBlue.shade600,
      'desc': 'Traffic & Alerts'
    },
  ];

  void _sendUrlToCar(String url) async {
    try {
      // Opens the car's browser panel on this address.
      await _browserChannel.invokeMethod('sendToCar', {'url': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Opened in DashMate Browser on the car screen',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  void _clearBrowserData() async {
    try {
      await _browserChannel.invokeMethod('clearBrowserData');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Browser data cleared'),
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
        final t = context.tokens;
        return AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Stream URL', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter a full URL, e.g. HLS (.m3u8), MPD or direct video stream',
                style: TextStyle(color: t.ink2, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _streamController,
                style: TextStyle(color: t.ink, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'https://example.com/manifest.mpd',
                  hintStyle: TextStyle(color: t.ink3, fontSize: 13),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.accent, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: t.ink2)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent),
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
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.get('browse'),
          style: TextStyle(fontWeight: FontWeight.w600, color: t.ink),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep_outlined, color: t.ink2),
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
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.border),
                boxShadow: t.cardShadow,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.search, color: t.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: TextStyle(color: t.ink, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search or enter address',
                        hintStyle: TextStyle(color: t.ink3),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
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
                    icon: Icon(Icons.arrow_forward_rounded, color: t.accent),
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
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.border),
                boxShadow: t.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.account_circle, color: Colors.red.shade600, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSignedInToYouTube ? 'Signed in to YouTube' : 'Sign in to YouTube',
                          style: TextStyle(fontWeight: FontWeight.bold, color: t.ink, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isSignedInToYouTube ? 'Sync subscriptions & history to car screen' : 'Log in with your Google account',
                          style: TextStyle(fontSize: 11, color: t.ink2),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: t.accent),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _sendUrlToCar('https://accounts.google.com/ServiceLogin?service=youtube'),
                    child: Text(_isSignedInToYouTube ? 'Account' : 'Sign In', style: TextStyle(color: t.accent, fontSize: 12)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Web, YouTube, RTM Klik on the car',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: t.ink2),
                ),
                GestureDetector(
                  onTap: _showStreamDialog,
                  child: Text('Paste Stream URL', style: TextStyle(color: t.accent, fontSize: 12, fontWeight: FontWeight.bold)),
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
                      color: t.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.border),
                      boxShadow: t.cardShadow,
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
                                color: (link['color'] as Color).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(link['icon'] as IconData, color: link['color'] as Color, size: 20),
                            ),
                            Icon(Icons.launch, color: t.ink3, size: 16),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link['name'] as String,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: t.ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              link['desc'] as String,
                              style: TextStyle(fontSize: 11, color: t.ink2),
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
                color: Color.alphaBlend(t.accent.withValues(alpha: 0.06), t.surface),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.accent.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: t.accent, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Videos play only when parked',
                          style: TextStyle(fontWeight: FontWeight.bold, color: t.ink, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Always keep your eyes on the road. Never watch videos or operate screens while driving.',
                          style: TextStyle(fontSize: 11, color: t.ink2),
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
