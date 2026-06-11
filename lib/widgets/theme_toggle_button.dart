import 'package:flutter/material.dart';

import '../controllers/theme_controller.dart';

/// Nút bật/tắt chế độ tối. Icon tự đổi theo giao diện đang hiển thị.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'Chuyển chế độ sáng' : 'Chuyển chế độ tối',
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => themeController.setMode(
        isDark ? ThemeMode.light : ThemeMode.dark,
      ),
    );
  }
}
