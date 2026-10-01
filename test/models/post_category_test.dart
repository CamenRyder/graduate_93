import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/models/post_category.dart';

void main() {
  group('PostCategory', () {
    test('đọc dữ liệu an toàn và dùng document id làm slug', () {
      final category = PostCategory.fromMap(
        id: 'cong-nghe',
        data: const {
          'name': '  Công nghệ  ',
          'description': '  Tin và bài viết mới  ',
          'visible': false,
          'sort_order': 2.0,
        },
      );

      expect(category.slug, 'cong-nghe');
      expect(category.name, 'Công nghệ');
      expect(category.description, 'Tin và bài viết mới');
      expect(category.visible, isFalse);
      expect(category.sortOrder, 2);
    });

    test('dùng giá trị mặc định cho category cũ thiếu field', () {
      final category = PostCategory.fromMap(id: 'chia-se', data: const {});

      expect(category.name, isEmpty);
      expect(category.description, isEmpty);
      expect(category.visible, isTrue);
      expect(category.sortOrder, 0);
    });
  });
}
