import 'dart:convert';

import 'package:dashmate/core/car_layout.dart';
import 'package:dashmate/screens/lyrics_screen.dart';
import 'package:dashmate/screens/prayer_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.dashmate.dashmate/channel');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('lyrics answer from MainActivity', () {
    test('"[ms] text" lines become timed lines', () {
      final l = parseLyricsResponse('[0] Hello\n[2500] World\nnot a lyric\n[4000]');
      expect(l, [
        {'time': 0, 'text': 'Hello'},
        {'time': 2500, 'text': 'World'},
        {'time': 4000, 'text': ''},
      ]);
    });
    test('a list of maps still works; nothing gives an empty list', () {
      expect(parseLyricsResponse([{'time': 5, 'text': 'a'}]), [{'time': 5, 'text': 'a'}]);
      expect(parseLyricsResponse(null), isEmpty);
      expect(parseLyricsResponse(''), isEmpty);
    });
  });

  test('Hijri date (tabular calendar)', () {
    expect(hijriDate(DateTime(2025, 3, 1)), '1 Ramadan 1446');
    expect(hijriDate(DateTime(2026, 10, 24)), '12 Jamadilawal 1448');
  });

  group('CarLayout.setOptions', () {
    late Map<bool, String?> saved;
    setUp(() {
      saved = {
        true: jsonEncode({
          'v': 2,
          'clockFont': 'thin',
          'widgets': [
            {'id': 'clock', 'x': 1, 'y': 1, 'w': 12, 'h': 3, 'ta': 'right'},
          ],
        }),
        false: null, // nothing saved for wide yet
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final tall = args['tall'] == true;
        if (call.method == 'getLayoutSettings') return saved[tall];
        if (call.method == 'saveLayoutSettings') saved[tall] = args['layout'] as String;
        return true;
      });
    });
    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null));

    test('writes the font into both layouts and keeps the widgets', () async {
      await CarLayout.setOptions({'clockFont': 'bebas', 'clock24': false});
      final tall = jsonDecode(saved[true]!) as Map;
      final wide = jsonDecode(saved[false]!) as Map;
      expect(tall['clockFont'], 'bebas');
      expect(tall['clock24'], false);
      expect((tall['widgets'] as List).single['ta'], 'right');
      expect(wide['clockFont'], 'bebas');
      expect((wide['widgets'] as List), isNotEmpty, reason: 'wide gets the default widgets');
      expect(await CarLayout.option<String>('clockFont'), 'bebas');
    });
  });
}
