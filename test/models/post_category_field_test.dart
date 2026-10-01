import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/models/post.dart';

void main() {
  test('Post ghi category_id và hỗ trợ bài chưa phân loại', () {
    const categorized = Post(
      id: 'post-1',
      title: 'Bài viết',
      published: true,
      categoryId: 'cong-nghe',
      blocks: [],
      timeCreated: null,
      timeUpdated: null,
    );
    const uncategorized = Post(
      id: 'post-2',
      title: 'Bài cũ',
      published: false,
      blocks: [],
      timeCreated: null,
      timeUpdated: null,
    );

    expect(categorized.toFirestore()['category_id'], 'cong-nghe');
    expect(uncategorized.categoryId, isEmpty);
    expect(uncategorized.toFirestore()['category_id'], isEmpty);
  });
}
