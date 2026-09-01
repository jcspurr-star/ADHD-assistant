import 'package:flutter_test/flutter_test.dart';
import 'package:adhd_assistant/models/note_entry.dart';

void main() {
  test('round trips ingredients and instructions for a recipe', () {
    final entry = NoteEntry(
      id: 'r1',
      title: 'Pancakes',
      content: '',
      updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
      kind: 'recipe',
      ingredients: '• Flour\n• Eggs',
      instructions: '1. Mix\n2. Cook',
    );

    final decoded = NoteEntry.fromJson(entry.toJson());

    expect(decoded.ingredients, '• Flour\n• Eggs');
    expect(decoded.instructions, '1. Mix\n2. Cook');
  });

  test('migrates legacy recipe content into instructions on load', () {
    final decoded = NoteEntry.fromJson({
      'id': 'legacy-1',
      'title': 'Old recipe',
      'content': 'Old freeform recipe body',
      'kind': 'recipe',
      'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
    });

    expect(decoded.instructions, 'Old freeform recipe body');
    expect(decoded.ingredients, isEmpty);
  });

  test(
    'does not migrate content when ingredients/instructions already set',
    () {
      final decoded = NoteEntry.fromJson({
        'id': 'r2',
        'title': 'Soup',
        'content': 'Legacy body should be ignored',
        'kind': 'recipe',
        'ingredients': 'Carrots',
        'instructions': 'Boil everything',
        'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
      });

      expect(decoded.ingredients, 'Carrots');
      expect(decoded.instructions, 'Boil everything');
    },
  );

  test('plain notes are unaffected by recipe migration', () {
    final decoded = NoteEntry.fromJson({
      'id': 'n1',
      'title': 'Shopping list',
      'content': 'Milk, eggs, bread',
      'kind': 'note',
      'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
    });

    expect(decoded.content, 'Milk, eggs, bread');
    expect(decoded.ingredients, isEmpty);
    expect(decoded.instructions, isEmpty);
  });
}
