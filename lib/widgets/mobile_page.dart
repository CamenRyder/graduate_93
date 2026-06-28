import 'package:flutter/material.dart';

import 'contact_footer.dart';
import 'guest_logout_button.dart';
import 'guest_photos_button.dart';
import 'theme_toggle_button.dart';

/// Khung layout dùng chung cho các màn hướng tới điện thoại.
///
/// Bố cục: nút đăng xuất + đổi theme ở góc trên phải, nội dung ở giữa và một
/// widget cố định dưới đáy. Mọi màu lấy từ theme nên tự hợp cả Sáng lẫn Tối.
class MobilePage extends StatelessWidget {
  const MobilePage({
    super.key,
    required this.child,
    this.maxWidth = 280,
    this.bottom,
    this.scrollable = true,
  });

  /// Nội dung chính của màn (thường là một Column).
  final Widget child;

  /// Bề ngang tối đa của cột nội dung — giữ dòng chữ dễ đọc trên màn rộng.
  final double maxWidth;

  /// Widget cố định dưới đáy. Ở chế độ cuộn, mặc định là dòng "Liên hệ Minh
  /// Hiếu"; truyền widget khác để thay, hoặc [SizedBox.shrink] để bỏ trống.
  /// Ở chế độ KHÔNG cuộn, widget này nằm ngay dưới nội dung (không có mặc định).
  final Widget? bottom;

  /// `true` (mặc định): nội dung canh giữa, cuộn được trong cột hẹp.
  /// `false`: nội dung lấp đầy vùng giữa (KHÔNG cuộn) — cho màn cần ảnh co dãn
  /// theo chiều cao (vd dùng [Expanded]); [bottom] xếp ngay bên dưới nội dung.
  final bool scrollable;

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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GuestPhotosButton(),
                    GuestLogoutButton(),
                    ThemeToggleButton(),
                  ],
                ),
              ),
            ),
            if (scrollable)
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 72),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: child,
                  ),
                ),
              )
            else
              Positioned.fill(
                // Chừa trên cho cụm nút góc phải; nội dung lấp đầy, [bottom]
                // (nếu có) nằm ngay bên dưới.
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: child),
                      if (bottom != null) ...[
                        const SizedBox(height: 16),
                        bottom!,
                      ],
                    ],
                  ),
                ),
              ),
            // Chế độ cuộn: widget đáy neo cố định dưới cùng (mặc định liên hệ).
            if (scrollable)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: bottom ?? const ContactFooter(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
