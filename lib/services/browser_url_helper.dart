import 'browser_url_helper_stub.dart'
    if (dart.library.html) 'browser_url_helper_web.dart';

void replaceBrowserUrl(String url) {
  replaceBrowserUrlImpl(url);
}
