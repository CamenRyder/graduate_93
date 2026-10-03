import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/models/post.dart';
import 'package:graduation_2026/models/post_category.dart';
import 'package:graduation_2026/pages/post_detail_page.dart';

Post _post(
  String id,
  String title, {
  List<String> tags = const [],
  bool published = true,
  int day = 1,
}) => Post(
  id: id,
  title: title,
  published: published,
  tags: tags,
  blocks: const [PostBlock(type: PostBlockType.paragraph, text: 'Nội dung')],
  timeCreated: DateTime(2026, 9, day),
  timeUpdated: null,
);

void main() {
  final current = _post('cur', 'Bài đang đọc', tags: ['Flutter Web', 'Đà Lạt']);

  Future<void> pumpDetail(WidgetTester tester, List<Post> all) async {
    await tester.binding.setSurfaceSize(const Size(900, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: PostDetailPage(
          postId: current.id,
          postStream: Stream.value(current),
          allPostsStream: Stream.value(all),
          categoriesStream: Stream.value(const <PostCategory>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hiện thẻ, nút chia sẻ và mục Đọc tiếp đã lọc nháp', (
    tester,
  ) async {
    await pumpDetail(tester, [
      current,
      _post('rel', 'Bài cùng thẻ', tags: ['flutter web'], day: 2),
      _post('draft', 'Bản nháp', tags: ['Flutter Web'], published: false),
    ]);

    expect(find.text('#Flutter Web'), findsOneWidget);
    expect(find.text('#Đà Lạt'), findsOneWidget);
    expect(find.text('SAO CHÉP LINK'), findsOneWidget);
    expect(find.text('FACEBOOK'), findsOneWidget);
    // Ngoài trình duyệt không có Web Share API -> không hiện nút này.
    expect(find.text('CHIA SẺ…'), findsNothing);
    expect(find.text('ĐỌC TIẾP'), findsOneWidget);
    expect(find.text('Bài cùng thẻ'), findsOneWidget);
    expect(find.text('Bản nháp'), findsNothing);
  });

  testWidgets('chỉ có một bài thì ẩn mục Đọc tiếp', (tester) async {
    await pumpDetail(tester, [current]);
    expect(find.text('ĐỌC TIẾP'), findsNothing);
  });

  testWidgets('sao chép link canonical vào clipboard và báo đã sao chép', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpDetail(tester, [current]);
    await tester.tap(find.text('SAO CHÉP LINK'));
    await tester.pumpAndSettle();

    expect(copied, 'https://graduation-e59ff.web.app/posts/cur/bai-dang-doc');
    expect(find.text('Đã sao chép liên kết'), findsOneWidget);
  });

  testWidgets('clipboard bị từ chối thì hiện link để tự sao chép', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'denied');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpDetail(tester, [current]);
    await tester.tap(find.text('SAO CHÉP LINK'));
    await tester.pumpAndSettle();

    expect(find.text('Đã sao chép liên kết'), findsNothing);
    expect(find.text('Sao chép liên kết'), findsOneWidget);
    expect(
      find.text('https://graduation-e59ff.web.app/posts/cur/bai-dang-doc'),
      findsOneWidget,
    );
  });

  testWidgets('clipboard treo (web từ chối quyền) thì sau 2 giây hiện link', (
    tester,
  ) async {
    final never = Completer<Object?>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) =>
          call.method == 'Clipboard.setData' ? never.future : Future.value(),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpDetail(tester, [current]);
    await tester.tap(find.text('SAO CHÉP LINK'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sao chép liên kết'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Sao chép liên kết'), findsOneWidget);
  });
}
