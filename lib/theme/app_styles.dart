import 'package:flutter/material.dart';

/// Màu nút hành động dùng chung giữa các màn (đồng nhất với màn auth).
/// Xanh = hợp lệ / gửi được; Đỏ = lỗi.
const Color kBrandGreen = Color(0xFF34A12C);
const Color kBrandRed = Color(0xFF8E1B1B);

/// Style chữ cho các đoạn lời nhắn (welcome, invite, ...).
///
/// Màu lấy từ `colorScheme.onSurface` nên tự hợp cả theme Sáng lẫn Tối.
TextStyle messageTextStyle(BuildContext context) => TextStyle(
      fontSize: 15,
      height: 1.55,
      color: Theme.of(context).colorScheme.onSurface,
    );
