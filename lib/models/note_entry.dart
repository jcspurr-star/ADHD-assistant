class NoteEntry {
  final String id;
  String title;
  String content;
  String updatedAtUtc;
  String kind;
  // Recipes ('kind' == 'recipe') store their body as these two separate
  // sections instead of using 'content'.
  String ingredients;
  String instructions;

  NoteEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAtUtc,
    this.kind = 'note',
    this.ingredients = '',
    this.instructions = '',
  });

  factory NoteEntry.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc().toIso8601String();
    final kind = (json['kind'] ?? 'note').toString();
    final content = (json['content'] ?? '').toString();
    final ingredients = (json['ingredients'] ?? '').toString();
    var instructions = (json['instructions'] ?? '').toString();
    // Migrate pre-existing recipes (body freeform in 'content') into the
    // instructions section the first time they're loaded.
    if (kind == 'recipe' &&
        ingredients.isEmpty &&
        instructions.isEmpty &&
        content.isNotEmpty) {
      instructions = content;
    }
    return NoteEntry(
      id: (json['id'] ?? '').toString().isNotEmpty
          ? json['id'].toString()
          : DateTime.now().microsecondsSinceEpoch.toString(),
      title: (json['title'] ?? '').toString(),
      content: content,
      updatedAtUtc: (json['updated_at_utc'] ?? now).toString(),
      kind: kind,
      ingredients: ingredients,
      instructions: instructions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'updated_at_utc': updatedAtUtc,
      'kind': kind,
      'ingredients': ingredients,
      'instructions': instructions,
    };
  }
}
