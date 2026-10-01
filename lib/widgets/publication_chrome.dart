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
                  horizontal: compact ? 20 : 32,
                  vertical: compact ? 18 : 22,
                ),
                child: Row(
                  children: [
                    _TextLink(
                      label: compact ? 'MH' : 'MINH HIẾU / NOTES',
                      onTap: () => context.go('/'),
                      strong: true,
                    ),
                    const Spacer(),
                    _TextLink(
                      label: 'Bài viết',
                      onTap: onWriting ?? () => context.go('/posts'),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 20),
                      _TextLink(
                        label: 'Ghi chú',
                        onTap: onNotes ?? () => context.go('/?section=notes'),
                      ),
                      const SizedBox(width: 20),
                      _TextLink(
                        label: 'Giới thiệu',
                        onTap: onAbout ?? () => context.go('/?section=about'),
                      ),
                    ],
                    SizedBox(width: compact ? 12 : 22),
                    _TextLink(
                      label: isDark ? 'Sáng' : 'Tối',
                      color: colors.primary,
                      onTap: () => themeController.setMode(
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
  const _TextLink({
    required this.label,
    required this.onTap,
    this.strong = false,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.monoFont,
            fontSize: 12.5,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: strong ? 0.75 : 0.1,
            color: color ?? colors.onSurface,
          ),
        ),
      ),
    );
  }
}
