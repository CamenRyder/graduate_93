/// Quy tắc cho thẻ (tag) của bài viết. Dart thuần để tool/prerender.dart dùng
/// lại được.
library;

import 'post_slug.dart';

const int maxTagsPerPost = 8;
const int maxTagLength = 32;

/// Định danh ổn định của tag, dùng cho URL `/tags/<slug>` và để so khớp
/// ("Flutter Web" và "flutter  web" là cùng một tag).
String tagSlug(String tag) => postSlug(tag);

String tagPath(String tag) => '/tags/${tagSlug(tag)}';

/// Chuẩn hóa danh sách tag: gộp khoảng trắng, cắt độ dài, bỏ tag rỗng và
/// trùng (theo slug, giữ lần xuất hiện đầu), tối đa [maxTagsPerPost].
List<String> normalizeTags(Iterable<String> tags) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in tags) {
    var tag = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (tag.length > maxTagLength) {
      tag = tag.substring(0, maxTagLength).trimRight();
    }
    final slug = tagSlug(tag);
    if (slug.isEmpty || !seen.add(slug)) continue;
    result.add(tag);
    if (result.length == maxTagsPerPost) break;
  }
  return result;
}

/// Tách chuỗi người dùng gõ/dán ("a, b; c") thành các tag.
List<String> parseTagInput(String input) =>
    input.split(RegExp(r'[,;\n]')).where((t) => t.trim().isNotEmpty).toList();
