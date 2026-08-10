import 'ics_file_loader_stub.dart'
    if (dart.library.html) 'ics_file_loader_web.dart';

class IcsFileLoader {
  static Future<String?> pickAndReadContent() {
    return IcsFileLoaderPlatform.pickAndReadContent();
  }
}
