import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../theme/app_styles.dart';
import '../widgets/mobile_page.dart';

/// Màn "hướng dẫn di chuyển" — mở từ nút "xem hướng dẫn" ở màn lịch hẹn.
///
/// Bố cục (không cuộn): ảnh sơ đồ trường lấp đầy phía trên (bấm để xem full màn
/// hình), dưới cùng là 2 nút xanh xếp dọc — "Xem vị trí trên Google Maps" rồi
/// "quay lại".
class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  /// Link Google Maps điểm hẹn.
  static const String _mapUrl = 'https://maps.app.goo.gl/kJgtwQ6Y1KKnLzTY8';

  /// Ảnh sơ đồ trường (điểm hẹn). Đã khai báo asset trong pubspec.yaml.
  static const String _mapAsset = 'assets/images/guideline.png';

  void _openMap() => web.window.open(_mapUrl, '_blank');

  @override
  Widget build(BuildContext context) {
    return MobilePage(
      scrollable: false,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _greenButton('Xem vị trí trên Google Maps', _openMap),
          const SizedBox(height: 10),
          _greenButton('Quay lại', () => context.go('/scheduled')),
        ],
      ),
      // Ảnh lấp đầy phần trên; bấm để xem full màn hình.
      child: GestureDetector(
        onTap: () => _openFullScreen(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                color: Colors.black,
                child: _image(context, BoxFit.contain),
              ),
              // Chỉ báo: nhấn vào ảnh để xem & phóng to.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _zoomHint(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dải chỉ báo ở đáy ảnh — gợi ý người dùng bấm để xem & phóng to.
  Widget _zoomHint() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.zoom_in, color: Colors.white, size: 18),
          SizedBox(width: 6),
          Text(
            'Nhấn vào ảnh để xem & phóng to',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Nút nền xanh thương hiệu, chữ trắng — đồng bộ style với nút auth.
  Widget _greenButton(String label, VoidCallback onPressed) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: kBrandGreen,
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  /// Ảnh sơ đồ; nếu chưa có file PNG thì hiện ô placeholder thay vì lỗi.
  Widget _image(BuildContext context, BoxFit fit) {
    return Image.asset(
      _mapAsset,
      fit: fit,
      errorBuilder: (context, error, stack) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 44, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              'Sơ đồ trường sẽ hiển thị ở đây',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// Mở ảnh full màn hình: nền đen, phóng to/thu nhỏ được, bấm để đóng.
  void _openFullScreen(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Đóng',
      barrierColor: Colors.black,
      pageBuilder: (ctx, _, _) => Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Center(child: _image(ctx, BoxFit.contain)),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
