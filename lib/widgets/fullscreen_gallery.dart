import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/storage_service.dart';
import '../theme/row_palette.dart';

/// Trình xem ảnh chi tiết toàn màn hình với vuốt ngang (PageView), phóng to
/// (InteractiveViewer), nút qua/lại, phím mũi tên/Escape và nút tải về máy.
///
/// Dùng chung cho kho ảnh admin ([GalleryPage]) và trang xem ảnh của khách
/// ([UserGalleryPage]). [onDownload] = null thì ẩn nút tải về.
class FullScreenGallery extends StatefulWidget {
  const FullScreenGallery({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.colors,
    this.onDownload,
  });

  final List<GalleryImage> images;
  final int initialIndex;

  /// {tên ảnh -> khóa màu} để hiện chấm màu phân loại của ảnh đang xem.
  final Map<String, String> colors;

  /// Tải ảnh về máy; ném lỗi nếu thất bại để viewer hiện thông báo. null = ẩn nút.
  final Future<void> Function(GalleryImage)? onDownload;

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);

  /// Dùng chung cho mọi trang; reset về gốc mỗi khi đổi trang. Khi ảnh đang
  /// phóng to thì khóa vuốt ngang để kéo ảnh không bị nhảy trang.
  final TransformationController _zoom = TransformationController();

  late int _index = widget.initialIndex;
  bool _zoomed = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onZoomChanged);
  }

  @override
  void dispose() {
    _zoom.removeListener(_onZoomChanged);
    _zoom.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onZoomChanged() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.05;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _goTo(int i) {
    if (i < 0 || i >= widget.images.length) return;
    // Thu ảnh về kích thước gốc trước để mở khóa vuốt/qua-lại khi đang phóng to.
    _zoom.value = Matrix4.identity();
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _downloadCurrent() async {
    final onDownload = widget.onDownload;
    if (onDownload == null || _downloading) return;
    setState(() => _downloading = true);
    final image = widget.images[_index];
    final messenger = ScaffoldMessenger.of(context);
    try {
      await onDownload(image);
      messenger
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Đã tải ảnh về máy')));
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('Tải ảnh thất bại: $e'),
          backgroundColor: Colors.red.shade700,
        ));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;
    final option = RowPalette.byKey(_colorOf(_index));

    // ScaffoldMessenger cục bộ để SnackBar hiện đè LÊN viewer (viewer phủ kín
    // màn hình nên SnackBar gốc của app sẽ bị che).
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _goTo(_index - 1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _goTo(_index + 1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
      },
      child: Focus(
        autofocus: true,
        child: ScaffoldMessenger(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // Ảnh: vuốt ngang để qua lại, chụm/lăn để phóng to.
                Positioned.fill(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: _zoomed
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    onPageChanged: (i) {
                      _zoom.value = Matrix4.identity();
                      setState(() => _index = i);
                    },
                    itemCount: total,
                    itemBuilder: (context, i) => InteractiveViewer(
                      transformationController: _zoom,
                      minScale: 1,
                      maxScale: 5,
                      child: Center(
                        child: Image.network(
                          widget.images[i].url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator(
                                          color: Colors.white),
                                    ),
                          errorBuilder: (context, error, stack) => const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: Colors.white54, size: 48),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Mũi tên qua/lại (hữu ích khi dùng chuột trên desktop).
                if (total > 1) ...[
                  _NavArrow(
                    icon: Icons.chevron_left,
                    alignment: Alignment.centerLeft,
                    onTap: _index > 0 ? () => _goTo(_index - 1) : null,
                  ),
                  _NavArrow(
                    icon: Icons.chevron_right,
                    alignment: Alignment.centerRight,
                    onTap: _index < total - 1 ? () => _goTo(_index + 1) : null,
                  ),
                ],

                // Thanh trên: đóng · (chấm màu) vị trí · tải về.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Đóng',
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          if (option != null) ...[
                            ColorDot(option: option, size: 14),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '${_index + 1}/$total',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                          ),
                          const Spacer(),
                          if (widget.onDownload == null)
                            const SizedBox(width: 48)
                          else
                            _downloading
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    ),
                                  )
                                : IconButton(
                                    tooltip: 'Tải ảnh này về máy',
                                    icon: const Icon(Icons.download,
                                        color: Colors.white),
                                    onPressed: _downloadCurrent,
                                  ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _colorOf(int i) => widget.colors[widget.images[i].name] ?? '';
}

/// Nút tròn nửa trong suốt ở rìa trái/phải để qua lại ảnh. [onTap] null = mờ đi.
class _NavArrow extends StatelessWidget {
  const _NavArrow({
    required this.icon,
    required this.alignment,
    required this.onTap,
  });

  final IconData icon;
  final Alignment alignment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Material(
            color: Colors.black38,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              icon: Icon(icon,
                  color: onTap == null ? Colors.white24 : Colors.white,
                  size: 32),
              onPressed: onTap,
            ),
          ),
        ),
      ),
    );
  }
}
