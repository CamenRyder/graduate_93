import 'dart:async';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/gallery_meta_service.dart';
import '../services/image_compressor.dart';
import '../services/storage_service.dart';
import '../services/web_download.dart';
import '../theme/row_palette.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/fullscreen_gallery.dart';
import '../widgets/theme_toggle_button.dart';

/// Kho ảnh (gallery) cho admin: upload ảnh lên Supabase Storage rồi xem lại,
/// phân loại theo màu (lưu trên Firestore), lọc theo màu và xóa hàng loạt.
///
/// - File ảnh: Supabase Storage (bucket `graduation`).
/// - Màu của mỗi ảnh: Firestore collection `gallery` (giống `rowColor` ở bảng
///   users — tái dùng [RowPalette]).
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final _storage = StorageService();
  final _meta = GalleryMetaService();

  /// null = đang tải lần đầu; [] = đã tải nhưng rỗng.
  List<GalleryImage>? _images;
  String? _error;

  /// {tên ảnh -> khóa màu} đồng bộ realtime từ Firestore.
  Map<String, String> _colors = {};
  StreamSubscription<Map<String, String>>? _colorSub;

  bool _uploading = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;
  bool _compress = true;

  /// Đường dẫn ảnh đang bị xóa (để hiện spinner trên đúng ô).
  final _deleting = <String>{};

  /// Bộ lọc màu: null = tất cả; '' = không màu; ngược lại = khóa màu.
  String? _filterColor;

  /// Chế độ chọn nhiều + tập ảnh đang chọn (theo tên ảnh).
  bool _selectionMode = false;
  final _selected = <String>{};

  /// Đang đóng gói + tải ZIP (tải nhiều ảnh theo màu / theo lựa chọn).
  bool _zipping = false;

  @override
  void initState() {
    super.initState();
    _load();
    _colorSub = _meta.watchColors().listen((colors) {
      if (mounted) setState(() => _colors = colors);
    });
  }

  @override
  void dispose() {
    _colorSub?.cancel();
    super.dispose();
  }

  /// Tải (hoặc tải lại) toàn bộ danh sách ảnh từ Storage.
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

  /// Danh sách ảnh sau khi áp bộ lọc màu.
  List<GalleryImage> get _visible {
    final imgs = _images ?? const <GalleryImage>[];
    if (_filterColor == null) return imgs;
    return imgs
        .where((i) => (_colors[i.name] ?? '') == _filterColor)
        .toList();
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  /// Mở bảng chọn màu trước, sau đó mới chọn file & upload theo màu đó.
  Future<void> _chooseColorThenUpload() async {
    final colorKey = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Chọn màu gán cho các ảnh sắp tải lên',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const ColorDot(option: null),
              title: const Text('Không màu'),
              onTap: () => Navigator.pop(ctx, RowPalette.none),
            ),
            ...RowPalette.options.map(
              (o) => ListTile(
                leading: ColorDot(option: o),
                title: Text(o.label),
                onTap: () => Navigator.pop(ctx, o.key),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (colorKey == null) return; // người dùng đóng bảng -> hủy.
    await _pickAndUpload(colorKey);
  }

  /// Chọn ảnh từ máy rồi upload lần lượt lên Storage; gán [uploadColor] cho
  /// mọi ảnh tải lên ('' = không màu).
  Future<void> _pickAndUpload(String uploadColor) async {
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
    var totalOriginal = 0;
    var totalCompressed = 0;
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        fail++;
        if (mounted) setState(() => _uploadDone++);
        continue;
      }
      try {
        var data = bytes;
        var name = file.name;
        String? contentType;
        if (_compress) {
          final c = await compressImage(bytes, file.name);
          data = c.bytes;
          name = c.filename;
          contentType = c.contentType;
          totalOriginal += c.originalSize;
          totalCompressed += c.compressedSize;
        }
        final img = await _storage.uploadImage(
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
      _images = [...uploaded.reversed, ...?_images];
    });
    // Gán màu đã chọn cho tất cả ảnh vừa tải lên.
    if (uploadColor.isNotEmpty && uploaded.isNotEmpty) {
      await _assignColor(uploaded.map((e) => e.name), uploadColor);
    }
    final base = fail == 0
        ? 'Đã tải lên ${uploaded.length} ảnh'
        : 'Tải lên ${uploaded.length} ảnh, lỗi $fail ảnh';
    final note = (_compress && totalOriginal > 0)
        ? ' · nén ${_fmtSize(totalOriginal)} → ${_fmtSize(totalCompressed)}'
        : '';
    _showToast('$base$note', isError: fail > 0);
  }

  // ── Xóa ─────────────────────────────────────────────────────────────────

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
      await _storage.deleteImage(image.fullPath);
      await _meta.deleteMetas([image.name]);
      if (!mounted) return;
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

  Future<void> _bulkDelete() async {
    final names = _selected.toList();
    if (names.isEmpty) return;
    final confirm = await showConfirmDialog(
      context,
      title: 'Xóa ${names.length} ảnh?',
      message: 'Các ảnh đã chọn sẽ bị xóa vĩnh viễn khỏi kho.',
      confirmLabel: 'Xóa',
      icon: Icons.delete_outline,
    );
    if (!confirm || !mounted) return;

    setState(() => _deleting.addAll(names));
    try {
      await _storage.deleteImages(names);
      await _meta.deleteMetas(names);
      if (!mounted) return;
      setState(() {
        _images?.removeWhere((i) => names.contains(i.name));
        _deleting.removeAll(names);
        _exitSelection();
      });
      _showToast('Đã xóa ${names.length} ảnh');
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting.removeAll(names));
      _showToast('Xóa ảnh thất bại: $e', isError: true);
    }
  }

  // ── Gán màu ───────────────────────────────────────────────────────────────

  Future<void> _assignColor(Iterable<String> names, String colorKey) async {
    final list = names.toList();
    if (list.isEmpty) return;
    // Cập nhật lạc quan cho mượt; Firestore stream sẽ đồng bộ lại sau.
    setState(() {
      for (final n in list) {
        if (colorKey.isEmpty) {
          _colors.remove(n);
        } else {
          _colors[n] = colorKey;
        }
      }
    });
    try {
      await _meta.setColors(list, colorKey);
    } catch (e) {
      if (mounted) _showToast('Gán màu thất bại: $e', isError: true);
    }
  }

  // ── Tải ảnh về máy ────────────────────────────────────────────────────────

  /// Tải bytes 1 ảnh rồi lưu về máy. Ném lỗi để nơi gọi (viewer) tự báo.
  Future<void> _saveImageToDevice(GalleryImage image) async {
    final bytes = await _storage.downloadBytes(image.fullPath);
    downloadBytesToDevice(
      bytes,
      _friendlyName(image.name),
      mimeType: _mimeForName(image.name),
    );
  }

  /// Mở bảng chọn màu rồi tải toàn bộ ảnh thuộc màu đó về máy dưới dạng 1 ZIP.
  Future<void> _chooseColorThenDownloadAll() async {
    const allSentinel = '__all__';
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Tải ảnh về máy theo màu (gói ZIP)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: const Text('Tất cả ảnh'),
              onTap: () => Navigator.pop(ctx, allSentinel),
            ),
            ListTile(
              leading: const ColorDot(option: null),
              title: const Text('Không màu'),
              onTap: () => Navigator.pop(ctx, RowPalette.none),
            ),
            ...RowPalette.options.map(
              (o) => ListTile(
                leading: ColorDot(option: o),
                title: Text(o.label),
                onTap: () => Navigator.pop(ctx, o.key),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return; // người dùng đóng bảng -> hủy.

    final all = _images ?? const <GalleryImage>[];
    final List<GalleryImage> group;
    final String fileLabel;
    if (choice == allSentinel) {
      group = all.toList();
      fileLabel = 'tat-ca';
    } else if (choice == RowPalette.none) {
      group = all.where((i) => (_colors[i.name] ?? '').isEmpty).toList();
      fileLabel = 'khong-mau';
    } else {
      group = all.where((i) => (_colors[i.name] ?? '') == choice).toList();
      fileLabel = choice; // khóa màu là ASCII (blue/green/...) -> hợp tên file.
    }
    await _downloadGroupAsZip(group, fileLabel);
  }

  /// Tải các ảnh đang chọn về máy dưới dạng 1 ZIP.
  Future<void> _downloadSelected() async {
    final names = _selected.toSet();
    final group =
        (_images ?? const <GalleryImage>[]).where((i) => names.contains(i.name)).toList();
    await _downloadGroupAsZip(group, 'da-chon');
  }

  /// Tải lần lượt bytes từng ảnh, đóng gói thành ZIP rồi lưu về máy. Hiển thị
  /// hộp thoại tiến trình (có nút Hủy) trong lúc tải.
  Future<void> _downloadGroupAsZip(
      List<GalleryImage> images, String fileLabel) async {
    if (images.isEmpty) {
      _showToast('Không có ảnh nào để tải');
      return;
    }

    final done = ValueNotifier<int>(0);
    var cancelled = false;
    BuildContext? dialogCtx;
    setState(() => _zipping = true);

    // Hộp thoại tiến trình (không tự đóng được, có nút Hủy).
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogCtx = ctx;
        return AlertDialog(
          title: const Text('Đang chuẩn bị file ZIP'),
          content: ValueListenableBuilder<int>(
            valueListenable: done,
            builder: (_, v, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: v / images.length),
                const SizedBox(height: 12),
                Text('$v / ${images.length} ảnh'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelled = true;
                Navigator.pop(ctx);
              },
              child: const Text('Hủy'),
            ),
          ],
        );
      },
    ));

    try {
      final archive = Archive();
      final used = <String>{};
      for (final image in images) {
        if (cancelled) break;
        final bytes = await _storage.downloadBytes(image.fullPath);
        final entryName = _uniqueName(_friendlyName(image.name), used);
        // noCompress: ảnh đã nén sẵn (JPEG/PNG...) nên "store" cho nhanh.
        archive.addFile(ArchiveFile.noCompress(entryName, bytes.length, bytes));
        done.value++;
      }
      if (cancelled) {
        _showToast('Đã hủy tải ZIP');
        return;
      }
      final zipBytes = ZipEncoder().encodeBytes(archive);
      downloadBytesToDevice(
        zipBytes,
        'kho-anh-$fileLabel.zip',
        mimeType: 'application/zip',
      );
      _showToast('Đã tải ${images.length} ảnh (ZIP)');
    } catch (e) {
      _showToast('Tải ZIP thất bại: $e', isError: true);
    } finally {
      if (mounted) setState(() => _zipping = false);
      if (dialogCtx != null && dialogCtx!.mounted) {
        Navigator.pop(dialogCtx!); // đóng hộp thoại tiến trình nếu còn mở.
      }
    }
  }

  /// Bỏ tiền tố timestamp `<digits>_` do lúc upload thêm vào -> tên gốc dễ đọc.
  String _friendlyName(String storageName) =>
      storageName.replaceFirst(RegExp(r'^\d+_'), '');

  /// Bảo đảm tên file không trùng trong ZIP: thêm hậu tố " (2)", " (3)"...
  String _uniqueName(String name, Set<String> used) {
    if (used.add(name)) return name;
    final dot = name.lastIndexOf('.');
    final base = dot == -1 ? name : name.substring(0, dot);
    final ext = dot == -1 ? '' : name.substring(dot);
    var i = 2;
    String candidate;
    do {
      candidate = '$base ($i)$ext';
      i++;
    } while (!used.add(candidate));
    return candidate;
  }

  /// Đoán Content-Type theo đuôi file để trình duyệt lưu/mở đúng định dạng.
  String _mimeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  // ── Chọn nhiều ──────────────────────────────────────────────────────────

  void _enterSelection(String name) {
    setState(() {
      _selectionMode = true;
      _selected.add(name);
    });
  }

  void _exitSelection() {
    _selectionMode = false;
    _selected.clear();
  }

  void _toggleSelect(String name) {
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
        if (_selected.isEmpty) _selectionMode = false;
      } else {
        _selected.add(name);
      }
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _fmtSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)}KB';
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

  /// Menu chọn màu (dùng cho từng ảnh và cho hàng loạt).
  List<PopupMenuEntry<String>> _colorMenuItems() {
    return [
      PopupMenuItem(
        value: RowPalette.none,
        child: Row(
          children: const [
            ColorDot(option: null),
            SizedBox(width: 10),
            Text('Không màu'),
          ],
        ),
      ),
      ...RowPalette.options.map(
        (o) => PopupMenuItem(
          value: o.key,
          child: Row(
            children: [
              ColorDot(option: o),
              const SizedBox(width: 10),
              Text(o.label),
            ],
          ),
        ),
      ),
    ];
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectionMode ? _selectionAppBar() : _normalAppBar(),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _uploading ? null : _chooseColorThenUpload,
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
              label: Text(
                _uploading
                    ? 'Đang tải $_uploadDone/$_uploadTotal...'
                    : 'Tải ảnh lên',
              ),
            ),
      body: Column(
        children: [
          if (_images != null && _images!.isNotEmpty) _filterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  AppBar _normalAppBar() {
    return AppBar(
      title: const Text('Kho ảnh'),
      leading: IconButton(
        tooltip: 'Quay lại',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/admin'),
      ),
      actions: [
        IconButton(
          tooltip: 'Tải ảnh về máy (ZIP) theo màu',
          icon: const Icon(Icons.download_outlined),
          onPressed:
              (_images == null || _images!.isEmpty || _uploading || _zipping)
                  ? null
                  : _chooseColorThenDownloadAll,
        ),
        IconButton(
          tooltip: 'Chọn nhiều ảnh',
          icon: const Icon(Icons.checklist),
          onPressed: (_images == null || _images!.isEmpty)
              ? null
              : () => setState(() => _selectionMode = true),
        ),
        IconButton(
          tooltip: _compress
              ? 'Nén ảnh: BẬT (giảm dung lượng)'
              : 'Nén ảnh: TẮT (tải nguyên gốc)',
          icon: Icon(_compress
              ? Icons.compress
              : Icons.photo_size_select_actual_outlined),
          color: _compress ? Theme.of(context).colorScheme.primary : null,
          onPressed:
              _uploading ? null : () => setState(() => _compress = !_compress),
        ),
        IconButton(
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
          onPressed: (_uploading || _images == null) ? null : _load,
        ),
        const ThemeToggleButton(),
        const SizedBox(width: 8),
      ],
    );
  }

  AppBar _selectionAppBar() {
    return AppBar(
      leading: IconButton(
        tooltip: 'Hủy chọn',
        icon: const Icon(Icons.close),
        onPressed: () => setState(_exitSelection),
      ),
      title: Text('Đã chọn ${_selected.length}'),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Gán màu cho ảnh đã chọn',
          icon: const Icon(Icons.palette_outlined),
          enabled: _selected.isNotEmpty,
          onSelected: (key) => _assignColor(_selected.toList(), key),
          itemBuilder: (_) => _colorMenuItems(),
        ),
        IconButton(
          tooltip: 'Tải ảnh đã chọn về máy (ZIP)',
          icon: const Icon(Icons.download_outlined),
          onPressed: (_selected.isEmpty || _zipping) ? null : _downloadSelected,
        ),
        IconButton(
          tooltip: 'Xóa ảnh đã chọn',
          icon: const Icon(Icons.delete_outline),
          onPressed: _selected.isEmpty ? null : _bulkDelete,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Thanh lọc theo màu (Wrap các chip giống bộ lọc màu của dashboard).
  Widget _filterBar() {
    Widget chip(String? value, String label, RowColorOption? option) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: _filterColor == value,
          avatar: value == null ? null : ColorDot(option: option),
          label: Text(label),
          onSelected: (_) => setState(() => _filterColor = value),
        ),
      );
    }

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          chip(null, 'Tất cả', null),
          chip(RowPalette.none, 'Không màu', null),
          ...RowPalette.options.map((o) => chip(o.key, o.label, o)),
        ],
      ),
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
    final visible = _visible;
    if (visible.isEmpty) {
      return const Center(child: Text('Không có ảnh nào khớp màu đang lọc'));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
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
    final deleting = _deleting.contains(image.fullPath);
    final selected = _selected.contains(image.name);
    final colorKey = _colors[image.name] ?? '';
    final option = RowPalette.byKey(colorKey);

    void onTap() {
      if (_selectionMode) {
        _toggleSelect(image.name);
      } else {
        _openFullScreen(image);
      }
    }

    return GestureDetector(
      onTap: deleting ? null : onTap,
      onLongPress: deleting ? null : () => _enterSelection(image.name),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
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

            // Chấm màu phân loại ở góc trên-trái (chỉ khi ảnh có màu).
            if (option != null)
              Positioned(
                top: 6,
                left: 6,
                child: _badge(child: ColorDot(option: option, size: 16)),
              ),

            // Lớp phủ + spinner khi đang xóa.
            if (deleting)
              Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Colors.white),
              ),

            // Chế độ chọn: ô tick; ngược lại: nút gán màu + xóa.
            if (_selectionMode)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                  size: 26,
                ),
              )
            else ...[
              Positioned(
                top: 4,
                right: 4,
                child: _badge(
                  circle: true,
                  child: PopupMenuButton<String>(
                    tooltip: 'Gán màu',
                    icon: const Icon(Icons.palette_outlined,
                        color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    onSelected: (key) => _assignColor([image.name], key),
                    itemBuilder: (_) => _colorMenuItems(),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: _badge(
                  circle: true,
                  child: IconButton(
                    tooltip: 'Xóa ảnh',
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.white, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _deleteImage(image),
                  ),
                ),
              ),
            ],

            // Khung sáng khi được chọn.
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Nền tối bo tròn để icon/chấm màu nổi trên ảnh.
  Widget _badge({required Widget child, bool circle = false}) {
    return Material(
      color: Colors.black54,
      shape: circle
          ? const CircleBorder()
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.all(circle ? 0 : 4),
        child: child,
      ),
    );
  }

  /// Mở ảnh full màn hình ở chế độ "xem chi tiết": vuốt ngang để qua lại các
  /// ảnh khác (theo đúng danh sách đang lọc), chụm/lăn để phóng to, và tải ảnh
  /// đang xem về máy.
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
        colors: Map.of(_colors),
        onDownload: _saveImageToDevice,
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
