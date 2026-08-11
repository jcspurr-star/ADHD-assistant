// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

class IcsFileLoaderPlatform {
  static Future<String?> pickAndReadContent() async {
    final input = html.FileUploadInputElement()..accept = '.ics';
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
