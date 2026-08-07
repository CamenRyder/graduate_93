import 'package:flutter/material.dart';

import 'app_dialog.dart';

/// Hiển thị popup xác nhận dùng chung của ứng dụng.
///
/// Popup có lớp nền tối và blur để nội dung chính nổi bật hơn. Hai nút hành
/// động luôn xếp dọc: xác nhận ở trên, hủy ở dưới. Khi [destructive] là true,
/// hành động xác nhận dùng màu lỗi để cảnh báo cho các thao tác như xóa.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Đồng ý',
  String cancelLabel = 'Hủy',
  IconData icon = Icons.help_outline_rounded,
  bool destructive = false,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  final accentColor = destructive ? colorScheme.error : colorScheme.primary;

  final result = await showAppDialog<bool>(
    context,
    builder: (dialogContext) => AppDialogCard(
      title: title,
      icon: icon,
      accentColor: accentColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 26),
          AppDialogActionButton(
            label: confirmLabel,
            backgroundColor: accentColor,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
          const SizedBox(height: 10),
          AppDialogActionButton(
            label: cancelLabel,
            backgroundColor: appDialogCancelColor,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ],
      ),
    ),
  );

  return result ?? false;
}
