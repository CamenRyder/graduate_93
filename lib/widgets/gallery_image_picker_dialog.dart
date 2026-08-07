import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// Mở hộp thoại chọn nhiều ảnh đang có trong kho ảnh dùng chung.
Future<List<GalleryImage>?> showGalleryImagePickerDialog(BuildContext context) {
  return showDialog<List<GalleryImage>>(
    context: context,
    builder: (_) => const GalleryImagePickerDialog(),
  );
}

class GalleryImagePickerDialog extends StatefulWidget {
  const GalleryImagePickerDialog({super.key, this.storageService});

  /// Cho phép inject khi kiểm thử; UI thực tế dùng [StorageService] mặc định.
  final StorageService? storageService;

  @override
  State<GalleryImagePickerDialog> createState() =>
      _GalleryImagePickerDialogState();
}

class _GalleryImagePickerDialogState extends State<GalleryImagePickerDialog> {
  late final StorageService _storage =
      widget.storageService ?? StorageService();

  List<GalleryImage>? _images;
  String? _error;
  final _selectedPaths = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
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

  void _toggle(GalleryImage image) {
    setState(() {
      if (!_selectedPaths.add(image.fullPath)) {
        _selectedPaths.remove(image.fullPath);
      }
    });
  }

  void _finish() {
    final images = _images ?? const <GalleryImage>[];
    Navigator.pop(
      context,
      images.where((image) => _selectedPaths.contains(image.fullPath)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.68;
    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      titlePadding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      title: Row(
        children: [
          const Expanded(child: Text('Chọn từ kho ảnh hệ thống')),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _images == null ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      content: SizedBox(
        width: 860,
        height: height.clamp(320.0, 620.0),
        child: _body(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _selectedPaths.isEmpty ? null : _finish,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text('Thêm (${_selectedPaths.length})'),
        ),
      ],
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(
              'Không tải được kho ảnh:\n$_error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    final images = _images;
    if (images == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (images.isEmpty) {
      return const Center(child: Text('Kho ảnh chưa có hình nào.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        final selected = _selectedPaths.contains(image.fullPath);
        return Material(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _toggle(image),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  image.url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (_, _, _) =>
                      const Center(child: Icon(Icons.broken_image_outlined)),
                ),
                if (selected)
                  ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.28),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black54,
                    child: Icon(
                      selected ? Icons.check : Icons.add,
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
