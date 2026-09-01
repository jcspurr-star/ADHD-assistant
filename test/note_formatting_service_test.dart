import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adhd_assistant/services/note_formatting_service.dart';

void main() {
  group('toggleWrap', () {
    test('wraps a selection with the marker', () {
      final controller = TextEditingController(text: 'hello world');
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );

      NoteFormattingService.toggleWrap(controller, '**');

      expect(controller.text, '**hello** world');
    });

    test('unwraps an already-wrapped selection', () {
      final controller = TextEditingController(text: '**hello** world');
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 9,
      );

      NoteFormattingService.toggleWrap(controller, '**');

      expect(controller.text, 'hello world');
    });

    test('inserts an empty pair and places the cursor between them', () {
      final controller = TextEditingController(text: 'hello');
      controller.selection = const TextSelection.collapsed(offset: 5);

      NoteFormattingService.toggleWrap(controller, '*');

      expect(controller.text, 'hello**');
      expect(controller.selection.baseOffset, 6);
    });
  });

  group('toggleBulletLines', () {
    test('adds bullets to touched lines', () {
      final controller = TextEditingController(text: 'first\nsecond\nthird');
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );

      NoteFormattingService.toggleBulletLines(controller);

      expect(controller.text, '• first\n• second\n• third');
    });

    test('removes bullets when all touched lines already have one', () {
      final controller = TextEditingController(
        text: '• first\n• second\n• third',
      );
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );

      NoteFormattingService.toggleBulletLines(controller);

      expect(controller.text, 'first\nsecond\nthird');
    });
  });

  group('stripForPreview', () {
    test('removes bold, italic and bullet markers', () {
      final result = NoteFormattingService.stripForPreview(
        '• **Buy** milk and *bread*',
      );

      expect(result, 'Buy milk and bread');
    });
  });
}
