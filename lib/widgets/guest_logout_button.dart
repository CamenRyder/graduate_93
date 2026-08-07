import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/guest_controller.dart';
import 'confirm_dialog.dart';

/// Nút đăng xuất khách mời, đặt cạnh nút đổi theme.
///
/// Chỉ hiện khi khách đã xác thực. Bấm -> hỏi xác nhận (dialog theo style dự án)
/// -> xóa phiên khách; router (refreshListenable) tự đưa về trang nhập code `/`.
class GuestLogoutButton extends StatelessWidget {
  const GuestLogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!guestController.isAuthenticated) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Đăng xuất',
      icon: const Icon(Icons.logout),
      onPressed: () => _logout(context),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await _confirmLogout(context);
    if (!ok) return;
    await guestController.signOut();
    // Router (refreshListenable) tự đưa về '/'; gọi thêm cho chắc.
    if (context.mounted) context.go('/');
  }

  Future<bool> _confirmLogout(BuildContext context) async {
    return showConfirmDialog(
      context,
      title: 'Đăng xuất?',
      message: 'Bạn sẽ cần nhập lại mã code để vào lại nhe.',
      confirmLabel: 'Đăng xuất',
      cancelLabel: 'Ở lại',
      icon: Icons.logout_rounded,
    );
  }
}
