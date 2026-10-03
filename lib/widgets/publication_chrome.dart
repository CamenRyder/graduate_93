import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/theme_controller.dart';
import '../theme.dart';

/// Điều hướng tối giản dùng chung cho trang chủ, kho bài và trang đọc.
class PublicationHeader extends StatelessWidget {
  const PublicationHeader({
    super.key,
    this.onWriting,
    this.onNotes,
    this.onAbout,
  });

  final VoidCallback? onWriting;
  final VoidCallback? onNotes;
  final VoidCallback? onAbout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        return Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 32,
                  vertical: compact ? 12 : 16,
                ),
                child: Row(
                  children: [
                    // Logo co lại (cắt chữ) thay vì làm tràn hàng trên màn hẹp.
                    Flexible(
                      child: _Wordmark(
                        onTap: () => context.go('/'),
                        compact: compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Spacer(),
                    _TextLink(
                      label: 'Bài viết',
                      onTap: onWriting ?? () => context.go('/posts'),
                    ),
                    if (!compact) ...[
                      _TextLink(
                        label: 'Ghi chú',
                        onTap: onNotes ?? () => context.go('/?section=notes'),
                      ),
                      _TextLink(
                        label: 'Giới thiệu',
                        onTap: onAbout ?? () => context.go('/?section=about'),
                      ),
                    ],
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: isDark
                          ? 'Chuyển chế độ sáng'
                          : 'Chuyển chế độ tối',
                      iconSize: 19,
                      color: colors.onSurfaceVariant,
                      icon: Icon(
                        isDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                      onPressed: () => themeController.setMode(
                        isDark ? ThemeMode.light : ThemeMode.dark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Logo chữ: tên viết bằng serif nghiêng + nhãn mono nhỏ.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.onTap, required this.compact});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      link: true,
      label: 'Trang chủ',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  'Minh Hiếu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.serif(
                    size: 22,
                    weight: FontWeight.w600,
                    style: FontStyle.italic,
                    letterSpacing: -0.3,
                    color: colors.onSurface,
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                Text(
                  'NOTES',
                  style: AppTheme.mono(
                    size: 10.5,
                    weight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: colors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PublicationFooter extends StatelessWidget {
  const PublicationFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(top: 28, bottom: 40),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final style = TextStyle(
            fontFamily: AppTheme.monoFont,
            fontSize: 12,
            letterSpacing: 0.2,
            color: colors.onSurfaceVariant,
          );
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('© 2026 Minh Hiếu', style: style),
                const SizedBox(height: 8),
                Text('Được viết và lưu giữ tại Việt Nam.', style: style),
              ],
            );
          }
          return Row(
            children: [
              Text('© 2026 Minh Hiếu', style: style),
              const Spacer(),
              Text('Được viết và lưu giữ tại Việt Nam.', style: style),
            ],
          );
        },
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: colors.onSurface,
        minimumSize: const Size(44, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(
          fontFamily: AppTheme.sansFont,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Text(label),
    );
  }
}
