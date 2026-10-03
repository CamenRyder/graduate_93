import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

bool canShareNatively() => (web.window.navigator as JSObject).has('share');

Future<bool> shareNatively({required String title, required String url}) async {
  if (!canShareNatively()) return false;
  try {
    await web.window.navigator
        .share(web.ShareData(title: title, url: url))
        .toDart;
    return true;
  } catch (_) {
    // AbortError khi người dùng đóng menu chia sẻ — không phải lỗi.
    return false;
  }
}

void openWindow(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}
