import 'dart:async';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/gallery_folder_service.dart';
import '../services/gallery_meta_service.dart';
import '../services/image_compressor.dart';
import '../services/image_precache_service.dart';
import '../services/storage_service.dart';
import '../services/storage_usage_service.dart';
import '../services/web_download.dart';
import '../supabase_config.dart';
import '../theme/row_palette.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/fullscreen_gallery.dart';
import '../widgets/text_input_dialog.dart';
import '../widgets/theme_toggle_button.dart';

/// Kho ảnh (gallery) cho admin: upload ảnh lên Supabase Storage rồi xem lại,
/// sắp xếp theo THƯ MỤC, phân loại theo màu (lưu trên Firestore), lọc theo
/// màu và xóa hàng loạt.
///
/// - File ảnh: Supabase Storage (bucket `graduation`) — lưu phẳng, KHÔNG
///   di chuyển file; "thư mục" chỉ là metadata trên Firestore.
/// - Màu + thư mục của mỗi ảnh: Firestore collection `gallery` (giống
///   `rowColor` ở bảng users — tái dùng [RowPalette]).
/// - Danh sách thư mục: Firestore collection `gallery_folders`.
///
/// Màn hình mở ra ở chế độ TỔNG QUAN THƯ MỤC (các thẻ thư mục + thẻ ảo
/// "Chưa phân loại"); bấm vào 1 thư mục mới thấy lưới ảnh với đầy đủ tính
/// năng cũ (gán màu, lọc, chọn nhiều, tải ZIP, xem toàn màn hình...).
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final _storage = StorageService();
  final _storageUsageService = StorageUsageService();
  final _meta = GalleryMetaService();
  final _folderService = GalleryFolderService();
  final _precache = ImagePrecacheService.instance;

  /// Id "ảo" của thư mục Chưa phân loại (ảnh không có field `folder`).
  static const String _unsorted = '';

  /// Số ảnh tải trước cho MỖI thư mục ngay khi vào màn tổng quan.
  static const int _precachePerFolder = 30;

  /// null = đang tải lần đầu; [] = đã tải nhưng rỗng.
  List<GalleryImage>? _images;
  String? _error;
  StorageUsage? _storageUsage;
  String? _storageUsageError;
  bool _storageUsageLoading = true;

  /// {tên ảnh -> khóa màu} đồng bộ realtime từ Firestore.
  Map<String, String> _colors = {};

  /// {tên ảnh -> id thư mục} đồng bộ realtime từ Firestore.
  Map<String, String> _imageFolders = {};
  StreamSubscription<GalleryMetaSnapshot>? _metaSub;

  /// Danh sách thư mục đồng bộ realtime từ Firestore.
  List<GalleryFolder> _folders = [];
  StreamSubscription<List<GalleryFolder>>? _folderSub;

  /// Thư mục đang mở: null = màn tổng quan thư mục; [_unsorted] = "Chưa phân
  /// loại"; còn lại = id thư mục thật.
  String? _openFolderId;

  /// Cờ "đã nhận dữ liệu lần đầu" của 2 stream — đủ cả mới precache/tổng quan.
  bool _foldersReady = false;
  bool _metasReady = false;

  /// Đã precache 30 ảnh đầu mỗi thư mục cho lần tải này chưa.
  bool _didOverviewPrecache = false;

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
    _metaSub = _meta.watchMetas().listen((snap) {
      if (!mounted) return;
      setState(() {
        _colors = snap.colors;
        _imageFolders = snap.folders;
      });
      _metasReady = true;
      _maybePrecacheOverview();
    });
    _folderSub = _folderService.watchFolders().listen((folders) {
      if (!mounted) return;
      setState(() => _folders = folders);
      _foldersReady = true;
      _maybePrecacheOverview();
    });
  }

  @override
  void dispose() {
    _metaSub?.cancel();
    _folderSub?.cancel();
    // Rời trang thì bỏ các ảnh CHƯA kịp tải trước (ảnh đã cache vẫn giữ).
    _precache.cancelPending();
    super.dispose();
  }

  /// Tải (hoặc tải lại) toàn bộ danh sách ảnh từ Storage.
  Future<void> _load() async {
    unawaited(_loadStorageUsage());
    setState(() {
      _images = null;
      _error = null;
      _didOverviewPrecache = false; // cho phép precache lại sau khi tải lại.
    });
    try {
      final images = await _storage.listImages();
      if (!mounted) return;
      setState(() => _images = images);
      _maybePrecacheOverview();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// Dung lượng là thông tin phụ: lỗi RPC không được làm hỏng toàn bộ kho ảnh.
  Future<void> _loadStorageUsage({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _storageUsageLoading = true;
        _storageUsageError = null;
      });
    }
    try {
      final usage = await _storageUsageService.getUsage(
        quotaBytes: SupabaseConfig.storageQuotaBytes,
      );
      if (!mounted) return;
      setState(() {
        _storageUsage = usage;
        _storageUsageLoading = false;
        _storageUsageError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _storageUsageLoading = false;
        _storageUsageError = '$e';
      });
    }
  }

  // ── Thư mục: helpers ─────────────────────────────────────────────────────

  /// Id thư mục HIỆU LỰC của 1 ảnh: rỗng nếu chưa phân loại hoặc thư mục đã
  /// bị xóa (id không còn trong [_folders] -> ảnh tự quay về "Chưa phân loại").
  String _folderOf(String imageName) {
    final id = _imageFolders[imageName] ?? '';
    if (id.isEmpty) return _unsorted;
    return _folders.any((f) => f.id == id) ? id : _unsorted;
  }

  /// Danh sách ảnh thuộc thư mục [folderId] (giữ nguyên thứ tự mới nhất trước).
  List<GalleryImage> _imagesOf(String folderId) =>
      (_images ?? const <GalleryImage>[])
          .where((i) => _folderOf(i.name) == folderId)
          .toList();

  /// Ảnh trong PHẠM VI đang xem: cả kho nếu ở tổng quan, ngược lại là ảnh
  /// của thư mục đang mở.
  List<GalleryImage> get _scope => _openFolderId == null
      ? (_images ?? const <GalleryImage>[])
      : _imagesOf(_openFolderId!);

  /// Danh sách ảnh sau khi áp bộ lọc màu (trong phạm vi thư mục đang mở).
  List<GalleryImage> get _visible {
    final imgs = _scope;
    if (_filterColor == null) return imgs;
    return imgs.where((i) => (_colors[i.name] ?? '') == _filterColor).toList();
  }

  /// Tên hiển thị của thư mục [folderId] ('' = "Chưa phân loại").
  String _folderTitle(String folderId) {
    if (folderId == _unsorted) return 'Chưa phân loại';
    for (final f in _folders) {
      if (f.id == folderId) return f.name;
    }
    return 'Thư mục';
  }

  /// Mở 1 thư mục từ màn tổng quan + tải trước NỐT các ảnh còn lại của nó.
  void _openFolder(String folderId) {
    setState(() {
      _openFolderId = folderId;
      _filterColor = null;
      _exitSelection();
    });
    // 30 ảnh đầu đã (đang) được cache từ màn tổng quan; schedule cả danh sách
    // để tải nốt phần còn lại — service tự bỏ qua URL trùng. priority = chen
    // lên đầu hàng đợi vì người dùng đang xem chính thư mục này.
    _precache.schedule(
      context,
      _imagesOf(folderId).map((i) => i.url),
      priority: true,
    );
  }

  /// Quay về màn tổng quan thư mục.
  void _closeFolder() {
    setState(() {
      _openFolderId = null;
      _filterColor = null;
      _exitSelection();
    });
  }

  // ── Tải trước ảnh (precache) ─────────────────────────────────────────────

  /// Khi đã đủ dữ liệu (ảnh + thư mục + metadata): tải trước
  /// [_precachePerFolder] ảnh đầu của MỖI thư mục (kể cả "Chưa phân loại")
  /// để bấm vào thư mục nào thumbnail cũng hiện ngay. Chạy 1 lần mỗi lần tải.
  void _maybePrecacheOverview() {
    if (_didOverviewPrecache || !mounted) return;
    if (_images == null || !_foldersReady || !_metasReady) return;
    _didOverviewPrecache = true;
    final urls = <String>[
      for (final id in [_unsorted, ..._folders.map((f) => f.id)])
        ..._imagesOf(id).take(_precachePerFolder).map((i) => i.url),
    ];
    _precache.schedule(context, urls);
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
  /// mọi ảnh tải lên ('' = không màu). Nếu đang mở 1 thư mục thật thì ảnh
  /// tự động thuộc thư mục đó; ở tổng quan / "Chưa phân loại" thì để trống.
  Future<void> _pickAndUpload(String uploadColor) async {
    // Chốt thư mục đích NGAY LÚC BẤM upload (upload lâu, người dùng có thể
    // chuyển màn hình giữa chừng).
    final targetFolder = (_openFolderId != null && _openFolderId != _unsorted)
        ? _openFolderId!
        : _unsorted;

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
    // Đưa ảnh vừa tải vào thư mục đang mở (nếu có).
    if (targetFolder != _unsorted && uploaded.isNotEmpty) {
      await _assignFolder(uploaded.map((e) => e.name), targetFolder);
    }
    final base = fail == 0
        ? 'Đã tải lên ${uploaded.length} ảnh'
        : 'Tải lên ${uploaded.length} ảnh, lỗi $fail ảnh';
    final note = (_compress && totalOriginal > 0)
        ? ' · nén ${_fmtSize(totalOriginal)} → ${_fmtSize(totalCompressed)}'
        : '';
    _showToast('$base$note', isError: fail > 0);
    if (uploaded.isNotEmpty) {
      unawaited(_loadStorageUsage(showLoading: false));
    }
  }

  // ── Xóa ─────────────────────────────────────────────────────────────────

  Future<void> _deleteImage(GalleryImage image) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Xóa ảnh?',
      message: 'Ảnh sẽ bị xóa vĩnh viễn khỏi kho.',
      confirmLabel: 'Xóa',
      icon: Icons.delete_outline,
      destructive: true,
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
      unawaited(_loadStorageUsage(showLoading: false));
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
      destructive: true,
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
      unawaited(_loadStorageUsage(showLoading: false));
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

  // ── Thư mục: tạo / đổi tên / xóa / chuyển ảnh ────────────────────────────

  /// Chuyển nhiều ảnh vào thư mục [folderId] ('' = về "Chưa phân loại").
  /// Cập nhật lạc quan giống [_assignColor].
  Future<void> _assignFolder(Iterable<String> names, String folderId) async {
    final list = names.toList();
    if (list.isEmpty) return;
    setState(() {
      for (final n in list) {
        if (folderId == _unsorted) {
          _imageFolders.remove(n);
        } else {
          _imageFolders[n] = folderId;
        }
      }
    });
    try {
      await _meta.setFolder(list, folderId);
    } catch (e) {
      if (mounted) _showToast('Chuyển thư mục thất bại: $e', isError: true);
    }
  }

  /// Hộp thoại nhập tên thư mục (tạo mới hoặc đổi tên). Trả về tên đã trim,
  /// null nếu hủy / để trống.
  Future<String?> _promptFolderName({String? initial}) async {
    return showTextInputDialog(
      context,
      title: initial == null ? 'Tạo thư mục mới' : 'Đổi tên thư mục',
      initialValue: initial ?? '',
      labelText: 'Tên thư mục',
      hintText: 'Ví dụ: Lễ tốt nghiệp',
      confirmLabel: initial == null ? 'Tạo' : 'Lưu',
      emptyErrorText: 'Vui lòng nhập tên thư mục.',
      icon: initial == null
          ? Icons.create_new_folder_outlined
          : Icons.drive_file_rename_outline,
      maxLength: 50,
    );
  }

  /// Hỏi tên rồi tạo thư mục mới; trả về id vừa tạo (null nếu hủy / lỗi).
  Future<String?> _createFolder() async {
    final name = await _promptFolderName();
    if (name == null || !mounted) return null;
    try {
      final id = await _folderService.createFolder(name);
      if (mounted) {
        // Thêm lạc quan để thư mục hiện ngay; stream sẽ đồng bộ lại sau.
        setState(() {
          _folders = [
            ..._folders,
            GalleryFolder(id: id, name: name, timeCreated: DateTime.now()),
          ];
        });
        _showToast('Đã tạo thư mục "$name"');
      }
      return id;
    } catch (e) {
      if (mounted) _showToast('Tạo thư mục thất bại: $e', isError: true);
      return null;
    }
  }

  Future<void> _renameFolder(GalleryFolder folder) async {
    final name = await _promptFolderName(initial: folder.name);
    if (name == null || name == folder.name || !mounted) return;
    // Cập nhật lạc quan; stream sẽ đồng bộ lại sau.
    setState(() {
      _folders = [
        for (final f in _folders)
          f.id == folder.id
              ? GalleryFolder(id: f.id, name: name, timeCreated: f.timeCreated)
              : f,
      ];
    });
    try {
      await _folderService.renameFolder(folder.id, name);
    } catch (e) {
      if (mounted) _showToast('Đổi tên thư mục thất bại: $e', isError: true);
    }
  }

  /// Xóa thư mục: ảnh bên trong quay về "Chưa phân loại", file KHÔNG bị xóa.
  Future<void> _deleteFolder(GalleryFolder folder) async {
    final count = _imagesOf(folder.id).length;
    final confirm = await showConfirmDialog(
      context,
      title: 'Xóa thư mục "${folder.name}"?',
      message: count == 0
          ? 'Thư mục đang trống.'
          : '$count ảnh bên trong sẽ chuyển về "Chưa phân loại" '
                '(không ảnh nào bị xóa).',
      confirmLabel: 'Xóa',
      icon: Icons.folder_delete_outlined,
      destructive: true,
    );
    if (!confirm || !mounted) return;

    // Cập nhật lạc quan: gỡ thư mục khỏi danh sách; ảnh tự quay về "Chưa phân
    // loại" nhờ [_folderOf] bỏ qua id không còn tồn tại.
    setState(() {
      _folders = _folders.where((f) => f.id != folder.id).toList();
      if (_openFolderId == folder.id) _openFolderId = null;
    });
    try {
      await _folderService.deleteFolder(folder.id);
      await _meta.clearFolder(folder.id);
      _showToast('Đã xóa thư mục "${folder.name}"');
    } catch (e) {
      if (mounted) _showToast('Xóa thư mục thất bại: $e', isError: true);
    }
  }

  /// Mở bottom sheet chọn thư mục đích rồi chuyển [names] vào đó
  /// (kèm lựa chọn tạo thư mục mới ngay trong sheet).
  Future<void> _chooseFolderThenMove(List<String> names) async {
    if (names.isEmpty) return;
    const createSentinel = '__create__';
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Chuyển ${names.length} ảnh vào thư mục',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.folder_off_outlined),
                    title: const Text('Chưa phân loại'),
                    onTap: () => Navigator.pop(ctx, _unsorted),
                  ),
                  ..._folders.map(
                    (f) => ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(
                        f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text('${_imagesOf(f.id).length} ảnh'),
                      onTap: () => Navigator.pop(ctx, f.id),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Tạo thư mục mới...'),
              onTap: () => Navigator.pop(ctx, createSentinel),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return; // người dùng đóng sheet -> hủy.

    var folderId = choice;
    if (choice == createSentinel) {
      final id = await _createFolder();
      if (id == null || !mounted) return;
      folderId = id;
    }
    await _assignFolder(names, folderId);
    if (!mounted) return;
    if (_selectionMode) setState(_exitSelection);
    _showToast(
      folderId == _unsorted
          ? 'Đã đưa ${names.length} ảnh về "Chưa phân loại"'
          : 'Đã chuyển ${names.length} ảnh vào "${_folderTitle(folderId)}"',
    );
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
  /// Ở tổng quan = xét cả kho; đang mở thư mục = chỉ xét ảnh thư mục đó.
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

    final all = _scope;
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
    final group = (_images ?? const <GalleryImage>[])
        .where((i) => names.contains(i.name))
        .toList();
    await _downloadGroupAsZip(group, 'da-chon');
  }

  /// Tải lần lượt bytes từng ảnh, đóng gói thành ZIP rồi lưu về máy. Hiển thị
  /// hộp thoại tiến trình (có nút Hủy) trong lúc tải.
  Future<void> _downloadGroupAsZip(
    List<GalleryImage> images,
    String fileLabel,
  ) async {
    if (images.isEmpty) {
      _showToast('Không có ảnh nào để tải');
      return;
    }

    final done = ValueNotifier<int>(0);
    var cancelled = false;
    BuildContext? dialogCtx;
    setState(() => _zipping = true);

    // Hộp thoại tiến trình (không tự đóng được, có nút Hủy).
    unawaited(
      showDialog<void>(
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
      ),
    );

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
    final inFolder = _openFolderId != null;
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
          _StorageUsageBar(
            usage: _storageUsage,
            loading: _storageUsageLoading,
            error: _storageUsageError,
            onRetry: _loadStorageUsage,
          ),
          if (inFolder && _scope.isNotEmpty) _filterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  AppBar _normalAppBar() {
    final inFolder = _openFolderId != null;
    return AppBar(
      title: Text(inFolder ? _folderTitle(_openFolderId!) : 'Kho ảnh'),
      leading: IconButton(
        tooltip: inFolder ? 'Về danh sách thư mục' : 'Quay lại',
        icon: const Icon(Icons.arrow_back),
        onPressed: inFolder ? _closeFolder : () => context.go('/admin'),
      ),
      actions: [
        if (!inFolder)
          IconButton(
            tooltip: 'Tạo thư mục mới',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _uploading ? null : () => _createFolder(),
          ),
        IconButton(
          tooltip: 'Tải ảnh về máy (ZIP) theo màu',
          icon: const Icon(Icons.download_outlined),
          onPressed: (_scope.isEmpty || _uploading || _zipping)
              ? null
              : _chooseColorThenDownloadAll,
        ),
        if (inFolder)
          IconButton(
            tooltip: 'Chọn nhiều ảnh',
            icon: const Icon(Icons.checklist),
            onPressed: _scope.isEmpty
                ? null
                : () => setState(() => _selectionMode = true),
          ),
        IconButton(
          tooltip: _compress
              ? 'Nén ảnh: BẬT (giảm dung lượng)'
              : 'Nén ảnh: TẮT (tải nguyên gốc)',
          icon: Icon(
            _compress
                ? Icons.compress
                : Icons.photo_size_select_actual_outlined,
          ),
          color: _compress ? Theme.of(context).colorScheme.primary : null,
          onPressed: _uploading
              ? null
              : () => setState(() => _compress = !_compress),
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
        IconButton(
          tooltip: 'Chuyển ảnh đã chọn vào thư mục',
          icon: const Icon(Icons.drive_file_move_outlined),
          onPressed: _selected.isEmpty
              ? null
              : () => _chooseFolderThenMove(_selected.toList()),
        ),
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
    if (_openFolderId == null) return _buildOverview(images);
    return _buildFolderGrid();
  }

  // ── Màn tổng quan thư mục ────────────────────────────────────────────────

  Widget _buildOverview(List<GalleryImage> images) {
    // Chờ 2 stream Firestore trả dữ liệu lần đầu để không "nháy" số đếm sai.
    if (!_foldersReady || !_metasReady) {
      return const Center(child: CircularProgressIndicator());
    }
    if (images.isEmpty && _folders.isEmpty) {
      return const Center(
        child: Text('Chưa có ảnh — bấm "Tải ảnh lên" để thêm'),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      // Ô đầu tiên luôn là "Chưa phân loại", sau đó tới các thư mục thật.
      itemCount: _folders.length + 1,
      itemBuilder: (context, i) =>
          i == 0 ? _folderCard(null) : _folderCard(_folders[i - 1]),
    );
  }

  /// Thẻ thư mục ở màn tổng quan: ảnh bìa = ảnh đầu tiên của thư mục, kèm tên
  /// + số ảnh; [folder] = null là thẻ ảo "Chưa phân loại" (không đổi tên/xóa).
  Widget _folderCard(GalleryFolder? folder) {
    final id = folder?.id ?? _unsorted;
    final name = folder?.name ?? 'Chưa phân loại';
    final imgs = _imagesOf(id);
    final cover = imgs.isEmpty ? null : imgs.first;

    return GestureDetector(
      onTap: () => _openFolder(id),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.black12,
              child: cover == null
                  ? Center(
                      child: Icon(
                        folder == null
                            ? Icons.folder_off_outlined
                            : Icons.folder_outlined,
                        size: 44,
                      ),
                    )
                  : Image.network(
                      cover.url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (context, error, stack) => const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),

            // Dải mờ dưới cùng: icon + tên thư mục + số ảnh.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      folder == null ? Icons.folder_off_outlined : Icons.folder,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${imgs.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

            // Menu đổi tên / xóa (chỉ với thư mục thật).
            if (folder != null)
              Positioned(
                top: 4,
                right: 4,
                child: _badge(
                  circle: true,
                  child: PopupMenuButton<String>(
                    tooltip: 'Tùy chọn thư mục',
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (v) => v == 'rename'
                        ? _renameFolder(folder)
                        : _deleteFolder(folder),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.drive_file_rename_outline, size: 20),
                            SizedBox(width: 10),
                            Text('Đổi tên'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.folder_delete_outlined, size: 20),
                            SizedBox(width: 10),
                            Text('Xóa thư mục'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Lưới ảnh trong 1 thư mục ─────────────────────────────────────────────

  Widget _buildFolderGrid() {
    final scope = _scope;
    if (scope.isEmpty) {
      return Center(
        child: Text(
          _openFolderId == _unsorted
              ? 'Không có ảnh nào chưa phân loại'
              : 'Thư mục trống — bấm "Tải ảnh lên" để thêm ảnh vào đây',
        ),
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
                errorBuilder: (context, error, stack) =>
                    const Center(child: Icon(Icons.broken_image_outlined)),
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

            // Chế độ chọn: ô tick; ngược lại: nút gán màu + chuyển thư mục + xóa.
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
                    icon: const Icon(
                      Icons.palette_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (key) => _assignColor([image.name], key),
                    itemBuilder: (_) => _colorMenuItems(),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                left: 4,
                child: _badge(
                  circle: true,
                  child: IconButton(
                    tooltip: 'Chuyển vào thư mục',
                    icon: const Icon(
                      Icons.drive_file_move_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _chooseFolderThenMove([image.name]),
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
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 20,
                    ),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.25),
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
      child: Padding(padding: EdgeInsets.all(circle ? 0 : 4), child: child),
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

class _StorageUsageBar extends StatelessWidget {
  const _StorageUsageBar({
    required this.usage,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final StorageUsage? usage;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final data = usage;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data == null
                      ? 'Dung lượng kho ảnh'
                      : 'Đã dùng ${_formatBytes(data.usedBytes)} / '
                            '${_formatBytes(data.quotaBytes)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (data != null)
                Text(
                  'Còn ${(data.remainingFraction * 100).round()}%',
                  style: theme.textTheme.bodySmall,
                ),
              if (error != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Thử đọc lại dung lượng',
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 7),
          if (loading && data == null)
            const LinearProgressIndicator(minHeight: 7)
          else if (error != null && data == null)
            Text(
              'Chưa đọc được dung lượng Storage. Hãy cài RPC rồi thử lại.',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            )
          else if (data != null)
            Semantics(
              label:
                  'Dung lượng Storage đã dùng ${(data.usedFraction * 100).round()} phần trăm',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: data.usedFraction,
                  minHeight: 8,
                  color: _progressColor(colors, data.remainingFraction),
                  backgroundColor: colors.surfaceContainerHighest,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _progressColor(ColorScheme colors, double remaining) {
    if (remaining <= 0.1) return colors.error;
    if (remaining <= 0.25) return colors.tertiary;
    return colors.primary;
  }

  String _formatBytes(int bytes) {
    const mb = 1024 * 1024;
    const gb = 1024 * mb;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
    return '${(bytes / mb).toStringAsFixed(bytes < 10 * mb ? 1 : 0)} MB';
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
            Text(
              'Không tải được kho ảnh:\n$error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
