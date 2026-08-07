import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/widgets/text_input_dialog.dart';

void main() {
  Widget testApp({required ValueChanged<BuildContext> onOpen}) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => onOpen(context),
            child: const Text('Mở popup'),
          ),
        ),
      ),
    );
  }

  testWidgets('validate và trim nội dung nhập một dòng', (tester) async {
    String? result;

    await tester.pumpWidget(
      testApp(
        onOpen: (context) async {
          result = await showTextInputDialog(
            context,
            title: 'Tạo thư mục mới',
            labelText: 'Tên thư mục',
            confirmLabel: 'Tạo',
            emptyErrorText: 'Vui lòng nhập tên thư mục.',
          );
        },
      ),
    );

    await tester.tap(find.text('Mở popup'));
    await tester.pumpAndSettle();

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Tạo thư mục mới'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo'));
    await tester.pump();

    expect(find.text('Vui lòng nhập tên thư mục.'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(find.byType(TextFormField), '  Lễ tốt nghiệp  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo'));
    await tester.pumpAndSettle();

    expect(result, 'Lễ tốt nghiệp');
  });

  testWidgets('giữ nguyên nội dung nhiều dòng và cho phép để trống', (
    tester,
  ) async {
    String? result;

    await tester.pumpWidget(
      testApp(
        onOpen: (context) async {
          result = await showTextInputDialog(
            context,
            title: 'Message',
            initialValue: 'Nội dung cũ',
            confirmLabel: 'Xong',
            minLines: 3,
            maxLines: 6,
            allowEmpty: true,
            trimResult: false,
          );
        },
      ),
    );

    await tester.tap(find.text('Mở popup'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Dòng 1\nDòng 2  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Xong'));
    await tester.pumpAndSettle();

    expect(result, 'Dòng 1\nDòng 2  ');
  });
}
