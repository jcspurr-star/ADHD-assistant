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

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Timer'), findsOneWidget);
    expect(find.text('Task list'), findsOneWidget);
    expect(find.text('Insights'), findsWidgets);
    expect(find.text('Notes'), findsOneWidget);

    final notesButton = find.widgetWithText(OutlinedButton, 'Notes');
    await tester.ensureVisible(notesButton);
    await tester.tap(notesButton);
    await tester.pumpAndSettle();

    expect(find.byType(NotesView), findsOneWidget);
  });
}
