import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/guest_controller.dart';
import '../services/gallery_meta_service.dart';
import '../services/storage_service.dart';
import '../services/web_download.dart';
import '../theme/row_palette.dart';
import '../widgets/fullscreen_gallery.dart';
import '../widgets/theme_toggle_button.dart';

/// Trang xem ảnh dành cho khách: CHỈ hiển thị những ảnh có màu trùng với màu
/// (`rowColor`) của khách đang đăng nhập.
///
/// - Khách có màu (vd "blue") -> xem được các ảnh admin đã gán đúng màu đó.
/// - Khách KHÔNG có màu (rowColor rỗng / không hợp lệ) -> không xem được ảnh nào.
///
/// Khác với kho ảnh admin ([GalleryPage]): chỉ xem & tải về, không upload / xóa
/// / gán màu / lọc.
class UserGalleryPage extends StatefulWidget {
  const UserGalleryPage({super.key});

  @override
  State<UserGalleryPage> createState() => _UserGalleryPageState();
}

class _UserGalleryPageState extends State<UserGalleryPage> {
  final _storage = StorageService();
  final _meta = GalleryMetaService();

  /// Màu của khách; chỉ ảnh trùng màu này mới được hiển thị.
  final String _myColor = guestController.rowColor;

  /// null = đang tải lần đầu; [] = đã tải nhưng rỗng.
  List<GalleryImage>? _images;
  String? _error;

  /// {tên ảnh -> khóa màu} đồng bộ realtime từ Firestore.
  Map<String, String> _colors = {};
  StreamSubscription<Map<String, String>>? _colorSub;

  /// Khách có màu hợp lệ (nằm trong bảng màu) hay không.
  bool get _hasColor => RowPalette.byKey(_myColor) != null;

  @override
  void initState() {
    super.initState();
    if (_hasColor) {
      _load();
      _colorSub = _meta.watchColors().listen((colors) {
        if (mounted) setState(() => _colors = colors);
      });
    }
  }

  @override
  void dispose() {
    _colorSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _images = null;
      _error = null;
    });
    try {
      final images = await _storage.listImages();
      if (!mounted) return;
      setState(() => _images = images);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// Danh sách ảnh thuộc đúng màu của khách.
  List<GalleryImage> get _visible {
    final imgs = _images ?? const <GalleryImage>[];
    return imgs.where((i) => (_colors[i.name] ?? '') == _myColor).toList();
  }

  /// Tải bytes 1 ảnh rồi lưu về máy. Ném lỗi để viewer tự báo.
  Future<void> _saveImageToDevice(GalleryImage image) async {
    final bytes = await _storage.downloadBytes(image.fullPath);
    downloadBytesToDevice(
      bytes,
      image.name.replaceFirst(RegExp(r'^\d+_'), ''),
      mimeType: _mimeForName(image.name),
    );
  }

  String _mimeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  void _openFullScreen(GalleryImage image) {
    final list = _visible;
    final start = list.indexWhere((i) => i.fullPath == image.fullPath);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Đóng',
      barrierColor: Colors.black,
      pageBuilder: (ctx, _, _) => FullScreenGallery(
        images: list,
        initialIndex: start < 0 ? 0 : start,
        // Khách không thấy màu phân loại -> map rỗng để ẩn chấm màu trong viewer.
        colors: const {},
        onDownload: _saveImageToDevice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hình ảnh'),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_hasColor)
            IconButton(
              tooltip: 'Tải lại',
              icon: const Icon(Icons.refresh),
              onPressed: _images == null ? null : _load,
            ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Khách không có màu -> không được xem ảnh nào.
    if (!_hasColor) return const _EmptyState();

    if (_error != null) {
      return _ErrorView(error: _error!, onRetry: _load);
    }
    if (_images == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final visible = _visible;
    if (visible.isEmpty) return const _EmptyState();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: visible.length,
      itemBuilder: (context, i) => _tile(visible[i]),
    );
  }

  Widget _tile(GalleryImage image) {
    return GestureDetector(
      onTap: () => _openFullScreen(image),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.black12,
          child: Image.network(
            image.url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (context, error, stack) => const Center(
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    );
  }
}

/// Trạng thái "chưa có ảnh để xem" (khách không màu hoặc chưa có ảnh đúng màu).
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              'Hiện chưa có hình ảnh nào dành cho bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 12),
            Text('Không tải được hình ảnh:\n$error',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
