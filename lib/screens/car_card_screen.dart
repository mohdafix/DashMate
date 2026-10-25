import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';

class CarCardScreen extends StatefulWidget {
  const CarCardScreen({super.key});

  @override
  State<CarCardScreen> createState() => _CarCardScreenState();
}

class _CarCardScreenState extends State<CarCardScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');
  static const MethodChannel _browserChannel = MethodChannel('drivedeck/car_browser');

  bool _showCard = true;
  String _selectedMode = 'Auto'; // 'Auto', 'Lyrics', 'Next prayer', 'Football'

  final List<String> _modes = const [
    'Auto',
    'Lyrics',
    'Next prayer',
    'Football',
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  void _loadPrefs() async {
    try {
      final res = await _channel.invokeMethod('getCarCardMode');
      if (res != null && mounted) {
        if (res is Map) {
          setState(() {
            _showCard = res['show'] ?? true;
            _selectedMode = res['mode'] ?? 'Auto';
          });
        } else if (res is String) {
          setState(() {
            _selectedMode = res;
          });
        }
      }
    } catch (_) {}
  }

  void _savePrefs() {
    _channel.invokeMethod('setCarCardMode', {
      'show': _showCard,
      'mode': _selectedMode,
    });
    _browserChannel.invokeMethod('setCarCardMode', {
      'show': _showCard,
      'mode': _selectedMode,
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Car card (next to the map)',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: t.ink,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 1. Top Card: Show AutoDeck Card toggle
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border),
              boxShadow: t.cardShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2, right: 14),
                  child: Icon(
                    Icons.featured_video_outlined,
                    color: t.ink,
                    size: 24,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Show DashMate Card',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: t.ink,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Media card next to the map (lyrics, prayer, scores). Turn off if your car's dashboard / meter map or media buttons stop working while DashMate is open.",
                        style: TextStyle(
                          fontSize: 13,
                          color: t.ink2,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _showCard,
                  onChanged: (val) {
                    setState(() {
                      _showCard = val;
                    });
                    _savePrefs();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Explanatory Subtitle
          Text(
            "What Android Auto's media card shows beside Google Maps. Auto = lyrics while music plays, a live score when your teams play, otherwise the next prayer.",
            style: TextStyle(
              fontSize: 13.5,
              color: t.ink2,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 16),

          // 3. Choice Chips
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _modes.map((mode) {
              final isSelected = _selectedMode.toLowerCase() == mode.toLowerCase();
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMode = mode;
                  });
                  _savePrefs();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? t.accent
                        : t.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected
                          ? t.accent
                          : t.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        Icon(
                          Icons.check,
                          color: t.onAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        mode,
                        style: TextStyle(
                          color: isSelected ? t.onAccent : t.ink2,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
    );
  }
}
