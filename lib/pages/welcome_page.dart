import 'package:flutter/material.dart';

import '../widgets/contact_footer.dart';
import '../widgets/theme_toggle_button.dart';
import '../widgets/typing_text.dart';

/// Trang chủ sau khi khách xác thực xong.
///
/// Router đảm bảo chỉ khách đã xác thực mới vào được đây, và không cho quay lại
/// trang nhập code (xem redirect trong `router.dart`). Vì vậy trang này không
/// cần tự kiểm tra cache nữa.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

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
              child: TypingText(
                'Trang chủ hẹ hẹ',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface,
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
