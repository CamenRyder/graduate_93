import 'package:flutter/material.dart';

import '../models/post.dart';
import '../theme.dart';
import 'row_palette.dart';

/// Style chữ cho từng loại khối bài viết — dùng CHUNG cho trình soạn
/// (PostEditorPage) và trang đọc (PostDetailPage) để nội dung lúc soạn
/// nhìn giống hệt lúc hiển thị cho khách.
///
/// Màu lấy từ `colorScheme` nên tự hợp cả theme Sáng lẫn Tối.
TextStyle postBlockTextStyle(BuildContext context, PostBlockType type) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (type) {
    PostBlockType.heading => AppTheme.serif(
      size: 31,
      weight: FontWeight.w600,
      height: 1.22,
      letterSpacing: -0.5,
      color: colorScheme.onSurface,
    ),
    PostBlockType.subheading => AppTheme.serif(
      size: 24,
      weight: FontWeight.w600,
      height: 1.32,
      letterSpacing: -0.25,
      color: colorScheme.onSurface,
    ),
    PostBlockType.quote => AppTheme.serif(
      size: 21,
      style: FontStyle.italic,
      height: 1.6,
      color: colorScheme.onSurface.withValues(alpha: 0.82),
    ),
    PostBlockType.code => const TextStyle(
      fontFamily: AppTheme.monoFont,
      fontSize: 14,
      height: 1.7,
      color: PostCodeColors.text,
    ),
    // Đoạn văn (và khối ảnh không dùng tới) — cỡ chữ đọc chuẩn 19px.
    _ => AppTheme.serif(
      size: 19,
      height: 1.72,
      color: colorScheme.onSurface,
    ),
  };
}

/// Gợi ý (hint) tiếng Việt cho ô nhập của từng loại khối trong trình soạn.
String postBlockHint(PostBlockType type) => switch (type) {
  PostBlockType.heading => 'Đề mục',
  PostBlockType.subheading => 'Đề mục phụ',
  PostBlockType.quote => 'Một câu trích dẫn đáng nhớ…',
  PostBlockType.code => '// Dán hoặc nhập mã nguồn…',
  _ => 'Viết gì đó…',
};

/// Icon đại diện cho từng loại khối (menu đổi loại, thanh thêm khối).
IconData postBlockIcon(PostBlockType type) => switch (type) {
  PostBlockType.heading => Icons.title_rounded,
  PostBlockType.subheading => Icons.text_fields_rounded,
  PostBlockType.paragraph => Icons.notes_rounded,
  PostBlockType.quote => Icons.format_quote_rounded,
  PostBlockType.code => Icons.code_rounded,
  PostBlockType.image => Icons.image_outlined,
};

/// Khoảng cách dọc quanh từng loại khối — trình soạn và trang đọc dùng chung
/// để nhịp đọc khớp nhau.
EdgeInsets postBlockSpacing(PostBlockType type) => switch (type) {
  PostBlockType.heading => const EdgeInsets.only(top: 44, bottom: 8),
  PostBlockType.subheading => const EdgeInsets.only(top: 30, bottom: 6),
  PostBlockType.quote => const EdgeInsets.symmetric(vertical: 22),
  PostBlockType.code => const EdgeInsets.symmetric(vertical: 22),
  PostBlockType.image => const EdgeInsets.symmetric(vertical: 26),
  _ => const EdgeInsets.symmetric(vertical: 8),
};

/// Bảng màu khối code — luôn tối ở cả 2 theme để code dễ đọc.
class PostCodeColors {
  PostCodeColors._();

  static const Color background = Color(0xFF17181C);
  static const Color border = Color(0xFF2E3037);
  static const Color text = Color(0xFFE6E6EA);
  static const Color gutter = Color(0xFF7A7D88);
}

/// Khung trang trí cho khối trích dẫn: vạch dọc màu nhấn bên trái.
BoxDecoration postQuoteDecoration(BuildContext context) => BoxDecoration(
  border: Border(
    left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
  ),
);

/// Khung tô sáng (highlight) của khối văn bản theo khóa màu RowPalette.
/// Trả về null khi khối không tô màu. Dùng chung cho trình soạn và trang đọc
/// nên màu tác giả chọn là màu khách nhìn thấy.
BoxDecoration? postHighlightDecoration(BuildContext context, String key) {
  final option = RowPalette.byKey(key);
  if (option == null) return null;
  final brightness = Theme.of(context).brightness;
  return BoxDecoration(
    color: option.background(brightness),
    border: Border(left: BorderSide(color: option.swatch, width: 3)),
  );
}

/// Padding bên trong khối được tô sáng.
const EdgeInsets postHighlightPadding = EdgeInsets.fromLTRB(20, 14, 18, 15);
