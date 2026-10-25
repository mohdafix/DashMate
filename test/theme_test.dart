import 'dart:io';
import 'dart:math' as math;

import 'package:dashmate/theme/app_theme.dart';
import 'package:dashmate/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

const _groupA = [
  'lib/screens/dashboard_screen.dart',
  'lib/screens/settings_screen.dart',
  'lib/screens/widgets_screen.dart',
  'lib/screens/background_screen.dart',
  'lib/screens/button_size_screen.dart',
  'lib/screens/floating_menu_screen.dart',
  'lib/screens/car_card_screen.dart',
];

void main() {
  test('light and dark ThemeData carry AppTokens', () {
    expect(AppTheme.light().extension<AppTokens>(), AppTokens.light);
    expect(AppTheme.dark().extension<AppTokens>(), AppTokens.dark);
  });

  test('token contrast', () {
    for (final t in [AppTokens.light, AppTokens.dark]) {
      for (final bg in [t.bg, t.surface, t.surface2]) {
        expect(_contrast(t.ink, bg), greaterThanOrEqualTo(4.5));
      }
      expect(_contrast(t.onAccent, t.accent), greaterThanOrEqualTo(4.5));
    }
  });

  test('group A screens have no hardcoded colours', () {
    final banned = [
      RegExp(r'Colors\.(white|black)\b'),
      RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)'),
      RegExp(r'AppColors\.'),
    ];
    for (final path in _groupA) {
      final src = File(path).readAsStringSync();
      for (final re in banned) {
        final hits = re.allMatches(src).map((m) => m.group(0)).toList();
        expect(hits, isEmpty, reason: '$path contains ${re.pattern}');
      }
    }
  });
}
