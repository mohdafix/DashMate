import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _groupB = [
  'lib/screens/prayer_screen.dart',
  'lib/screens/lyrics_screen.dart',
  'lib/screens/parking_screen.dart',
  'lib/screens/football_settings_screen.dart',
  'lib/screens/browse_screen.dart',
  'lib/screens/custom_page_screen.dart',
  'lib/screens/welcome_sound_screen.dart',
];

final _banned = <RegExp>[
  RegExp(r'Colors\.(white|black)\b'),
  RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)'),
  RegExp(r'AppColors\.'),
];

void main() {
  group('group B screens have no hardcoded colours', () {
    for (final path in _groupB) {
      test(path, () {
        final lines = File(path).readAsLinesSync();
        final hits = <String>[];
        for (var i = 0; i < lines.length; i++) {
          for (final re in _banned) {
            if (re.hasMatch(lines[i])) hits.add('${i + 1}: ${lines[i].trim()}');
          }
        }
        expect(hits, isEmpty, reason: '$path still hardcodes colours');
      });
    }
  });
}
