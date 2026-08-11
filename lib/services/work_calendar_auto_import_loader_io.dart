import 'dart:io';

import '../secrets.dart';
import 'work_calendar_auto_import_types.dart';

class WorkCalendarAutoImportLoaderPlatform {
  static Future<String?> loadContent() async {
    final result = await loadWithDiagnostics();
    return result.content;
  }

  static Future<WorkCalendarAutoImportResult> loadWithDiagnostics() async {
    final path = workCalendarAutoImportPath.trim();
    if (path.isEmpty) {
      return const WorkCalendarAutoImportResult(
        content: null,
        status: 'Local path is empty in workCalendarAutoImportPath.',
      );
    }

    try {
      final file = File(path);
      if (!await file.exists()) {
        return WorkCalendarAutoImportResult(
          content: null,
          status: 'Local ICS file not found at configured path.',
        );
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return const WorkCalendarAutoImportResult(
          content: null,
          status: 'Local ICS file is empty.',
        );
      }
      return WorkCalendarAutoImportResult(
        content: content,
        status: 'Loaded ICS content from local path.',
      );
    } catch (error) {
      return WorkCalendarAutoImportResult(
        content: null,
        status: 'Failed reading local ICS file: $error',
      );
    }
  }
}
