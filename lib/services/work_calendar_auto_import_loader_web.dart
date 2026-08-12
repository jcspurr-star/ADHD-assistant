import 'work_calendar_auto_import_types.dart';

class WorkCalendarAutoImportLoaderPlatform {
  static Future<String?> loadContent() async {
    final result = await loadWithDiagnostics();
    return result.content;
  }

  static Future<WorkCalendarAutoImportResult> loadWithDiagnostics() async {
    return const WorkCalendarAutoImportResult(
      content: null,
      status:
          'Auto-import from local file path is not supported on web. Use Import .ics manually.',
    );
  }
}
