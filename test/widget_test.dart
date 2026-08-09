import 'package:flutter_test/flutter_test.dart';

import 'package:adhd_assistant/main.dart';

void main() {
  testWidgets('Main sections render and Notes opens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ADHDApp());
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Timer'), findsOneWidget);
    expect(find.text('Task list'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();

    expect(find.text('Capture'), findsOneWidget);
  });
}
