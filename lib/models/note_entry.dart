class NoteEntry {
  final String id;
  String title;
  String content;
  String updatedAtUtc;
  String kind;

  NoteEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAtUtc,
    this.kind = 'note',
  });

  factory NoteEntry.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc().toIso8601String();
    return NoteEntry(
      id: (json['id'] ?? '').toString().isNotEmpty
          ? json['id'].toString()
          : DateTime.now().microsecondsSinceEpoch.toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      updatedAtUtc: (json['updated_at_utc'] ?? now).toString(),
      kind: (json['kind'] ?? 'note').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'updated_at_utc': updatedAtUtc,
      'kind': kind,
    };
  }
}
