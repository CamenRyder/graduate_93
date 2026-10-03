import '../models/post.dart';
import 'post_slug.dart';

/// Chuẩn hóa chuỗi để so khớp: bỏ dấu, chữ thường, gộp khoảng trắng.
String normalizeSearchText(String text) =>
    foldVietnamese(text).replaceAll(RegExp(r'\s+'), ' ').trim();

/// Lọc [posts] theo [query] ngay trên danh sách đã tải (không gọi Firestore).
///
/// Bài khớp khi MỌI từ trong truy vấn xuất hiện ở tiêu đề, nội dung văn bản,
/// thẻ hoặc tên danh mục (tra qua [categoryNames] theo `categoryId`). Bài có từ
/// khóa nằm trong tiêu đề được đưa lên trước; trong cùng nhóm giữ nguyên thứ
/// tự đầu vào (mới nhất trước). Truy vấn rỗng trả lại nguyên danh sách.
List<Post> searchPosts(
  List<Post> posts,
  String query, {
  Map<String, String> categoryNames = const {},
}) {
  final terms = normalizeSearchText(
    query,
  ).split(' ').where((t) => t.isNotEmpty).toList(growable: false);
  if (terms.isEmpty) return posts;

  final titleHits = <Post>[];
  final bodyHits = <Post>[];
  for (final post in posts) {
    final title = normalizeSearchText(post.title);
    final haystack = [
      title,
      normalizeSearchText(categoryNames[post.categoryId] ?? ''),
      for (final tag in post.tags) normalizeSearchText(tag),
      for (final block in post.blocks)
        if (block.type.isText) normalizeSearchText(block.text),
    ].join('\n');
    if (!terms.every(haystack.contains)) continue;
    (terms.any(title.contains) ? titleHits : bodyHits).add(post);
  }
  return [...titleHits, ...bodyHits];
}
