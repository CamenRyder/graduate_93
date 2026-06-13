import 'package:flutter/material.dart';

/// Một lựa chọn màu "holder" (nền) cho 1 hàng dữ liệu trong bảng admin.
///
/// QUAN TRỌNG — Firebase chỉ lưu [key] (chuỗi ngữ nghĩa, vd "blue"),
/// KHÔNG lưu mã màu RGB thô. Nhờ vậy mỗi hàng tự render ra tông phù hợp với
/// chế độ Sáng / Tối đang bật, thay vì bị "kẹt" một mã màu cố định chỉ hợp
/// một trong hai chế độ (sáng quá ở dark mode hoặc tối quá ở light mode).
class RowColorOption {
  const RowColorOption({
    required this.key,
    required this.label,
    required this.swatch,
    required this.lightBackground,
    required this.darkBackground,
  });

  /// Khóa lưu xuống Firebase (field `rowColor`). Rỗng = không tô màu.
  final String key;

  /// Tên hiển thị trong menu chọn màu.
  final String label;

  /// Màu đại diện (đậm, dễ nhận biết) hiển thị trên ô tròn của nút chọn.
  final Color swatch;

  /// Nền hàng ở chế độ SÁNG — tông pastel nhạt để chữ tối vẫn đọc rõ.
  final Color lightBackground;

  /// Nền hàng ở chế độ TỐI — tông trầm tối để chữ sáng vẫn đọc rõ.
  final Color darkBackground;

  /// Màu nền theo độ sáng (brightness) của theme hiện hành.
  Color background(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : lightBackground;
}

/// Bảng màu "holder" dùng chung cho bảng users.
class RowPalette {
  RowPalette._();

  /// Khóa cho "không tô màu".
  static const String none = '';

  /// 5 màu theo yêu cầu, mỗi màu có sẵn tông cho cả Sáng lẫn Tối.
  static const List<RowColorOption> options = [
    RowColorOption(
      key: 'blue', // xanh dương
      label: 'Xanh dương',
      swatch: Color(0xFF2F6FED),
      lightBackground: Color(0xFFDCE9FD),
      darkBackground: Color(0xFF173251),
    ),
    RowColorOption(
      key: 'green', // xanh lá
      label: 'Xanh lá',
      swatch: Color(0xFF2E9E4F),
      lightBackground: Color(0xFFD8F0DC),
      darkBackground: Color(0xFF173B24),
    ),
    RowColorOption(
      key: 'maroon', // đỏ đô
      label: 'Đỏ đô',
      swatch: Color(0xFF9B2C3A),
      lightBackground: Color(0xFFF4D9DC),
      darkBackground: Color(0xFF45181E),
    ),
    RowColorOption(
      key: 'orange', // cam nhạt
      label: 'Cam nhạt',
      swatch: Color(0xFFF5933B),
      lightBackground: Color(0xFFFDE6CC),
      darkBackground: Color(0xFF4A3315),
    ),
    RowColorOption(
      key: 'coffee', // nâu cà phê
      label: 'Nâu cà phê',
      swatch: Color(0xFF7A5A43),
      lightBackground: Color(0xFFE8DCD0),
      darkBackground: Color(0xFF3A2A1E),
    ),
    RowColorOption(
      key: 'pink', // hồng nhạt
      label: 'Hồng nhạt',
      swatch: Color(0xFFEC5E92),
      lightBackground: Color(0xFFFBDCE8),
      darkBackground: Color(0xFF4A2036),
    ),
  ];

  /// Tra cứu option theo [key]; trả về null nếu rỗng hoặc không hợp lệ
  /// (vd dữ liệu cũ chưa có màu, hoặc key lạ từ Firebase).
  static RowColorOption? byKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final option in options) {
      if (option.key == key) return option;
    }
    return null;
  }

  /// Màu nền của hàng cho [key] theo [brightness]; null nếu không tô màu.
  static Color? backgroundFor(String? key, Brightness brightness) =>
      byKey(key)?.background(brightness);
}

/// Ô tròn hiển thị màu đại diện — dùng chung cho menu chọn màu (mỗi hàng)
/// và cho dropdown lọc theo màu. [option] = null nghĩa là "không màu"
/// (hiển thị icon gạch chéo trên nền trong suốt).
class ColorDot extends StatelessWidget {
  const ColorDot({super.key, required this.option, this.size = 18});

  final RowColorOption? option;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: option?.swatch ?? Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.outline),
      ),
      child: option == null
          ? Icon(
              Icons.block,
              size: size - 5,
              color: colorScheme.onSurfaceVariant,
            )
          : null,
    );
  }
}
