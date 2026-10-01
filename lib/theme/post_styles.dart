import 'package:flutter/material.dart';

import '../models/post.dart';
import '../theme.dart';

/// Style chữ cho từng loại khối bài viết — dùng CHUNG cho trình soạn
/// (PostEditorPage) và trang đọc (PostDetailPage) để nội dung lúc soạn
/// nhìn giống hệt lúc hiển thị cho khách.
///
/// Màu lấy từ `colorScheme` nên tự hợp cả theme Sáng lẫn Tối.
TextStyle postBlockTextStyle(BuildContext context, PostBlockType type) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (type) {
    PostBlockType.heading => TextStyle(
      fontFamily: AppTheme.serifFont,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.22,
      letterSpacing: -0.45,
      color: colorScheme.onSurface,
    ),
    PostBlockType.subheading => TextStyle(
      fontFamily: AppTheme.serifFont,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.35,
      letterSpacing: -0.2,
      color: colorScheme.onSurface,
    ),
    PostBlockType.quote => TextStyle(
      fontFamily: AppTheme.serifFont,
      fontSize: 20,
      fontStyle: FontStyle.italic,
      height: 1.7,
      color: colorScheme.onSurfaceVariant,
    ),
    PostBlockType.code => const TextStyle(
      fontFamily: AppTheme.monoFont,
      fontSize: 14.5,
      height: 1.65,
    ),
    // Đoạn văn (và khối ảnh không dùng tới) — cỡ chữ đọc chuẩn 18px.
    _ => TextStyle(
      fontFamily: AppTheme.serifFont,
      fontSize: 18,
      height: 1.75,
      color: colorScheme.onSurface,
    ),
  };
}

/// Gợi ý (hint) tiếng Việt cho ô nhập của từng loại khối trong trình soạn.
String postBlockHint(PostBlockType type) => switch (type) {
  PostBlockType.heading => 'Nhập đề mục…',
  PostBlockType.subheading => 'Nhập đề mục phụ…',
  PostBlockType.quote => 'Nhập trích dẫn…',
  PostBlockType.code => 'Dán hoặc nhập mã nguồn…',
  _ => 'Nhập nội dung…',
};
