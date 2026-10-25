import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';

/// First-run setup (and "Your name & car screen" later): the owner's name, shown in the app and
/// used for {name} in the greeting, and the Android Auto screen shape. The shape goes into the
/// same car_screen_* settings the car measurement uses, so the two never disagree.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, this.firstRun = false});

  /// First run: no back button; Save needs a name.
  final bool firstRun;

  /// Shows setup if no name has been entered yet. Returns the saved name (or null).
  static Future<String?> showIfNeeded(BuildContext context) async {
    try {
      final res = await _channel.invokeMethod<Map>('getUserSetup');
      final name = (res?['name'] as String?) ?? '';
      if (name.isNotEmpty || !context.mounted)
        return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const SetupScreen(firstRun: true),
      ),
    );
  }

  static const MethodChannel _channel = MethodChannel(
    'com.dashmate.dashmate/channel',
  );

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController();
  String _shape = 'tall'; // the Jaecoo J7 is tall
  String?
  _measured; // e.g. "1014 × 1635 (portrait)" once the car has reported its size
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await SetupScreen._channel.invokeMethod<Map>('getUserSetup');
      if (!mounted || res == null) return;
      setState(() {
        _name.text = (res['name'] as String?) ?? '';
        _shape = (res['shape'] as String?) ?? 'tall';
        _measured = res['size'] as String?;
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await SetupScreen._channel.invokeMethod('saveUserSetup', {
        'name': name,
        'shape': _shape,
      });
    } catch (_) {}
    if (mounted) Navigator.of(context).pop(name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final canSave = _name.text.trim().isNotEmpty && !_saving;
    return PopScope(
      canPop: !widget.firstRun,
      child: Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(
          automaticallyImplyLeading: !widget.firstRun,
          title: Text(
            widget.firstRun ? 'Welcome to DashMate' : 'Your name & car screen',
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (widget.firstRun)
                Text(
                  'Two quick things before your first drive.',
                  style: TextStyle(fontSize: 14, color: t.ink2, height: 1.4),
                ),
              const SizedBox(height: 20),
              Text(
                'Your name',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Shown in the app, and used for {name} if you type a greeting.',
                style: TextStyle(fontSize: 12, color: t.ink3),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _name,
                autofocus: widget.firstRun,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'e.g. Zack'),
              ),
              const SizedBox(height: 16),
              Text(
                'Android Auto screen',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'DashMate measures the exact size the first time it opens in your car.',
                style: TextStyle(fontSize: 12, color: t.ink3),
              ),
              const SizedBox(height: 10),
              _shapeOption(
                t,
                'tall',
                Icons.stay_current_portrait,
                'Tall · Jaecoo J7',
                _measured != null &&
                        _shape == 'tall' &&
                        _measured!.contains('portrait')
                    ? '$_measured · measured from your car'
                    : 'Portrait screen (13.2" or 14.8")',
              ),
              const SizedBox(height: 10),
              _shapeOption(
                t,
                'wide',
                Icons.stay_current_landscape,
                'Wide',
                'Landscape screen (most other cars)',
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: canSave ? _save : null,
                  child: Text(
                    widget.firstRun ? 'Start' : 'Save',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shapeOption(
    AppTokens t,
    String value,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final on = _shape == value;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _shape = value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: on ? t.accent.withValues(alpha: 0.10) : t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: on ? t.accent : t.border,
            width: on ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: on ? t.accent : t.ink2),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: t.ink2)),
                ],
              ),
            ),
            Icon(
              on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: on ? t.accent : t.ink3,
            ),
          ],
        ),
      ),
    );
  }
}
