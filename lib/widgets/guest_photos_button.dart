import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/guest_controller.dart';
import '../theme/row_palette.dart';

/// Nút mở trang xem ảnh của khách (`/photos`), đặt cạnh nút đổi theme.
///
/// Chỉ hiện khi khách đã xác thực VÀ được admin phân loại bằng một màu hợp lệ —
/// khách không có màu thì không xem được ảnh nào nên cũng không hiện nút.
class GuestPhotosButton extends StatelessWidget {
  const GuestPhotosButton({super.key});

  @override
  Widget build(BuildContext context) {
    final canView = guestController.isAuthenticated &&
        RowPalette.byKey(guestController.rowColor) != null;
    if (!canView) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Xem hình ảnh',
      icon: const Icon(Icons.photo_library_outlined),
      onPressed: () => context.push('/photos'),
    );
  }
}
