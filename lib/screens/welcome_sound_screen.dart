import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class WelcomeSoundScreen extends StatefulWidget {
  const WelcomeSoundScreen({super.key});

  @override
  State<WelcomeSoundScreen> createState() => _WelcomeSoundScreenState();
}

class _WelcomeSoundScreenState extends State<WelcomeSoundScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');

  int _selectedSoundMode = 1; // 0: Off, 1: Chime, 2: Custom
  String _customSoundName = '';
  bool _voiceGreeting = true;
  final TextEditingController _greetingController = TextEditingController();
  String _selectedVoice = 'Phone default';
  double _speed = 1.0;
  double _pitch = 1.0;
  double _volume = 0.8;

  final List<String> _tags = [
    '+ Name',
    '+ Prayer name',
    '+ Prayer time',
    '+ Current time',
    '+ Rain alert',
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  void _loadPrefs() async {
    try {
      final res = await _channel.invokeMethod('getWelcomePrefs');
      if (res != null && res is Map && mounted) {
        setState(() {
          _selectedSoundMode = (res['mode'] as num?)?.toInt() ?? 1;
          _voiceGreeting = (res['voiceGreeting'] as bool?) ?? true;
          _greetingController.text = (res['customText'] as String?) ?? '';
          _speed = (res['speed'] as num?)?.toDouble() ?? 1.0;
          _pitch = (res['pitch'] as num?)?.toDouble() ?? 1.0;
          _volume = (res['volume'] as num?)?.toDouble() ?? 0.8;
          _customSoundName = (res['customSoundName'] as String?) ?? '';
        });
      }
    } catch (_) {}
  }

  void _savePrefs() {
    _channel.invokeMethod('setWelcomePrefs', {
      'mode': _selectedSoundMode,
      'voiceGreeting': _voiceGreeting,
      'customText': _greetingController.text,
      'speed': _speed,
      'pitch': _pitch,
      'volume': _volume,
    });
  }

  void _addTag(String tag) {
    String placeholder = '';
    switch (tag) {
      case '+ Name':
        placeholder = '{name}';
        break;
      case '+ Prayer name':
        placeholder = '{prayer_name}';
        break;
      case '+ Prayer time':
        placeholder = '{prayer_time}';
        break;
      case '+ Current time':
        placeholder = '{time}';
        break;
      case '+ Rain alert':
        placeholder = '{rain}';
        break;
    }
    final text = _greetingController.text;
    final newText = text.isEmpty ? placeholder : '$text $placeholder';
    if (newText.length <= 240) {
      setState(() {
        _greetingController.text = newText;
      });
      _savePrefs();
    }
  }

  void _testSpeech() {
    _channel.invokeMethod('testWelcomeExperience', {
      'mode': _selectedSoundMode,
      'voiceGreeting': _voiceGreeting,
      'customText': _greetingController.text,
      'speed': _speed,
      'pitch': _pitch,
      'volume': _volume,
    });
  }

  void _pickCustomSound() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('pickCustomSound');
      if (res != null && mounted) {
        setState(() {
          _customSoundName = res['name']?.toString() ?? '';
          _selectedSoundMode = 2;
        });
        _savePrefs();
      }
    } catch (_) {}
  }

  void _previewSound() {
    _channel.invokeMethod('testSound');
  }

  @override
  void dispose() {
    _greetingController.dispose();
    super.dispose();
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
          'Welcome sound',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top 3-way Segmented Control
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildSoundModeTab(0, Icons.volume_off_outlined, 'Off')),
                      Container(width: 1, color: Colors.white12),
                      Expanded(child: _buildSoundModeTab(1, Icons.notifications_active_outlined, 'Chime')),
                      Container(width: 1, color: Colors.white12),
                      Expanded(child: _buildSoundModeTab(2, Icons.insert_drive_file_outlined, 'Custom')),
                    ],
                  ),
                ),

                if (_selectedSoundMode == 2) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D2A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2C3E55)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2F44),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.audio_file_rounded, color: AppColors.accentTeal, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _customSoundName.isNotEmpty ? _customSoundName : 'No file chosen',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _customSoundName.isNotEmpty ? 'Tap Change to replace audio' : 'Tap Browse to choose audio file',
                                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        ),
                        if (_customSoundName.isNotEmpty) ...[
                          IconButton(
                            icon: const Icon(Icons.play_circle_fill, color: AppColors.accentTeal, size: 26),
                            onPressed: _previewSound,
                            tooltip: 'Preview sound',
                          ),
                        ],
                        TextButton(
                          onPressed: _pickCustomSound,
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF243B55),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_customSoundName.isNotEmpty ? 'Change' : 'Browse', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // 2. Voice Greeting Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Voice greeting',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Spoken after the sound',
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                    Switch(
                      value: _voiceGreeting,
                      activeColor: AppColors.accentTeal,
                      activeTrackColor: AppColors.accentTeal.withValues(alpha: 0.5),
                      onChanged: (val) {
                        setState(() => _voiceGreeting = val);
                        _savePrefs();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. What to say text box
                Container(
                  height: 100,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C101A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: _greetingController,
                    maxLines: null,
                    maxLength: 240,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'What to say (optional)',
                      hintStyle: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.4)),
                      counterText: '',
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _savePrefs();
                    },
                  ),
                ),

                const SizedBox(height: 6),

                // Counter & hint row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Leave empty for the automatic greetin...',
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${_greetingController.text.length}/240',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 4. Quick Insert Tags
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: _tags.map((t) => _buildTagPill(t)).toList(),
                ),

                const SizedBox(height: 24),

                // 5. Voice Dropdown Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Voice', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6))),
                          const SizedBox(height: 2),
                          Text(_selectedVoice, style: const TextStyle(fontSize: 14, color: Colors.white)),
                        ],
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.white70),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 6. Speed Slider
                Row(
                  children: [
                    const SizedBox(
                      width: 50,
                      child: Text('Speed', style: TextStyle(fontSize: 13, color: Colors.white70)),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppColors.accentTeal,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: AppColors.accentTeal,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                        ),
                        child: Slider(
                          value: _speed,
                          min: 0.5,
                          max: 1.5,
                          divisions: 10,
                          onChanged: (val) {
                            setState(() => _speed = val);
                            _savePrefs();
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // 7. Pitch Slider
                Row(
                  children: [
                    const SizedBox(
                      width: 50,
                      child: Text('Pitch', style: TextStyle(fontSize: 13, color: Colors.white70)),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppColors.accentTeal,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: AppColors.accentTeal,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                        ),
                        child: Slider(
                          value: _pitch,
                          min: 0.5,
                          max: 1.5,
                          divisions: 10,
                          onChanged: (val) {
                            setState(() => _pitch = val);
                            _savePrefs();
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // 8. Volume & Test Row
                Row(
                  children: [
                    const Icon(Icons.volume_up, size: 20, color: Colors.white70),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppColors.accentTeal,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: AppColors.accentTeal,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                        ),
                        child: Slider(
                          value: _volume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (val) {
                            setState(() => _volume = val);
                            _savePrefs();
                          },
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _testSpeech,
                      icon: const Icon(Icons.play_arrow, size: 16, color: Colors.black),
                      label: const Text('Test', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentTeal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 9. Bottom Attribution Note
                Text(
                  'Plays through the car speakers when Android Auto connects. Your music pauses, then resumes after.',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSoundModeTab(int index, IconData icon, String label) {
    final isSel = _selectedSoundMode == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedSoundMode = index);
        _savePrefs();
        if (index == 2 && _customSoundName.isEmpty) {
          _pickCustomSound();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF1E3830) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSel ? AppColors.accentTeal : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                color: isSel ? AppColors.accentTeal : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagPill(String tag) {
    return GestureDetector(
      onTap: () => _addTag(tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          tag,
          style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
