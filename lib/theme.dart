import 'package:flutter/material.dart';

/// Hệ thiết kế của ấn phẩm: nền giấy ấm, chữ là nhân vật chính.
///
/// - Newsreader (serif) cho tiêu đề và nội dung dài.
/// - Be Vietnam Pro (sans, dựng riêng cho tiếng Việt) cho giao diện, quản trị
///   và trình soạn — là font mặc định của toàn app.
/// - JetBrains Mono cho metadata, nhãn nhỏ và code.
///
/// Mọi font đều được đóng gói trong assets (Flutter web không đọc được font
/// hệ thống như Georgia — trước đây tiêu đề bị rơi về Roboto).
class AppTheme {
  AppTheme._();

  static const String serifFont = 'Newsreader';
  static const String sansFont = 'Be Vietnam Pro';
  static const String monoFont = 'JetBrains Mono';

  /// Màu nhấn "mực xanh" — dùng tiết chế cho link, trạng thái chọn, CTA.
  static const Color accent = Color(0xFF2B4BC8);
  static const Color accentDark = Color(0xFF9DB0FF);

  /// Màu trạng thái (đèn giao thông) — dùng cho chấm trạng thái lưu/đăng.
  static const Color success = Color(0xFF2F8A4C);
  static const Color warning = Color(0xFFB7791F);

  // ── Thang bo góc ─────────────────────────────────────────────────────────
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 14;

  // ── Thang chuyển động (Tier A — tối giản) ────────────────────────────────
  static const Duration motionFast = Duration(milliseconds: 140);
  static const Duration motionBase = Duration(milliseconds: 200);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF141413)
        : const Color(0xFFF8F6F1);
    final surfaceRaised = isDark
        ? const Color(0xFF1C1C1A)
        : const Color(0xFFFFFFFF);
    final surfaceHigh = isDark
        ? const Color(0xFF242422)
        : const Color(0xFFF1EEE7);
    final surfaceHighest = isDark
        ? const Color(0xFF2E2D2A)
        : const Color(0xFFE8E4DB);
    final ink = isDark ? const Color(0xFFECE9E2) : const Color(0xFF1C1B19);
    final muted = isDark ? const Color(0xFFA6A299) : const Color(0xFF67635B);
    // Viền đủ đậm để vẫn thấy rõ ở chế độ Sáng.
    final line = isDark ? const Color(0xFF383733) : const Color(0xFFDAD5CA);
    final lineSoft = isDark ? const Color(0xFF2B2A27) : const Color(0xFFE7E3DA);
    final activeAccent = isDark ? accentDark : accent;
    final error = isDark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: activeAccent,
          brightness: brightness,
        ).copyWith(
          primary: activeAccent,
          onPrimary: isDark ? const Color(0xFF0F1530) : Colors.white,
          primaryContainer: activeAccent.withValues(alpha: isDark ? 0.18 : 0.1),
          onPrimaryContainer: activeAccent,
          secondary: muted,
          tertiary: warning,
          error: error,
          surface: background,
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: line,
          outlineVariant: lineSoft,
          surfaceContainerLowest: background,
          surfaceContainerLow: surfaceRaised,
          surfaceContainer: surfaceRaised,
          surfaceContainerHigh: surfaceHigh,
          surfaceContainerHighest: surfaceHighest,
          inverseSurface: ink,
          onInverseSurface: background,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: sansFont,
    );
    final textTheme = base.textTheme
        .apply(bodyColor: ink, displayColor: ink, fontFamily: sansFont)
        .copyWith(
          headlineLarge: serif(size: 34, weight: FontWeight.w600, color: ink),
          headlineMedium: serif(size: 28, weight: FontWeight.w600, color: ink),
          headlineSmall: serif(size: 23, weight: FontWeight.w600, color: ink),
          titleLarge: TextStyle(
            fontFamily: sansFont,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: ink,
          ),
          titleMedium: TextStyle(
            fontFamily: sansFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
          bodyMedium: TextStyle(
            fontFamily: sansFont,
            fontSize: 14,
            height: 1.5,
            color: ink,
          ),
          bodySmall: TextStyle(
            fontFamily: sansFont,
            fontSize: 12.5,
            height: 1.45,
            color: muted,
          ),
          labelLarge: const TextStyle(
            fontFamily: sansFont,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: lineSoft,
      dividerTheme: DividerThemeData(color: lineSoft, thickness: 1, space: 1),
      splashFactory: InkSparkle.splashFactory,
      hoverColor: ink.withValues(alpha: 0.04),
      focusColor: activeAccent.withValues(alpha: 0.12),
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
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.85)),
        labelStyle: TextStyle(color: muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: inputBorder(line),
        enabledBorder: inputBorder(line),
        disabledBorder: inputBorder(lineSoft),
        focusedBorder: inputBorder(activeAccent, 1.5),
        errorBorder: inputBorder(error),
        focusedErrorBorder: inputBorder(error, 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: controlShape,
          textStyle: const TextStyle(
            fontFamily: sansFont,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          foregroundColor: ink,
          side: BorderSide(color: line),
          shape: controlShape,
          textStyle: const TextStyle(
            fontFamily: sansFont,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 40),
          shape: controlShape,
          textStyle: const TextStyle(
            fontFamily: sansFont,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ink,
          shape: controlShape,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: muted,
          selectedForegroundColor: ink,
          selectedBackgroundColor: surfaceHighest,
          side: BorderSide(color: line),
          shape: controlShape,
          textStyle: const TextStyle(
            fontFamily: sansFont,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : line,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceRaised,
        selectedColor: activeAccent.withValues(alpha: 0.12),
        side: BorderSide(color: line),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontFamily: sansFont,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: line),
        ),
        textStyle: TextStyle(fontFamily: sansFont, fontSize: 14, color: ink),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
              side: BorderSide(color: line),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFFECE9E2) : const Color(0xFF1C1B19),
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: TextStyle(
          fontFamily: sansFont,
          fontSize: 12,
          color: isDark ? const Color(0xFF141413) : Colors.white,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFFECE9E2)
            : const Color(0xFF1C1B19),
        contentTextStyle: TextStyle(
          fontFamily: sansFont,
          fontSize: 14,
          color: isDark ? const Color(0xFF141413) : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        width: 440,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 2,
        highlightElevation: 0,
        shape: controlShape,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: activeAccent,
        linearTrackColor: lineSoft,
      ),
      appBarTheme: AppBarThemeData(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: sansFont,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        shape: Border(bottom: BorderSide(color: lineSoft)),
      ),
    );
  }

  /// Style serif chuẩn (Newsreader). Với cỡ chữ lớn, bật trục quang học
  /// `opsz` để nét chữ thanh mảnh hơn như chữ in báo.
  static TextStyle serif({
    required double size,
    FontWeight weight = FontWeight.w400,
    FontStyle? style,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: serifFont,
      fontSize: size,
      fontWeight: weight,
      fontStyle: style,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontVariations: [FontVariation('opsz', size.clamp(6, 72).toDouble())],
    );
  }

  /// Nhãn mono nhỏ in hoa (metadata, eyebrow).
  static TextStyle mono({
    double size = 11.5,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0.4,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: monoFont,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
      height: height,
    );
  }
}
