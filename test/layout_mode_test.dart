import 'package:dashmate/screens/settings_screen.dart';
import 'package:dashmate/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.dashmate.dashmate/channel');

void main() {
  testWidgets('Car layout: Always tall by default, Automatic is saved', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    String? stored; // nothing saved yet
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (call.method == 'getLayoutMode') return stored ?? 'tall';
      if (call.method == 'setLayoutMode') stored = (call.arguments as Map)['mode'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null));

    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Always tall'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('car-layout-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('layout-mode-auto')));
    await tester.pumpAndSettle();
    expect(stored, 'auto');
    expect(find.textContaining('Automatic'), findsOneWidget);
  });
}
