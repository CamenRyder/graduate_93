import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/image_compressor.dart';
import '../services/storage_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/theme_toggle_button.dart';

/// Kho ảnh (gallery) cho admin: upload ảnh lên Supabase Storage rồi xem lại.
///
/// - Lưới ảnh (mới nhất lên đầu), bấm 1 ảnh để xem full màn hình + zoom.
/// - Nút nổi "Tải ảnh lên" để chọn 1 hoặc nhiều ảnh từ máy.
/// - Bấm icon thùng rác trên mỗi ảnh để xóa.
///
/// Danh sách ảnh giữ TRỰC TIẾP trong [_images] (không dùng FutureBuilder) để
/// sau khi upload/xóa có thể cập nhật state ngay, không phụ thuộc vào việc gọi
/// lại `list()` (đôi khi trả kết quả cũ do cache CDN).
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final _service = StorageService();

  /// null = đang tải lần đầu; [] = đã tải nhưng rỗng.
  List<GalleryImage>? _images;
  String? _error;
  bool _uploading = false;

  /// Tiến độ upload nhiều ảnh: đã xong / tổng.
  int _uploadDone = 0;
  int _uploadTotal = 0;

  /// Có nén ảnh trước khi tải lên không (mặc định: có).
  bool _compress = true;

  /// Đường dẫn ảnh đang bị xóa (để hiện spinner trên đúng ô).
  final _deleting = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Tải (hoặc tải lại) toàn bộ danh sách ảnh từ Storage.
  Future<void> _load() async {
    setState(() {
      _images = null;
      _error = null;
    });
    try {
      final images = await _service.listImages();
      if (!mounted) return;
      setState(() => _images = images);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// Chọn ảnh từ máy rồi upload lần lượt lên Storage.
  /// Ảnh upload thành công được chèn ngay vào đầu danh sách.
  Future<void> _pickAndUpload() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true, // bắt buộc trên web để có bytes.
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadDone = 0;
      _uploadTotal = result.files.length;
    });
    final uploaded = <GalleryImage>[];
    var fail = 0;
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        fail++;
        if (mounted) setState(() => _uploadDone++);
        continue;
      }
      try {
        // Nén ảnh trước (nếu bật) để giảm dung lượng & băng thông.
        var data = bytes;
        var name = file.name;
        String? contentType;
        if (_compress) {
          final c = await compressImage(bytes, file.name);
          data = c.bytes;
          name = c.filename;
          contentType = c.contentType;
        }
        final img = await _service.uploadImage(
          bytes: data,
          filename: name,
          contentType: contentType,
        );
        uploaded.add(img);
      } catch (_) {
        fail++;
      }
      if (mounted) setState(() => _uploadDone++);
    }

    if (!mounted) return;
    setState(() {
      _uploading = false;
      // Chèn ảnh mới lên đầu (mới nhất trước).
      _images = [...uploaded.reversed, ...?_images];
    });
    _showToast(
      fail == 0
          ? 'Đã tải lên ${uploaded.length} ảnh'
          : 'Tải lên ${uploaded.length} ảnh, lỗi $fail ảnh',
      isError: fail > 0,
    );
  }

  Future<void> _deleteImage(GalleryImage image) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Xóa ảnh?',
      message: 'Ảnh sẽ bị xóa vĩnh viễn khỏi kho.',
      confirmLabel: 'Xóa',
      icon: Icons.delete_outline,
    );
    if (!confirm || !mounted) return;

    setState(() => _deleting.add(image.fullPath));
    try {
      await _service.deleteImage(image.fullPath);
      if (!mounted) return;
      // Server đã xác nhận xóa -> gỡ khỏi danh sách ngay.
      setState(() {
        _images?.removeWhere((i) => i.fullPath == image.fullPath);
        _deleting.remove(image.fullPath);
      });
      _showToast('Đã xóa ảnh');
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting.remove(image.fullPath));
      _showToast('Xóa ảnh thất bại: $e', isError: true);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho ảnh'),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: (_uploading || _images == null) ? null : _load,
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _pickAndUpload,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.upload),
        label: Text(_uploading ? 'Đang tải...' : 'Tải ảnh lên'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _ErrorView(error: _error!, onRetry: _load);
    }
    final images = _images;
    if (images == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (images.isEmpty) {
      return const Center(
        child: Text('Chưa có ảnh — bấm "Tải ảnh lên" để thêm'),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: images.length,
      itemBuilder: (context, i) => _tile(images[i]),
    );
  }

  Widget _tile(GalleryImage image) {
    final deleting = _deleting.contains(image.fullPath);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: deleting ? null : () => _openFullScreen(image),
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
          // Lớp phủ + spinner khi đang xóa ô này.
          if (deleting)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Xóa ảnh',
                icon: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: deleting ? null : () => _deleteImage(image),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mở ảnh full màn hình: nền đen, phóng to/thu nhỏ được, bấm để đóng.
  void _openFullScreen(GalleryImage image) {
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
                child: Center(
                  child: Image.network(image.url, fit: BoxFit.contain),
                ),
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
            Text('Không tải được kho ảnh:\n$error',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
