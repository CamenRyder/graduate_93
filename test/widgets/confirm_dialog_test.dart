import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/widgets/confirm_dialog.dart';

void main() {
  testWidgets('hiển thị nền blur và hai nút hành động xếp dọc', (tester) async {
    bool? result;
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.green);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, colorScheme: colorScheme),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showConfirmDialog(
                  context,
                  title: 'Xác nhận?',
                  message: 'Bạn có muốn tiếp tục không?',
                  confirmLabel: 'Tiếp tục',
                  cancelLabel: 'Hủy',
                );
              },
              child: const Text('Mở popup'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở popup'));
    await tester.pumpAndSettle();

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Xác nhận?'), findsOneWidget);
    expect(find.text('Bạn có muốn tiếp tục không?'), findsOneWidget);

    final confirmFinder = find.widgetWithText(FilledButton, 'Tiếp tục');
    final cancelFinder = find.widgetWithText(FilledButton, 'Hủy');
    expect(confirmFinder, findsOneWidget);
    expect(cancelFinder, findsOneWidget);
    expect(
      tester.getTopLeft(confirmFinder).dy,
      lessThan(tester.getTopLeft(cancelFinder).dy),
    );

    final confirmButton = tester.widget<FilledButton>(confirmFinder);
    final cancelButton = tester.widget<FilledButton>(cancelFinder);
    expect(
      confirmButton.style?.backgroundColor?.resolve({}),
      colorScheme.primary,
    );
    expect(confirmButton.style?.foregroundColor?.resolve({}), Colors.white);
    expect(cancelButton.style?.foregroundColor?.resolve({}), Colors.white);

    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
