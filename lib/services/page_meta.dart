import '../utils/seo.dart';
import 'page_meta_stub.dart'
    if (dart.library.js_interop) 'page_meta_web.dart'
    as impl;

/// Cập nhật `<title>`, description, canonical và thẻ Open Graph/Twitter của
/// trang đang mở. Google chạy JS nên đọc được các giá trị này; mạng xã hội
/// thì không — phần đó do HTML tĩnh sinh lúc build (tool/prerender.dart).
///
/// Ngoài web (test VM) là no-op.
class PageMeta {
  PageMeta._();

  static String? _lastKey;

  static void set(SeoMeta meta) {
    // Trang gọi trong build(): bỏ qua nếu không có gì đổi để khỏi đụng DOM
    // mỗi frame.
    final key = '${meta.canonicalUrl}|${meta.fullTitle}|${meta.description}';
    if (key == _lastKey) return;
    _lastKey = key;
    impl.applySeoMeta(meta);
  }

  /// Về meta mặc định của site (vd khi rời trang chi tiết bài).
  static void reset() => set(const SeoMeta(path: '/'));
}
