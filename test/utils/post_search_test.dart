import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/models/post.dart';
import 'package:graduation_2026/utils/post_search.dart';
import 'package:graduation_2026/utils/post_slug.dart';

Post _post(
  String id,
  String title, {
  String body = '',
  String category = '',
  PostBlockType type = PostBlockType.paragraph,
}) {
  return Post(
    id: id,
    title: title,
    published: true,
    categoryId: category,
    blocks: [if (body.isNotEmpty) PostBlock(type: type, text: body)],
    timeCreated: null,
    timeUpdated: null,
  );
}

List<String> _ids(List<Post> posts) => [for (final p in posts) p.id];

void main() {
  group('foldVietnamese', () {
    test('bỏ dấu dạng dựng sẵn và dạng tổ hợp', () {
      expect(foldVietnamese('Tốt Nghiệp ĐẸP'), 'tot nghiep dep');
      // "ố" viết bằng o + U+0302 + U+0301.
      expect(foldVietnamese('tốt'), 'tot');
    });
  });

  group('searchPosts', () {
    final posts = [
      _post('a', 'Ghi chú Flutter', body: 'Cách dựng router'),
      _post('b', 'Một ngày ở Đà Lạt', body: 'Ghi lại chuyến đi Flutter camp'),
      _post('c', 'Thiết kế hệ thống', category: 'ky-thuat'),
      _post(
        'd',
        'Snippet',
        body: 'final x = flutterRouter;',
        type: PostBlockType.code,
      ),
    ];

    test('truy vấn rỗng hoặc toàn khoảng trắng trả nguyên danh sách', () {
      expect(_ids(searchPosts(posts, '')), ['a', 'b', 'c', 'd']);
      expect(_ids(searchPosts(posts, '   ')), ['a', 'b', 'c', 'd']);
    });

    test('gõ không dấu vẫn khớp tiêu đề có dấu', () {
      expect(_ids(searchPosts(posts, 'da lat')), ['b']);
      expect(_ids(searchPosts(posts, 'ĐÀ   LẠT')), ['b']);
    });

    test('mọi từ phải xuất hiện (AND)', () {
      expect(_ids(searchPosts(posts, 'flutter router')), ['a', 'd']);
      expect(_ids(searchPosts(posts, 'flutter khongco')), isEmpty);
    });

    test('bài khớp ở tiêu đề xếp trước bài khớp ở nội dung', () {
      expect(_ids(searchPosts(posts, 'flutter')), ['a', 'b', 'd']);
    });

    test('khớp theo tên danh mục', () {
      expect(
        _ids(
          searchPosts(
            posts,
            'ky thuat',
            categoryNames: {'ky-thuat': 'Kỹ thuật'},
          ),
        ),
        ['c'],
      );
    });

    test('không làm thay đổi danh sách đầu vào', () {
      final input = List<Post>.of(posts);
      searchPosts(input, 'flutter');
      expect(_ids(input), ['a', 'b', 'c', 'd']);
    });
  });
}
