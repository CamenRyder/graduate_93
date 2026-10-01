import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/models/post.dart';
import 'package:graduation_2026/pages/blog_admin_dashboard.dart';

void main() {
  testWidgets('dashboard blog hiển thị tốt trên màn hình mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final posts = [
      Post(
        id: 'published-post',
        title: 'Bài viết đầu tiên',
        published: true,
        blocks: const [
          PostBlock(type: PostBlockType.paragraph, text: 'Nội dung'),
        ],
        timeCreated: DateTime(2026, 8, 13),
        timeUpdated: null,
      ),
      Post(
        id: 'draft-post',
        title: 'Bản nháp mới',
        published: false,
        blocks: const [PostBlock(type: PostBlockType.image)],
        timeCreated: DateTime(2026, 8, 12),
        timeUpdated: null,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: BlogAdminDashboard(postsStream: Stream.value(posts))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blog Studio'), findsOneWidget);
    expect(find.text('Tổng bài viết'), findsOneWidget);
    expect(find.text('Đã xuất bản'), findsOneWidget);
    expect(find.text('Bản nháp'), findsWidgets);
    expect(find.text('Bài viết đầu tiên'), findsOneWidget);
    expect(find.text('Danh mục bài viết'), findsOneWidget);
    expect(find.text('Quản lý Users'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
