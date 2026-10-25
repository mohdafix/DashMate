import 'dart:convert';

import 'package:dashmate/screens/widgets_screen.dart';
import 'package:dashmate/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.dashmate.dashmate/channel');

/// Fake MainActivity: remembers what the editor saves, per screen shape.
class _FakeCar {
  _FakeCar({this.stored = const {}});
  final String screen = 'portrait';
  final Map<bool, Map<String, dynamic>> stored;
  final saved = <bool, Map<String, dynamic>>{};

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'getCarScreenSize':
        return screen;
      case 'getLayoutSettings':
        final l = stored[(call.arguments as Map)['tall'] == true];
        return l == null ? null : jsonEncode(l); // null: nothing saved yet, built-in defaults
      case 'saveLayoutSettings':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        saved[args['tall'] == true] =
            jsonDecode(args['layout'] as String) as Map<String, dynamic>;
        return true;
      default:
        return null;
    }
  }

  String? taOf(bool tall, String id) {
    final l = saved[tall];
    if (l == null) return null;
    final w = (l['widgets'] as List).cast<Map>().firstWhere((e) => e['id'] == id);
    return w['ta'] as String?;
  }
}

Future<void> _open(WidgetTester tester, _FakeCar car) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, car.handle);
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null));
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const WidgetsScreen()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Style'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Center saves ta=center for the selected widget in the Tall layout', (tester) async {
    final car = _FakeCar();
    await _open(tester, car);
    await tester.tap(find.byKey(const ValueKey('align-center')));
    await tester.pumpAndSettle();
    expect(car.taOf(true, 'clock'), 'center');
    expect(car.saved.containsKey(false), isFalse, reason: 'the Wide layout must not be touched');
  });

  testWidgets('Right on the Wide tab saves into the Wide layout only', (tester) async {
    final car = _FakeCar();
    await _open(tester, car);
    await tester.tap(find.text('Wide'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('align-right')));
    await tester.pumpAndSettle();
    expect(car.taOf(false, 'clock'), 'right');
    expect(car.saved.containsKey(true), isFalse);
  });

  testWidgets('the board preview follows the alignment', (tester) async {
    final car = _FakeCar();
    await _open(tester, car);
    Alignment clockAlign() => tester
        .widget<Align>(find.ancestor(of: find.text('08:29'), matching: find.byType(Align)).first)
        .alignment as Alignment;
    expect(clockAlign(), Alignment.centerLeft);
    await tester.tap(find.byKey(const ValueKey('align-right')));
    await tester.pumpAndSettle();
    expect(clockAlign(), Alignment.centerRight);
  });

  testWidgets('saving widgets keeps the clock font and 12/24-hour choice', (tester) async {
    final car = _FakeCar(stored: {
      true: {
        'v': 2,
        'clockFont': 'bebas',
        'clock24': false,
        'widgets': [
          {'id': 'clock', 'x': 1, 'y': 1, 'w': 12, 'h': 3, 'ta': 'left'},
        ],
      },
    });
    await _open(tester, car);
    await tester.tap(find.byKey(const ValueKey('align-center')));
    await tester.pumpAndSettle();
    expect(car.saved[true]!['clockFont'], 'bebas');
    expect(car.saved[true]!['clock24'], false);
    expect(car.taOf(true, 'clock'), 'center');
  });
}
