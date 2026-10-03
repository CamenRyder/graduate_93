import '../models/post.dart';
import 'post_tags.dart';

/// Chọn tối đa [limit] bài để gợi ý đọc tiếp sau [current].
///
/// Chỉ xét bài đã đăng, trừ chính [current]. Điểm = 3 × số tag trùng + 2 nếu
/// cùng danh mục; bằng điểm thì bài mới hơn trước. Chưa đủ [limit] thì bổ sung
/// bằng các bài mới nhất còn lại, để cuối bài luôn có gợi ý khi blog còn ít bài.
List<Post> relatedPosts(Post current, List<Post> all, {int limit = 3}) {
  final currentTags = {for (final tag in current.tags) tagSlug(tag)};
  int score(Post post) {
    final shared = post.tags.where((t) => currentTags.contains(tagSlug(t)));
    final sameCategory =
        current.categoryId.isNotEmpty && post.categoryId == current.categoryId;
    return shared.length * 3 + (sameCategory ? 2 : 0);
  }

  DateTime when(Post post) =>
      post.timeCreated ??
      post.timeUpdated ??
      DateTime.fromMillisecondsSinceEpoch(0);

  final candidates = [
    for (final post in all)
      if (post.published && post.id != current.id) post,
  ]..sort((a, b) => when(b).compareTo(when(a)));

  final scored =
      [
        for (final post in candidates)
          if (score(post) > 0) post,
      ]..sort((a, b) {
        // List.sort không ổn định: so thêm ngày để bằng điểm thì bài mới trước.
        final byScore = score(b).compareTo(score(a));
        return byScore != 0 ? byScore : when(b).compareTo(when(a));
      });

  final picked = scored.take(limit).toList();
  for (final post in candidates) {
    if (picked.length >= limit) break;
    if (!picked.contains(post)) picked.add(post);
  }
  return picked;
}
