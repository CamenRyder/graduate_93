import 'package:flutter/material.dart';

/// Dialog xác nhận dùng chung, theo style Material 3 của hệ thống.
///
/// [destructive] = true -> dùng tông màu đỏ (error) cho hành động nguy hiểm
/// như xóa. Trả về `true` nếu người dùng xác nhận.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Đồng ý',
  String cancelLabel = 'Hủy',
  IconData icon = Icons.help_outline,
  bool destructive = false,
}) async {
  final colorScheme = Theme.of(context).colorScheme;

  final accent = destructive ? colorScheme.error : colorScheme.primary;
  final onAccent = destructive ? colorScheme.onError : colorScheme.onPrimary;
  final accentContainer =
      destructive ? colorScheme.errorContainer : colorScheme.primaryContainer;
  final onAccentContainer = destructive
      ? colorScheme.onErrorContainer
      : colorScheme.onPrimaryContainer;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: accentContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: onAccentContainer, size: 28),
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: onAccent,
            // không kéo dài full-width như nút trong form
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return result ?? false;
}
