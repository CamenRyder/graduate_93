import 'package:flutter/material.dart';

import 'contact_footer.dart';
import 'theme_toggle_button.dart';

/// Khung layout dùng chung cho các màn hướng tới điện thoại.
///
/// Bố cục: nút đổi theme ở góc trên phải, nội dung canh giữa trong một cột hẹp
/// (cuộn được khi tràn / khi bật bàn phím) và dòng liên hệ cố định dưới đáy.
/// Mọi màu đều lấy từ theme nên tự hợp cả chế độ Sáng lẫn Tối.
class MobilePage extends StatelessWidget {
  const MobilePage({
    super.key,
    required this.child,
    this.maxWidth = 280,
  });

  /// Nội dung chính của màn (thường là một Column).
  final Widget child;

  /// Bề ngang tối đa của cột nội dung — giữ dòng chữ dễ đọc trên màn rộng.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: ThemeToggleButton(),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 72),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: child,
                ),
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 28),
                child: ContactFooter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
