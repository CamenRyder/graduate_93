import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/models/post.dart';
import 'package:graduation_2026/utils/related_posts.dart';

Post _post(
  String id, {
  int day = 1,
  String category = '',
  List<String> tags = const [],
  bool published = true,
}) => Post(
  id: id,
  title: id,
  published: published,
  categoryId: category,
  tags: tags,
  blocks: const [],
  timeCreated: DateTime(2026, 9, day),
  timeUpdated: null,
);

List<String> _ids(List<Post> posts) => [for (final p in posts) p.id];

void main() {
  final current = _post('cur', category: 'tech', tags: ['Flutter', 'Web']);

  test('xếp theo điểm: tag trùng nặng hơn cùng danh mục', () {
    final all = [
      current,
      _post('same-cat', day: 9, category: 'tech'),
      _post('two-tags', day: 2, tags: ['flutter', 'WEB']),
      _post('one-tag', day: 3, tags: ['Flutter']),
      _post('none', day: 30),
    ];
    // two-tags = 6, one-tag = 3, same-cat = 2.
    expect(_ids(relatedPosts(current, all)), [
      'two-tags',
      'one-tag',
      'same-cat',
    ]);
  });

  test('bằng điểm thì bài mới hơn trước', () {
    final all = [
      _post('old', day: 1, category: 'tech'),
      _post('new', day: 20, category: 'tech'),
      _post('mid', day: 10, category: 'tech'),
    ];
    expect(_ids(relatedPosts(current, all)), ['new', 'mid', 'old']);
  });

  test('loại bản nháp và chính bài đang đọc', () {
    final all = [
      current,
      _post('draft', tags: ['Flutter'], published: false),
      _post('ok', tags: ['Flutter']),
    ];
    expect(_ids(relatedPosts(current, all)), ['ok']);
  });

  test('thiếu bài liên quan thì bổ sung bằng bài mới nhất', () {
    final all = [
      _post('match', day: 1, tags: ['Web']),
      _post('latest', day: 28),
      _post('older', day: 5),
      _post('oldest', day: 2),
    ];
    expect(_ids(relatedPosts(current, all)), ['match', 'latest', 'older']);
    expect(relatedPosts(current, [current]), isEmpty);
  });

  test('bài không danh mục không được tính là "cùng danh mục"', () {
    final noCategory = _post('cur2');
    final all = [_post('a', day: 1), _post('b', day: 2)];
    // Không có điểm -> chỉ còn thứ tự mới nhất.
    expect(_ids(relatedPosts(noCategory, all, limit: 2)), ['b', 'a']);
  });
}
