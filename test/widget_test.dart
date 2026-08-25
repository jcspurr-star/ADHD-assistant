import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:adhd_assistant/main.dart';
import 'package:adhd_assistant/widgets/notes_view.dart';

void main() {
  testWidgets('Main sections render and Notes opens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ADHDApp());
    await tester.pumpAndSettle();

    final setupWarning = find.text('Outlook Setup Needed');
    while (setupWarning.evaluate().isNotEmpty) {
      final closeButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Close'),
      );
      if (closeButton.evaluate().isEmpty) break;
      await tester.tap(closeButton);
      await tester.pumpAndSettle();
    }

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Timer'), findsOneWidget);
    expect(find.text('Task list'), findsOneWidget);
    expect(find.text('Insights'), findsWidgets);
    expect(find.text('Notes'), findsOneWidget);

    final notesLabel = find.text('Notes');
    await tester.ensureVisible(notesLabel);
    await tester.tap(notesLabel);
    await tester.pumpAndSettle();

    expect(find.byType(NotesView), findsOneWidget);
  });
}
