import 'work_calendar_auto_import_loader_stub.dart'
    if (dart.library.io) 'work_calendar_auto_import_loader_io.dart'
    if (dart.library.html) 'work_calendar_auto_import_loader_web.dart';
import 'work_calendar_auto_import_types.dart';

class WorkCalendarAutoImportLoader {
  static Future<String?> loadContent() {
    return WorkCalendarAutoImportLoaderPlatform.loadContent();
  }

  static Future<WorkCalendarAutoImportResult> loadWithDiagnostics() {
    return WorkCalendarAutoImportLoaderPlatform.loadWithDiagnostics();
  }
}
