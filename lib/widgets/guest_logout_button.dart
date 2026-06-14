import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/guest_controller.dart';
import '../theme/app_styles.dart';

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

  /// Dialog xác nhận theo gu dự án: bo góc, chữ monospace, nút phẳng bo 12 —
  /// nút chính xanh thương hiệu (chữ trắng), nút phụ nền xám nhạt.
  Future<bool> _confirmLogout(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: kBrandGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, color: kBrandGreen, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  'Đăng xuất?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Bạn sẽ cần nhập lại mã code để vào lại nhe.',
                  textAlign: TextAlign.center,
                  style: messageTextStyle(ctx),
                ),
                const SizedBox(height: 24),
                _DialogAction(
                  label: 'Đăng xuất',
                  background: kBrandGreen,
                  foreground: Colors.white,
                  onTap: () => Navigator.pop(ctx, true),
                ),
                const SizedBox(height: 10),
                _DialogAction(
                  label: 'Ở lại',
                  background: colorScheme.surfaceContainerHighest,
                  foreground: colorScheme.onSurface,
                  onTap: () => Navigator.pop(ctx, false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result ?? false;
  }
}

/// Nút trong dialog: nền phẳng bo góc 12, chữ đậm canh giữa — đồng bộ với nút
/// "Gửi" / nút hành động ở màn auth.
class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
