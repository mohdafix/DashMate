import 'package:flutter_test/flutter_test.dart';
import 'package:dashmate/main.dart';

void main() {
  testWidgets('DashMate app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DashMateApp());
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
