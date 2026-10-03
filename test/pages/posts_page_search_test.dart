import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/models/post.dart';
import 'package:graduation_2026/models/post_category.dart';
import 'package:graduation_2026/pages/posts_page.dart';

Post _post(
  String id,
  String title, {
  bool published = true,
  List<String> tags = const [],
}) => Post(
  id: id,
  title: title,
  published: published,
  tags: tags,
  blocks: const [PostBlock(type: PostBlockType.paragraph, text: 'Nội dung')],
  timeCreated: DateTime(2026, 10, 1),
  timeUpdated: null,
);

Widget _app({String initialQuery = '', String? tagSlug}) {
  return MaterialApp(
    home: PostsPage(
      initialQuery: initialQuery,
      tagSlug: tagSlug,
      postsStream: Stream.value([
        _post('a', 'Ghi chú Flutter', tags: const ['Flutter Web']),
        _post('b', 'Một ngày ở Đà Lạt'),
        _post('draft', 'Bản nháp Đà Lạt', published: false),
        _post(
          'draft-tag',
          'Nháp có thẻ',
          published: false,
          tags: const ['Flutter Web'],
        ),
      ]),
      categoriesStream: Stream.value(const <PostCategory>[]),
    ),
  );
}

void main() {
  testWidgets('gõ từ khóa lọc danh sách, xóa thì hiện lại đủ', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('2 BÀI VIẾT'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'da lat');
    await tester.pumpAndSettle();
    expect(find.text('1 KẾT QUẢ CHO “DA LAT”'), findsOneWidget);
    expect(find.text('Một ngày ở Đà Lạt'), findsOneWidget);
    expect(find.text('Ghi chú Flutter'), findsNothing);
    // Bản nháp không bao giờ lọt vào kết quả tìm kiếm.
    expect(find.text('Bản nháp Đà Lạt'), findsNothing);

    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await tester.pumpAndSettle();
    expect(find.text('2 BÀI VIẾT'), findsOneWidget);
  });

  testWidgets('?q= ban đầu mở ra đã lọc sẵn, không có kết quả thì báo rõ', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(initialQuery: 'khong co'));
    await tester.pumpAndSettle();
    expect(find.text('0 KẾT QUẢ CHO “KHONG CO”'), findsOneWidget);
    expect(
      find.text('Không tìm thấy bài viết nào khớp “khong co”.'),
      findsOneWidget,
    );
  });

  testWidgets('/tags/:slug chỉ hiện bài đã đăng có thẻ đó, tiêu đề là #nhãn', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(tagSlug: 'flutter-web'));
    await tester.pumpAndSettle();
    expect(find.text('#Flutter Web'), findsOneWidget);
    expect(find.text('1 BÀI VIẾT'), findsOneWidget);
    expect(find.text('Ghi chú Flutter'), findsOneWidget);
    expect(find.text('Nháp có thẻ'), findsNothing);
  });

  testWidgets('thẻ không có bài nào thì báo rỗng', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(tagSlug: 'khong-ton-tai'));
    await tester.pumpAndSettle();
    expect(find.text('#khong-ton-tai'), findsOneWidget);
    expect(find.text('0 BÀI VIẾT'), findsOneWidget);
  });
}
