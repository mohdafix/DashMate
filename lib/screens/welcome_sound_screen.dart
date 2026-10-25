import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';

class WelcomeSoundScreen extends StatefulWidget {
  const WelcomeSoundScreen({super.key});

  @override
  State<WelcomeSoundScreen> createState() => _WelcomeSoundScreenState();
}

class _WelcomeSoundScreenState extends State<WelcomeSoundScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');

  int _selectedSoundMode = 1; // 0: Off, 1: Chime, 2: Custom
  bool _voiceGreeting = false; // no voice unless the owner types a greeting
  final TextEditingController _greetingController = TextEditingController();
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
          _voiceGreeting = (res['voiceGreeting'] as bool?) ?? false;
          _greetingController.text = (res['customText'] as String?) ?? '';
          _speed = (res['speed'] as num?)?.toDouble() ?? 1.0;
          _pitch = (res['pitch'] as num?)?.toDouble() ?? 1.0;
          _volume = (res['volume'] as num?)?.toDouble() ?? 0.8;
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
    _channel.invokeMethod('testVoiceGreeting', {
      'text': _greetingController.text,
      'speed': _speed,
      'pitch': _pitch,
      'volume': _volume,
    });
  }

  @override
  void dispose() {
    _greetingController.dispose();
    super.dispose();
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
          'Welcome sound',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: t.ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border),
              boxShadow: t.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top 3-way Segmented Control
                Container(
                  height: 48,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildSoundModeTab(0, Icons.volume_off_outlined, 'Off')),
                      Container(width: 1, color: t.border),
                      Expanded(child: _buildSoundModeTab(1, Icons.notifications_active_outlined, 'Chime')),
                      Container(width: 1, color: t.border),
                      Expanded(child: _buildSoundModeTab(2, Icons.insert_drive_file_outlined, 'Custom')),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Voice Greeting Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice greeting',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Spoken after the sound',
                          style: TextStyle(fontSize: 13, color: t.ink2),
                        ),
                      ],
                    ),
                    Switch(
                      value: _voiceGreeting,
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
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.border),
                  ),
                  child: TextField(
                    controller: _greetingController,
                    maxLines: null,
                    maxLength: 240,
                    style: TextStyle(fontSize: 14, color: t.ink),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      hintText: 'What to say (optional)',
                      hintStyle: TextStyle(fontSize: 14, color: t.ink3),
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
                        style: TextStyle(fontSize: 11, color: t.ink3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${_greetingController.text.length}/240',
                      style: TextStyle(fontSize: 11, color: t.ink3),
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

                // 6. Speed Slider
                Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text('Speed', style: TextStyle(fontSize: 13, color: t.ink2)),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: t.accent,
                          inactiveTrackColor: t.border,
                          thumbColor: t.accent,
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
                    SizedBox(
                      width: 50,
                      child: Text('Pitch', style: TextStyle(fontSize: 13, color: t.ink2)),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: t.accent,
                          inactiveTrackColor: t.border,
                          thumbColor: t.accent,
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
                    Icon(Icons.volume_up, size: 20, color: t.ink2),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: t.accent,
                          inactiveTrackColor: t.border,
                          thumbColor: t.accent,
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
                      icon: Icon(Icons.play_arrow, size: 16, color: t.onAccent),
                      label: Text('Test', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: t.onAccent)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.accent,
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 9. Bottom Attribution Note
                Text(
                  'Plays through the car speakers when Android Auto connects. Your music pauses, then resumes after.',
                  style: TextStyle(fontSize: 12, color: t.ink3, height: 1.4),
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
    final t = context.tokens;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedSoundMode = index);
        _savePrefs();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSel ? t.surface : Colors.transparent,
          border: isSel ? Border.all(color: t.accent) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSel ? t.accent : t.ink2),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                color: isSel ? t.accent : t.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagPill(String tag) {
    final t = context.tokens;
    return GestureDetector(
      onTap: () => _addTag(tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: t.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.border),
        ),
        child: Text(
          tag,
          style: TextStyle(fontSize: 13, color: t.ink, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
