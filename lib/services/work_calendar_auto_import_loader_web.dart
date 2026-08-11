import 'work_calendar_auto_import_types.dart';

class WorkCalendarAutoImportLoaderPlatform {
  static Future<String?> loadContent() async {
    return null;
  }

  static Future<WorkCalendarAutoImportResult> loadWithDiagnostics() async {
    return const WorkCalendarAutoImportResult(
      content: null,
      status:
          'Auto-import from web URL is disabled for web builds. Use Import .ics manually.',
    );
  }
}
