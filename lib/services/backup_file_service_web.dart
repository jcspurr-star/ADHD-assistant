// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class BackupFileServicePlatform {
  static Future<void> downloadBackup(
    String jsonContent,
    String filename,
  ) async {
    final bytes = utf8.encode(jsonContent);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static Future<String?> pickAndReadBackupFile() async {
    final input = html.FileUploadInputElement()..accept = '.json';
    final completer = Completer<String?>();

    void cleanup() {
      input.remove();
    }

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) {
        cleanup();
        completer.complete(null);
        return;
      }

      final file = files.first;
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        cleanup();
        final content = reader.result;
        completer.complete(content is String ? content : null);
      });
      reader.onError.listen((_) {
        cleanup();
        completer.complete(null);
      });
      reader.readAsText(file);
    });

    input.click();
    return completer.future;
  }
}
