import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class ButtonSizeScreen extends StatefulWidget {
  const ButtonSizeScreen({super.key});

  @override
  State<ButtonSizeScreen> createState() => _ButtonSizeScreenState();
}

class _ButtonSizeScreenState extends State<ButtonSizeScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');

  double _buttonSize = 100.0;
  double _opacity = 92.0;
  int _selectedColorIndex = 0;

  final List<Color> _colors = const [
    Color(0xFF14E0C1), // Teal
    Color(0xFF009688), // Emerald Green
    Color(0xFFE55368), // Coral / Pink Red
    Color(0xFF3B82F6), // Blue
    Color(0xFFD9822B), // Amber / Gold
    Color(0xFF8B5CF6), // Purple
  ];

  final Color _darkColor = const Color(0xFF161B26);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  void _loadPrefs() async {
    try {
      final res = await _channel.invokeMethod('getButtonPrefs');
      if (res != null && res is Map && mounted) {
        setState(() {
          _buttonSize = (res['size'] as num?)?.toDouble() ?? 100.0;
          _opacity = (res['opacity'] as num?)?.toDouble() ?? 92.0;
          _selectedColorIndex = (res['colorIndex'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  void _savePrefs() {
    _channel.invokeMethod('setNavScale', {
      'scale': (_buttonSize / 100.0).toStringAsFixed(2),
      'opacity': (_opacity / 100.0).toStringAsFixed(2),
      'colorIndex': _selectedColorIndex,
    });
  }

  Color get _currentColor {
    if (_selectedColorIndex == -1) return _darkColor;
    return _colors[_selectedColorIndex];
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
          'Car button size',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 1. Top Card: Button Size
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 14),
                      child: Icon(Icons.touch_app_outlined, color: Colors.white, size: 22),
                    ),
                    Expanded(
                      child: Text(
                        "Size of AutoDeck's button bar on the car screen",
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8), height: 1.3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_buttonSize.toInt()}%',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _buttonSize = (_buttonSize - 5).clamp(80.0, 130.0);
                        });
                        _savePrefs();
                      },
                      child: const Text('—', style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppColors.accentTeal,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: AppColors.accentTeal,
                          overlayColor: AppColors.accentTeal.withValues(alpha: 0.2),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        ),
                        child: Slider(
                          value: _buttonSize,
                          min: 80,
                          max: 130,
                          divisions: 10,
                          onChanged: (val) {
                            setState(() => _buttonSize = val);
                            _savePrefs();
                          },
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _buttonSize = (_buttonSize + 5).clamp(80.0, 130.0);
                        });
                        _savePrefs();
                      },
                      child: const Text('+', style: TextStyle(fontSize: 20, color: Colors.white70, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Bottom Card: Floating button look
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header preview
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _currentColor.withValues(alpha: _opacity / 100.0 * 0.4),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _currentColor.withValues(alpha: _opacity / 100.0)),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.grid_view,
                          color: Colors.white.withValues(alpha: (_opacity / 100.0).clamp(0.4, 1.0)),
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Floating button look',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'How the floating button looks on the car screen when idle.',
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Opacity section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Opacity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
                    Text(
                      '${_opacity.toInt()}%',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.accentTeal,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: AppColors.accentTeal,
                    overlayColor: AppColors.accentTeal.withValues(alpha: 0.2),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  ),
                  child: Slider(
                    value: _opacity,
                    min: 20,
                    max: 100,
                    divisions: 16,
                    onChanged: (val) {
                      setState(() => _opacity = val);
                      _savePrefs();
                    },
                  ),
                ),

                const SizedBox(height: 14),

                // Colour section
                const Text('Colour', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
                const SizedBox(height: 14),

                // Color circles row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (int i = 0; i < _colors.length; i++)
                      _buildColorCircle(
                        color: _colors[i],
                        isSelected: _selectedColorIndex == i,
                        onTap: () {
                          setState(() => _selectedColorIndex = i);
                          _savePrefs();
                        },
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Dark circle
                _buildColorCircle(
                  color: _darkColor,
                  isSelected: _selectedColorIndex == -1,
                  onTap: () {
                    setState(() => _selectedColorIndex = -1);
                    _savePrefs();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorCircle({
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.white, width: 2.5)
              : Border.all(color: Colors.white12, width: 1),
        ),
        child: isSelected
            ? const Center(
                child: Icon(Icons.check, color: Colors.white, size: 20),
              )
            : null,
      ),
    );
  }
}
