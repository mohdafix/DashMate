import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

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
      dynamic res;
      try {
        res = await _channel.invokeMethod('getCarCardMode');
      } catch (_) {
        res = await _browserChannel.invokeMethod('getCarCardMode');
      }
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
          'Car card (next to the map)',
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
          // 1. Top Card: Show DashMate Card toggle
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 14),
                  child: Icon(
                    Icons.featured_video_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Show DashMate Card',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Media card next to the map (lyrics, prayer, scores). Turn off if your car's dashboard / meter map or media buttons stop working while DashMate is open.",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSub,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _showCard,
                  activeColor: AppColors.accentTeal,
                  activeTrackColor: const Color(0xFF0F766E),
                  inactiveThumbColor: Colors.white38,
                  inactiveTrackColor: Colors.white12,
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
          const Text(
            "What Android Auto's media card shows beside Google Maps. Auto = lyrics while music plays, a live score when your teams play, otherwise the next prayer.",
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSub,
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
                        ? const Color(0xFF0F766E)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentTeal
                          : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        mode,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
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
