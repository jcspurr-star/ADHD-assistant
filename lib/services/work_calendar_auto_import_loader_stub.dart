import 'work_calendar_auto_import_types.dart';

class WorkCalendarAutoImportLoaderPlatform {
  static Future<String?> loadContent() async {
    return null;
  }

  static Future<WorkCalendarAutoImportResult> loadWithDiagnostics() async {
    return const WorkCalendarAutoImportResult(
      content: null,
      status: 'Auto-import is not supported on this platform.',
    );
  }
}
