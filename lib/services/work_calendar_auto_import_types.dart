class WorkCalendarAutoImportResult {
  final String? content;
  final String status;

  const WorkCalendarAutoImportResult({
    required this.content,
    required this.status,
  });

  bool get success => content != null && content!.trim().isNotEmpty;
}
