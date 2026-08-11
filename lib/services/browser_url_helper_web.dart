import 'dart:js_interop';

@JS('window.history.replaceState')
external void _replaceState(JSAny? data, JSString title, JSString url);

void replaceBrowserUrlImpl(String url) {
  _replaceState(null, ''.toJS, url.toJS);
}
