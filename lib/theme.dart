import 'package:flutter/material.dart';

/// Hệ màu trung tính cho ấn phẩm cá nhân.
///
/// Giao diện công khai dùng Georgia cho tiêu đề/nội dung dài và dành
/// JetBrains Mono cho metadata, điều hướng nhỏ và code. Các màn quản trị vẫn
/// dùng font hệ thống để giữ mật độ thao tác thoải mái.
class AppTheme {
  AppTheme._();

  static const Color accent = Color(0xFF3157D5);
  static const String serifFont = 'Georgia';
  static const String monoFont = 'JetBrains Mono';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF111214)
        : const Color(0xFFFAFAF8);
    final surfaceRaised = isDark
        ? const Color(0xFF191B1F)
        : const Color(0xFFFFFFFF);
    final ink = isDark ? const Color(0xFFE9E9E5) : const Color(0xFF18191B);
    final muted = isDark ? const Color(0xFFA7A8A4) : const Color(0xFF62635F);
    final line = isDark ? const Color(0xFF32343A) : const Color(0xFFD8D8D2);
    final activeAccent = isDark ? const Color(0xFF9AB0FF) : accent;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: activeAccent,
          brightness: brightness,
        ).copyWith(
          primary: activeAccent,
          onPrimary: isDark ? const Color(0xFF101326) : Colors.white,
          surface: background,
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: line,
          outlineVariant: line,
          surfaceContainerLowest: background,
          surfaceContainerLow: surfaceRaised,
          surfaceContainer: surfaceRaised,
          surfaceContainerHigh: isDark
              ? const Color(0xFF202227)
              : const Color(0xFFF1F1ED),
          surfaceContainerHighest: isDark
              ? const Color(0xFF292B31)
              : const Color(0xFFE9E9E4),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      dividerColor: line,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: activeAccent,
        selectionColor: activeAccent.withValues(alpha: 0.22),
        selectionHandleColor: activeAccent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: surfaceRaised,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: activeAccent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: activeAccent.withValues(alpha: 0.12),
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        labelStyle: TextStyle(color: ink),
      ),
      appBarTheme: AppBarThemeData(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
