import 'package:flutter/material.dart';

import '../models/post.dart';

/// Style chữ cho từng loại khối bài viết — dùng CHUNG cho trình soạn
/// (PostEditorPage) và trang đọc (PostDetailPage) để nội dung lúc soạn
/// nhìn giống hệt lúc hiển thị cho khách.
///
/// Màu lấy từ `colorScheme` nên tự hợp cả theme Sáng lẫn Tối.
TextStyle postBlockTextStyle(BuildContext context, PostBlockType type) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (type) {
    PostBlockType.heading => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.35,
        color: colorScheme.onSurface,
      ),
    PostBlockType.subheading => TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        height: 1.4,
        color: colorScheme.onSurface,
      ),
    PostBlockType.quote => TextStyle(
        fontSize: 16,
        fontStyle: FontStyle.italic,
        height: 1.6,
        color: colorScheme.onSurfaceVariant,
      ),
    // Đoạn văn (và khối ảnh không dùng tới) — chữ đọc thoáng, height ~1.6.
    _ => TextStyle(
        fontSize: 16,
        height: 1.6,
        color: colorScheme.onSurface,
      ),
  };
}

/// Gợi ý (hint) tiếng Việt cho ô nhập của từng loại khối trong trình soạn.
String postBlockHint(PostBlockType type) => switch (type) {
      PostBlockType.heading => 'Nhập đề mục…',
      PostBlockType.subheading => 'Nhập đề mục phụ…',
      PostBlockType.quote => 'Nhập trích dẫn…',
      _ => 'Nhập nội dung…',
    };
