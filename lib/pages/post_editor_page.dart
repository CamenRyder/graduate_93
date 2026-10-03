import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../models/post_category.dart';
import '../services/category_service.dart';
import '../services/post_image_upload_middleware.dart';
import '../services/post_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../theme/post_styles.dart';
import '../theme/row_palette.dart';
import '../utils/post_slug.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/gallery_image_picker_dialog.dart';
import '../widgets/theme_toggle_button.dart';

/// Trình soạn bài viết dạng KHỐI (tự viết, không dùng thư viện editor):
/// tiêu đề + danh sách khối theo thứ tự, mỗi khối là Đề mục / Đề mục phụ /
/// Đoạn văn / Trích dẫn / Mã nguồn / Ảnh.
///
/// Bố cục:
/// - Thanh trên cố định: quay lại, trạng thái lưu, nút Lưu/Đăng.
/// - Canvas giữa: hiển thị y hệt trang đọc (dùng chung post_styles). Công cụ
///   của từng khối (đổi loại, tô màu, di chuyển, gỡ) chỉ hiện khi rê chuột
///   hoặc đang gõ trong khối để mặt giấy luôn sạch.
/// - Cột thiết lập bên phải (màn rộng): trạng thái, danh mục, mục lục,
///   thống kê. Màn hẹp: trạng thái + danh mục nằm ngay dưới tiêu đề.
///
/// Ảnh: chọn từ kho ảnh hệ thống hoặc từ thiết bị. Ảnh từ thiết bị bắt buộc
/// qua middleware resize/nén rồi đưa vào kho ảnh chung ở trạng thái chưa phân
/// loại. Gỡ ảnh khỏi bài không xóa ảnh trong kho dùng chung.
///
/// [postId] = null -> viết bài mới; khác null -> sửa bài đã có.
class PostEditorPage extends StatefulWidget {
  const PostEditorPage({super.key, this.postId});

  final String? postId;

  @override
  State<PostEditorPage> createState() => _PostEditorPageState();
}

/// Bản nháp 1 khối trong trình soạn (giữ TextEditingController + FocusNode
/// riêng cho khối văn bản; khối ảnh chỉ giữ url + path đã upload).
class _BlockDraft {
  _BlockDraft.text(this.type, {String text = '', this.highlight = ''})
    : ctrl = TextEditingController(text: text),
      focus = FocusNode(),
      url = '',
      path = '';

  _BlockDraft.image({required this.url, required this.path})
    : type = PostBlockType.image,
      ctrl = null,
      focus = null,
      highlight = '';

  PostBlockType type;
  final TextEditingController? ctrl;
  final FocusNode? focus;
  String highlight;
  final String url;
  final String path;

  /// Chuyển thành [PostBlock] để ghi lên Firestore.
  PostBlock toBlock() => type == PostBlockType.image
      ? PostBlock(type: type, url: url, path: path)
      : PostBlock(type: type, text: ctrl!.text.trim(), highlight: highlight);

  /// Chuỗi đại diện nội dung — so với bản đã lưu để biết có thay đổi chưa.
  String get signature => type == PostBlockType.image
      ? 'img:$path'
      : '${type.name}:$highlight:${ctrl!.text.trim()}';

  void dispose() {
    ctrl?.dispose();
    focus?.dispose();
  }
}

enum _SaveState { fresh, saved, dirty, saving }

class _PostEditorPageState extends State<PostEditorPage> {
  final _service = PostService();
  final _categoryService = CategoryService();
  final _storage = StorageService();
  final _imageUpload = PostImageUploadMiddleware();

  final _titleCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  final _blocks = <_BlockDraft>[];
  late final Stream<List<PostCategory>> _categoriesStream = _categoryService
      .watchCategories();

  /// Khối đã gỡ — chỉ dispose khi trang đóng (dispose ngay lúc gỡ thì
  /// TextField còn sống trong frame hiện tại sẽ lỗi).
  final _removedDrafts = <_BlockDraft>[];

  bool _published = false;
  String _categoryId = '';
  bool _loading = false;
  String? _loadError;
  bool _saving = false;
  bool _uploading = false;

  /// Chữ ký nội dung lần lưu/tải gần nhất (null = bài mới chưa từng lưu).
  String? _savedSignature;

  bool get _isEdit => widget.postId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _load();
    } else {
      // Bài mới: sẵn 1 đoạn văn trống, con trỏ đặt ở tiêu đề.
      _blocks.add(_BlockDraft.text(PostBlockType.paragraph));
      _savedSignature = _signature();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleFocus.dispose();
    for (final d in _blocks) {
      d.dispose();
    }
    for (final d in _removedDrafts) {
      d.dispose();
    }
    super.dispose();
  }

  /// Đọc bài đang sửa từ Firestore rồi đổ vào form.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final post = await _service.getPost(widget.postId!);
      if (!mounted) return;
      if (post == null) {
        setState(() {
          _loading = false;
          _loadError = 'Không tìm thấy bài viết (có thể đã bị xóa).';
        });
        return;
      }
      _titleCtrl.text = post.title;
      _blocks
        ..clear()
        ..addAll(
          post.blocks.map(
            (b) => b.type == PostBlockType.image
                ? _BlockDraft.image(url: b.url, path: b.path)
                : _BlockDraft.text(
                    b.type,
                    text: b.text,
                    highlight: b.highlight,
                  ),
          ),
        );
      setState(() {
        _published = post.published;
        _categoryId = post.categoryId;
        _loading = false;
        _savedSignature = _signature();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$e';
      });
    }
  }

  // ── Trạng thái thay đổi ──────────────────────────────────────────────────

  String _signature() => [
    _titleCtrl.text.trim(),
    '$_published',
    _categoryId,
    for (final d in _blocks) d.signature,
  ].join('\u0001');

  bool get _isDirty => _signature() != _savedSignature;

  /// Mọi thứ khiến chữ ký thay đổi khi gõ (tiêu đề + ô nhập các khối).
  Listenable get _contentChanges => Listenable.merge([
    _titleCtrl,
    for (final d in _blocks)
      if (d.ctrl != null) d.ctrl!,
  ]);

  _SaveState get _saveState {
    if (_saving) return _SaveState.saving;
    if (_isDirty) return _SaveState.dirty;
    return _isEdit ? _SaveState.saved : _SaveState.fresh;
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  /// Quay lại danh sách — hỏi lại nếu còn thay đổi chưa lưu.
  Future<void> _leave() async {
    if (_isDirty && !_saving) {
      final confirm = await showConfirmDialog(
        context,
        title: 'Rời trang khi chưa lưu?',
        message: 'Những thay đổi chưa lưu trong bài sẽ bị mất.',
        confirmLabel: 'Rời trang',
        cancelLabel: 'Ở lại',
        icon: Icons.warning_amber_rounded,
        destructive: true,
      );
      if (!confirm || !mounted) return;
    }
    context.go('/admin/posts');
  }

  // ── Thêm / gỡ / di chuyển khối ────────────────────────────────────────────

  /// Thêm khối [type] vào vị trí [at] (mặc định cuối bài). Khối ảnh mở bảng
  /// chọn nguồn; khối chữ được focus ngay để gõ tiếp.
  Future<void> _addBlock(PostBlockType type, {int? at}) async {
    if (type == PostBlockType.image) {
      await _chooseImageSource(at: at);
      return;
    }
    final draft = _BlockDraft.text(type);
    setState(() => _blocks.insert(at ?? _blocks.length, draft));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) draft.focus?.requestFocus();
    });
  }

  /// Chọn nguồn ảnh trước khi thêm khối: kho dùng chung hoặc thiết bị.
  Future<void> _chooseImageSource({int? at}) async {
    final source = await showModalBottomSheet<_PostImageSource>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text(
                  'Thêm hình ảnh',
                  style: Theme.of(ctx).textTheme.headlineSmall,
                ),
              ),
              _SourceTile(
                icon: Icons.photo_library_outlined,
                title: 'Kho ảnh hệ thống',
                subtitle: 'Dùng lại ảnh đã có trong kho dùng chung',
                onTap: () => Navigator.pop(ctx, _PostImageSource.systemGallery),
              ),
              _SourceTile(
                icon: Icons.upload_file_outlined,
                title: 'Tải lên từ thiết bị',
                subtitle: 'Ảnh được giảm dung lượng và thêm vào kho chung',
                onTap: () => Navigator.pop(ctx, _PostImageSource.device),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    switch (source) {
      case _PostImageSource.systemGallery:
        await _pickImagesFromSystemGallery(at: at);
      case _PostImageSource.device:
        await _pickAndUploadDeviceImages(at: at);
    }
  }

  /// Chọn nhiều ảnh đã có trong kho. Chỉ tạo liên kết trong bài, không upload
  /// bản sao và không thay đổi metadata phân loại của ảnh.
  Future<void> _pickImagesFromSystemGallery({int? at}) async {
    final images = await showGalleryImagePickerDialog(context);
    if (images == null || images.isEmpty || !mounted) return;
    setState(() {
      var index = at ?? _blocks.length;
      for (final image in images) {
        _blocks.insert(
          index++,
          _BlockDraft.image(url: image.url, path: image.fullPath),
        );
      }
    });
    _showToast('Đã thêm ${images.length} ảnh từ kho hệ thống');
  }

  /// Chọn ảnh từ máy (withData để có bytes trên web). Mọi file bắt buộc đi
  /// qua [PostImageUploadMiddleware], sau đó mỗi ảnh thành 1 khối.
  Future<void> _pickAndUploadDeviceImages({int? at}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true, // bắt buộc trên web để có bytes.
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    setState(() => _uploading = true);
    var index = at ?? _blocks.length;
    var fail = 0;
    var uploaded = 0;
    var totalOriginal = 0;
    var totalStored = 0;
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        fail++;
        continue;
      }
      try {
        final result = await _imageUpload.uploadDeviceImage(
          bytes: bytes,
          filename: file.name,
        );
        uploaded++;
        totalOriginal += result.originalSize;
        totalStored += result.storedSize;
        if (!mounted) return;
        setState(
          () => _blocks.insert(
            index.clamp(0, _blocks.length),
            _BlockDraft.image(
              url: result.image.url,
              path: result.image.fullPath,
            ),
          ),
        );
        index++;
      } catch (_) {
        fail++;
      }
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    final base = fail == 0
        ? 'Đã thêm $uploaded ảnh vào bài và kho ảnh chung'
        : 'Đã thêm $uploaded ảnh, lỗi $fail ảnh';
    final compression = totalOriginal > 0
        ? ' · ${_formatBytes(totalOriginal)} → ${_formatBytes(totalStored)}'
        : '';
    _showToast('$base$compression', isError: fail > 0);
  }

  /// Gỡ 1 khối. Ảnh kho chung chỉ gỡ khỏi bài; ảnh cũ dưới `posts/` vẫn xóa
  /// file riêng như trước. Khối văn bản có chữ sẽ hỏi để tránh lỡ tay.
  Future<void> _removeBlock(_BlockDraft d) async {
    if (d.type == PostBlockType.image) {
      final isLegacyOwned = StorageService.isPostOwnedImagePath(d.path);
      final confirm = await showConfirmDialog(
        context,
        title: 'Gỡ ảnh khỏi bài?',
        message: isLegacyOwned
            ? 'Đây là ảnh cũ lưu riêng cho bài và sẽ bị xóa khỏi bộ nhớ.'
            : 'Ảnh chỉ được gỡ khỏi bài viết và vẫn còn trong kho ảnh chung.',
        confirmLabel: 'Gỡ ảnh',
        icon: Icons.delete_outline,
        destructive: isLegacyOwned,
      );
      if (!confirm || !mounted) return;
      if (isLegacyOwned) {
        try {
          await _storage.deletePostImages([d.path]);
        } catch (e) {
          if (mounted) _showToast('Xóa file ảnh thất bại: $e', isError: true);
        }
        if (!mounted) return;
      }
    } else if (d.ctrl!.text.trim().isNotEmpty) {
      final confirm = await showConfirmDialog(
        context,
        title: 'Gỡ khối này?',
        message: 'Nội dung trong khối sẽ mất khi lưu bài.',
        confirmLabel: 'Gỡ',
        icon: Icons.delete_outline,
        destructive: true,
      );
      if (!confirm || !mounted) return;
    }

    setState(() {
      _blocks.remove(d);
      _removedDrafts.add(d);
    });
  }

  /// Đổi chỗ khối [d] với khối liền kề ([delta] = -1 lên / +1 xuống).
  void _moveBlock(_BlockDraft d, int delta) {
    final index = _blocks.indexOf(d);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= _blocks.length) return;
    setState(() {
      _blocks.removeAt(index);
      _blocks.insert(target, d);
    });
  }

  // ── Lưu ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_saving || _uploading || _loading || _loadError != null) return;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _showToast('Bài viết cần có tiêu đề trước khi lưu', isError: true);
      _titleFocus.requestFocus();
      return;
    }

    // Bỏ các khối văn bản trống; khối ảnh luôn giữ.
    final blocks = [
      for (final d in _blocks)
        if (d.type == PostBlockType.image || d.ctrl!.text.trim().isNotEmpty)
          d.toBlock(),
    ];

    setState(() => _saving = true);
    try {
      final post = Post(
        id: widget.postId ?? '',
        title: title,
        published: _published,
        categoryId: _categoryId,
        blocks: blocks,
        timeCreated: null,
        timeUpdated: null,
      );
      if (_isEdit) {
        await _service.updatePost(post);
      } else {
        await _service.createPost(post);
      }
      if (!mounted) return;
      _savedSignature = _signature();
      _showToast(_published ? 'Đã lưu và đăng bài viết' : 'Đã lưu bản nháp');
      context.go('/admin/posts');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showToast('Lỗi khi lưu: $e', isError: true);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        },
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 640;
                final wide = constraints.maxWidth >= 1120;
                return Column(
                  children: [
                    ListenableBuilder(
                      listenable: _contentChanges,
                      builder: (context, _) => _EditorTopBar(
                        compact: compact,
                        isEdit: _isEdit,
                        published: _published,
                        saveState: _loading || _loadError != null
                            ? null
                            : _saveState,
                        busy: _saving || _uploading,
                        onBack: _leave,
                        onSave: (_loading || _loadError != null) ? null : _save,
                        onView: _isEdit
                            ? () => context.push(
                                postDetailPath(
                                  id: widget.postId!,
                                  title: _titleCtrl.text,
                                ),
                              )
                            : null,
                      ),
                    ),
                    SizedBox(
                      height: 2,
                      child: (_saving || _uploading)
                          ? const LinearProgressIndicator(minHeight: 2)
                          : null,
                    ),
                    Expanded(
                      child: _body(compact: compact, wide: wide),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _body({required bool compact, required bool wide}) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _EditorMessage(
        icon: Icons.find_in_page_outlined,
        title: 'Không mở được bài viết',
        message: _loadError!,
        actionLabel: 'Về danh sách bài viết',
        onAction: () => context.go('/admin/posts'),
      );
    }

    final canvas = _canvas(compact: compact, showSettings: !wide);
    if (!wide) return canvas;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: canvas),
        _sidebar(),
      ],
    );
  }

  /// Mặt giấy soạn thảo: tiêu đề, dòng metadata, các khối, thanh thêm khối.
  Widget _canvas({required bool compact, required bool showSettings}) {
    final colors = Theme.of(context).colorScheme;
    final gutter = compact ? 0.0 : _EditorBlock.gutterWidth;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 24,
        compact ? 28 : 56,
        compact ? 16 : 24,
        160,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 720 + gutter * 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListenableBuilder(
                        listenable: _contentChanges,
                        builder: (context, _) => _MetaLine(
                          published: _published,
                          stats: _PostStats.of(_blocks),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _titleCtrl,
                        focusNode: _titleFocus,
                        minLines: 1,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _focusFirstBlock(),
                        style: AppTheme.serif(
                          size: compact ? 36 : 48,
                          weight: FontWeight.w600,
                          height: 1.1,
                          letterSpacing: compact ? -0.8 : -1.2,
                          color: colors.onSurface,
                        ),
                        decoration: _bareDecoration(
                          hintText: 'Tiêu đề bài viết',
                          hintStyle: AppTheme.serif(
                            size: compact ? 36 : 48,
                            weight: FontWeight.w600,
                            height: 1.1,
                            letterSpacing: compact ? -0.8 : -1.2,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                      ),
                      if (showSettings) ...[
                        const SizedBox(height: 22),
                        _inlineSettings(),
                      ],
                      const SizedBox(height: 28),
                      Divider(color: colors.outlineVariant),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                if (_blocks.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: gutter,
                      vertical: 12,
                    ),
                    child: Text(
                      'Bài viết đang trống. Chọn một loại khối bên dưới để bắt đầu.',
                      style: AppTheme.serif(
                        size: 18,
                        style: FontStyle.italic,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (var i = 0; i < _blocks.length; i++)
                  _EditorBlock(
                    key: ObjectKey(_blocks[i]),
                    draft: _blocks[i],
                    compact: compact,
                    isFirst: i == 0,
                    isLast: i == _blocks.length - 1,
                    onChanged: () => setState(() {}),
                    onMove: (delta) => _moveBlock(_blocks[i], delta),
                    onRemove: () => _removeBlock(_blocks[i]),
                    onInsertBelow: (type) => _addBlock(type, at: i + 1),
                  ),
                const SizedBox(height: 28),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: _BlockInserter(
                    enabled: !_uploading && !_saving,
                    uploading: _uploading,
                    onAdd: _addBlock,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _focusFirstBlock() {
    for (final d in _blocks) {
      if (d.focus != null) {
        d.focus!.requestFocus();
        return;
      }
    }
    _addBlock(PostBlockType.paragraph);
  }

  /// Trạng thái + danh mục đặt ngay dưới tiêu đề (màn hẹp, không có cột bên).
  Widget _inlineSettings() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _statusControl(),
        SizedBox(width: 280, child: _categoryField(dense: true)),
      ],
    );
  }

  Widget _statusControl() {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: false,
          label: Text('Nháp'),
          icon: Icon(Icons.edit_note_rounded, size: 18),
        ),
        ButtonSegment(
          value: true,
          label: Text('Đăng'),
          icon: Icon(Icons.public_rounded, size: 17),
        ),
      ],
      selected: {_published},
      onSelectionChanged: _saving
          ? null
          : (value) => setState(() => _published = value.first),
    );
  }

  /// Cột thiết lập bên phải trên màn rộng.
  Widget _sidebar() {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(left: BorderSide(color: colors.outlineVariant)),
      ),
      child: ListenableBuilder(
        listenable: _contentChanges,
        builder: (context, _) {
          final stats = _PostStats.of(_blocks);
          final outline = [
            for (final d in _blocks)
              if ((d.type == PostBlockType.heading ||
                      d.type == PostBlockType.subheading) &&
                  d.ctrl!.text.trim().isNotEmpty)
                d,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            children: [
              const _SidebarLabel('Xuất bản'),
              _statusControl(),
              const SizedBox(height: 10),
              Text(
                _published
                    ? 'Khách đọc được bài này ngay sau khi lưu.'
                    : 'Chỉ bạn nhìn thấy. Chọn "Đăng" khi bài đã sẵn sàng.',
                style: text.bodySmall,
              ),
              const _SidebarDivider(),
              const _SidebarLabel('Danh mục'),
              _categoryField(dense: false),
              const _SidebarDivider(),
              const _SidebarLabel('Mục lục'),
              if (outline.isEmpty)
                Text(
                  'Thêm khối Đề mục để tạo mục lục cho người đọc.',
                  style: text.bodySmall,
                )
              else
                for (final d in outline)
                  _OutlineItem(
                    label: d.ctrl!.text.trim(),
                    nested: d.type == PostBlockType.subheading,
                    onTap: () => d.focus?.requestFocus(),
                  ),
              const _SidebarDivider(),
              const _SidebarLabel('Thống kê'),
              _StatsGrid(stats: stats),
              const _SidebarDivider(),
              Row(
                children: [
                  _KeyCap(label: '⌘ S'),
                  const SizedBox(width: 6),
                  Text('/', style: text.bodySmall),
                  const SizedBox(width: 6),
                  _KeyCap(label: 'Ctrl S'),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Lưu nhanh', style: text.bodySmall)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _categoryField({required bool dense}) {
    return StreamBuilder<List<PostCategory>>(
      stream: _categoriesStream,
      builder: (context, snapshot) {
        final colors = Theme.of(context).colorScheme;
        if (snapshot.hasError) {
          return Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: colors.error),
              const SizedBox(width: 8),
              const Expanded(child: Text('Không tải được danh mục')),
              TextButton(
                onPressed: () => context.push('/admin/categories'),
                child: const Text('Quản lý'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const LinearProgressIndicator(minHeight: 2);
        }

        final categories = snapshot.data!;
        final categoryExists =
            _categoryId.isEmpty ||
            categories.any((category) => category.id == _categoryId);
        final dropdown = DropdownButtonFormField<String>(
          key: ValueKey(_categoryId),
          initialValue: _categoryId,
          isExpanded: true,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Danh mục',
            prefixIcon: const Icon(Icons.folder_outlined, size: 19),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: dense ? 11 : 13,
            ),
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('Chưa phân loại')),
            if (!categoryExists)
              DropdownMenuItem(
                value: _categoryId,
                child: Text('Danh mục đã bị xóa ($_categoryId)'),
              ),
            for (final category in categories)
              DropdownMenuItem(
                value: category.id,
                child: Text(
                  category.visible
                      ? category.name
                      : '${category.name} (đang ẩn)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _saving
              ? null
              : (value) => setState(() => _categoryId = value ?? ''),
        );
        if (dense) return dropdown;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            dropdown,
            const SizedBox(height: 6),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 36),
              ),
              onPressed: () => context.push('/admin/categories'),
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: const Text('Quản lý danh mục'),
            ),
          ],
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)}KB';
  }
}

enum _PostImageSource { systemGallery, device }

// ═════════════════════════════════════════════════════════════════════════
// Thanh trên cùng
// ═════════════════════════════════════════════════════════════════════════

class _EditorTopBar extends StatelessWidget {
  const _EditorTopBar({
    required this.compact,
    required this.isEdit,
    required this.published,
    required this.saveState,
    required this.busy,
    required this.onBack,
    required this.onSave,
    required this.onView,
  });

  final bool compact;
  final bool isEdit;
  final bool published;
  final _SaveState? saveState;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback? onSave;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final saving = saveState == _SaveState.saving;
    final saveLabel = saving
        ? 'Đang lưu…'
        : published
        ? (compact ? 'Đăng' : (isEdit ? 'Lưu & đăng' : 'Đăng bài'))
        : (compact ? 'Lưu' : 'Lưu nháp');

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Về danh sách bài viết',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          if (!compact) ...[
            Text(
              'Bài viết',
              style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '/',
                style: TextStyle(fontSize: 14, color: colors.outline),
              ),
            ),
            Text(
              isEdit ? 'Chỉnh sửa' : 'Bài mới',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 16),
          ],
          if (saveState != null) _SaveStatusPill(state: saveState!),
          const Spacer(),
          const ThemeToggleButton(),
          if (onView != null) ...[
            const SizedBox(width: 4),
            compact
                ? IconButton(
                    tooltip: 'Xem bản đã lưu',
                    onPressed: onView,
                    icon: const Icon(Icons.visibility_outlined),
                  )
                : OutlinedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Xem bài'),
                  ),
          ],
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: (onSave == null || busy) ? null : onSave,
            icon: saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : Icon(
                    published ? Icons.public_rounded : Icons.check_rounded,
                    size: 18,
                  ),
            label: Text(saveLabel),
          ),
        ],
      ),
    );
  }
}

class _SaveStatusPill extends StatelessWidget {
  const _SaveStatusPill({required this.state});

  final _SaveState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, color) = switch (state) {
      _SaveState.saving => ('Đang lưu', colors.primary),
      _SaveState.dirty => ('Chưa lưu', AppTheme.warning),
      _SaveState.saved => ('Đã lưu', AppTheme.success),
      _SaveState.fresh => ('Bài mới', colors.onSurfaceVariant),
    };
    return Semantics(
      liveRegion: true,
      label: 'Trạng thái: $label',
      child: AnimatedContainer(
        duration: AppTheme.motionBase,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Canvas
// ═════════════════════════════════════════════════════════════════════════

/// Dòng metadata phía trên tiêu đề — giống dòng metadata ở trang đọc.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.published, required this.stats});

  final bool published;
  final _PostStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = AppTheme.mono(
      size: 11.5,
      weight: FontWeight.w600,
      letterSpacing: 0.6,
      color: colors.onSurfaceVariant,
    );
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          published ? 'ĐĂNG CÔNG KHAI' : 'BẢN NHÁP',
          style: style.copyWith(
            color: published ? AppTheme.success : colors.primary,
          ),
        ),
        Text('·', style: style),
        Text('${stats.words} CHỮ', style: style),
        Text('·', style: style),
        Text('${stats.minutes} PHÚT ĐỌC', style: style),
      ],
    );
  }
}

/// 1 khối trong trình soạn. Cột trái: nút đổi loại; cột phải: tô màu + menu
/// thao tác. Cả hai chỉ hiện khi rê chuột/đang gõ (màn hẹp luôn hiện mờ).
class _EditorBlock extends StatefulWidget {
  const _EditorBlock({
    super.key,
    required this.draft,
    required this.compact,
    required this.isFirst,
    required this.isLast,
    required this.onChanged,
    required this.onMove,
    required this.onRemove,
    required this.onInsertBelow,
  });

  static const double gutterWidth = 44;

  final _BlockDraft draft;
  final bool compact;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onChanged;
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;
  final ValueChanged<PostBlockType> onInsertBelow;

  @override
  State<_EditorBlock> createState() => _EditorBlockState();
}

class _EditorBlockState extends State<_EditorBlock> {
  bool _hovered = false;
  bool _menuOpen = false;

  _BlockDraft get d => widget.draft;
  bool get _focused => d.focus?.hasFocus ?? false;
  bool get _active => _hovered || _focused || _menuOpen;

  @override
  void initState() {
    super.initState();
    d.focus?.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _EditorBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
      oldWidget.draft.focus?.removeListener(_onFocus);
      d.focus?.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    d.focus?.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  void _setType(PostBlockType type) {
    d.type = type;
    if (type == PostBlockType.code) d.highlight = '';
    widget.onChanged();
    d.focus?.requestFocus();
  }

  void _setHighlight(String key) {
    d.highlight = key;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final toolsOpacity = _active ? 1.0 : (widget.compact ? 0.55 : 0.0);
    final spacing = postBlockSpacing(d.type);

    final content = _content(context);

    final leading = AnimatedOpacity(
      opacity: toolsOpacity,
      duration: AppTheme.motionFast,
      child: d.type.isText
          ? _TypeButton(type: d.type, onSelected: _setType)
          : _GutterIcon(icon: postBlockIcon(d.type), tooltip: 'Khối ảnh'),
    );
    final trailing = AnimatedOpacity(
      opacity: toolsOpacity,
      duration: AppTheme.motionFast,
      child: _BlockMenu(
        draft: d,
        isFirst: widget.isFirst,
        isLast: widget.isLast,
        onOpenChanged: (open) => setState(() => _menuOpen = open),
        onHighlight: _setHighlight,
        onMove: widget.onMove,
        onInsertBelow: widget.onInsertBelow,
        onRemove: widget.onRemove,
      ),
    );

    final Widget row;
    if (widget.compact) {
      // Màn hẹp: công cụ nằm trên 1 hàng mỏng phía trên nội dung.
      row = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              leading,
              const SizedBox(width: 4),
              AnimatedOpacity(
                opacity: toolsOpacity,
                duration: AppTheme.motionFast,
                child: Text(
                  d.type.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              trailing,
            ],
          ),
          content,
        ],
      );
    } else {
      final topOffset = switch (d.type) {
        PostBlockType.heading => 4.0,
        PostBlockType.subheading => 1.0,
        PostBlockType.code || PostBlockType.image => 0.0,
        _ => 0.0,
      };
      row = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _EditorBlock.gutterWidth,
            child: Padding(
              padding: EdgeInsets.only(top: topOffset),
              child: Align(alignment: Alignment.topLeft, child: leading),
            ),
          ),
          Expanded(child: content),
          SizedBox(
            width: _EditorBlock.gutterWidth,
            child: Padding(
              padding: EdgeInsets.only(top: topOffset),
              child: Align(alignment: Alignment.topRight, child: trailing),
            ),
          ),
        ],
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        // Khoảng cách giống trang đọc nhưng gọn hơn một chút khi soạn.
        padding: EdgeInsets.only(
          top: spacing.top * 0.75,
          bottom: spacing.bottom * 0.75,
        ),
        child: row,
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (d.type == PostBlockType.image) return _ImagePreview(url: d.url);

    final colors = Theme.of(context).colorScheme;
    final style = postBlockTextStyle(context, d.type);
    final isCode = d.type == PostBlockType.code;

    Widget field = TextField(
      controller: d.ctrl,
      focusNode: d.focus,
      minLines: 1,
      maxLines: null, // tự giãn theo nội dung.
      keyboardType: TextInputType.multiline,
      style: style,
      cursorColor: isCode ? PostCodeColors.text : null,
      decoration: _bareDecoration(
        hintText: postBlockHint(d.type),
        hintStyle: style.copyWith(
          color: isCode
              ? PostCodeColors.gutter
              : colors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );

    if (isCode) {
      return Container(
        decoration: BoxDecoration(
          color: PostCodeColors.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: PostCodeColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 11, 18, 9),
              child: Text(
                'CODE',
                style: AppTheme.mono(
                  size: 10.5,
                  weight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: PostCodeColors.gutter,
                ),
              ),
            ),
            const Divider(height: 1, color: PostCodeColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: field,
            ),
          ],
        ),
      );
    }

    if (d.type == PostBlockType.quote) {
      field = Container(
        padding: const EdgeInsets.only(left: 22),
        decoration: postQuoteDecoration(context),
        child: field,
      );
    }

    final highlight = postHighlightDecoration(context, d.highlight);
    if (highlight != null) {
      field = AnimatedContainer(
        duration: AppTheme.motionBase,
        padding: postHighlightPadding,
        decoration: highlight,
        child: field,
      );
    }
    return field;
  }
}

/// Nút loại khối ở lề trái — bấm để đổi loại.
class _TypeButton extends StatelessWidget {
  const _TypeButton({required this.type, required this.onSelected});

  final PostBlockType type;
  final ValueChanged<PostBlockType> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<PostBlockType>(
      tooltip: 'Đổi loại khối · ${type.label}',
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (ctx) => [
        for (final t in PostBlockType.textTypes)
          PopupMenuItem(
            value: t,
            height: 42,
            child: Row(
              children: [
                Icon(
                  postBlockIcon(t),
                  size: 18,
                  color: t == type ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.label,
                    style: TextStyle(
                      fontWeight: t == type ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (t == type)
                  Icon(Icons.check_rounded, size: 18, color: colors.primary),
              ],
            ),
          ),
      ],
      child: _GutterIcon(icon: postBlockIcon(type)),
    );
  }
}

class _GutterIcon extends StatelessWidget {
  const _GutterIcon({required this.icon, this.tooltip});

  final IconData icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final box = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: colors.outline),
        color: colors.surfaceContainerLow,
      ),
      child: Icon(icon, size: 17, color: colors.onSurfaceVariant),
    );
    return tooltip == null ? box : Tooltip(message: tooltip, child: box);
  }
}

/// Menu thao tác của 1 khối (lề phải).
class _BlockMenu extends StatelessWidget {
  const _BlockMenu({
    required this.draft,
    required this.isFirst,
    required this.isLast,
    required this.onOpenChanged,
    required this.onHighlight,
    required this.onMove,
    required this.onInsertBelow,
    required this.onRemove,
  });

  final _BlockDraft draft;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<bool> onOpenChanged;
  final ValueChanged<String> onHighlight;
  final ValueChanged<int> onMove;
  final ValueChanged<PostBlockType> onInsertBelow;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canHighlight = draft.type.isText && draft.type != PostBlockType.code;
    final current = RowPalette.byKey(draft.highlight);

    Widget item(
      IconData icon,
      String label,
      VoidCallback? onPressed, {
      Color? color,
    }) {
      return MenuItemButton(
        onPressed: onPressed,
        leadingIcon: Icon(icon, size: 18, color: color),
        style: MenuItemButton.styleFrom(
          minimumSize: const Size(220, 42),
          foregroundColor: color,
        ),
        child: Text(label),
      );
    }

    return MenuAnchor(
      onOpen: () => onOpenChanged(true),
      onClose: () => onOpenChanged(false),
      alignmentOffset: const Offset(-180, 4),
      menuChildren: [
        if (canHighlight)
          SubmenuButton(
            leadingIcon: current == null
                ? const Icon(Icons.format_color_fill_rounded, size: 18)
                : ColorDot(option: current, size: 16),
            style: SubmenuButton.styleFrom(minimumSize: const Size(220, 42)),
            menuChildren: [
              MenuItemButton(
                onPressed: () => onHighlight(RowPalette.none),
                leadingIcon: const ColorDot(option: null, size: 16),
                trailingIcon: current == null
                    ? Icon(Icons.check_rounded, size: 16, color: colors.primary)
                    : null,
                child: const Text('Không tô'),
              ),
              for (final o in RowPalette.options)
                MenuItemButton(
                  onPressed: () => onHighlight(o.key),
                  leadingIcon: ColorDot(option: o, size: 16),
                  trailingIcon: o.key == draft.highlight
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: colors.primary,
                        )
                      : null,
                  child: Text(o.label),
                ),
            ],
            child: const Text('Tô màu nền'),
          ),
        item(
          Icons.arrow_upward_rounded,
          'Chuyển lên',
          isFirst ? null : () => onMove(-1),
        ),
        item(
          Icons.arrow_downward_rounded,
          'Chuyển xuống',
          isLast ? null : () => onMove(1),
        ),
        const Divider(),
        item(
          Icons.notes_rounded,
          'Chèn đoạn văn bên dưới',
          () => onInsertBelow(PostBlockType.paragraph),
        ),
        item(
          Icons.image_outlined,
          'Chèn ảnh bên dưới',
          () => onInsertBelow(PostBlockType.image),
        ),
        const Divider(),
        item(
          Icons.delete_outline_rounded,
          draft.type == PostBlockType.image ? 'Gỡ ảnh' : 'Gỡ khối',
          onRemove,
          color: colors.error,
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: 'Thao tác với khối',
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          fixedSize: const Size(32, 32),
          padding: EdgeInsets.zero,
          foregroundColor: colors.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
        ),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_horiz_rounded, size: 20),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 440),
        child: Image.network(
          url,
          width: double.infinity,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
          errorBuilder: (context, error, stack) => SizedBox(
            height: 140,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Không tải được ảnh',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hàng nút thêm khối ở cuối bài — 1 chạm là thêm, không cần mở bảng chọn.
class _BlockInserter extends StatelessWidget {
  const _BlockInserter({
    required this.enabled,
    required this.uploading,
    required this.onAdd,
  });

  final bool enabled;
  final bool uploading;
  final ValueChanged<PostBlockType> onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: colors.outline),
        color: colors.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                'Thêm khối',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              const Spacer(),
              if (uploading) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Đang tải ảnh lên…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in PostBlockType.values)
                ActionChip(
                  avatar: Icon(postBlockIcon(t), size: 17),
                  label: Text(t.label),
                  onPressed: enabled ? () => onAdd(t) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Cột thiết lập
// ═════════════════════════════════════════════════════════════════════════

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.mono(
          size: 11,
          weight: FontWeight.w700,
          letterSpacing: 0.9,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 22),
    child: Divider(),
  );
}

class _OutlineItem extends StatelessWidget {
  const _OutlineItem({
    required this.label,
    required this.nested,
    required this.onTap,
  });

  final String label;
  final bool nested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: EdgeInsets.fromLTRB(nested ? 22 : 10, 7, 8, 7),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: nested ? colors.outlineVariant : colors.outline,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: nested ? 13 : 13.5,
            height: 1.35,
            fontWeight: nested ? FontWeight.w400 : FontWeight.w600,
            color: nested ? colors.onSurfaceVariant : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

class _PostStats {
  const _PostStats({
    required this.words,
    required this.minutes,
    required this.blocks,
    required this.images,
  });

  factory _PostStats.of(List<_BlockDraft> drafts) {
    final words = drafts
        .where((d) => d.type.isText && d.type != PostBlockType.code)
        .expand((d) => d.ctrl!.text.trim().split(RegExp(r'\s+')))
        .where((word) => word.isNotEmpty)
        .length;
    return _PostStats(
      words: words,
      minutes: (words / 220).ceil().clamp(1, 99),
      blocks: drafts.length,
      images: drafts.where((d) => d.type == PostBlockType.image).length,
    );
  }

  final int words;
  final int minutes;
  final int blocks;
  final int images;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final _PostStats stats;

  @override
  Widget build(BuildContext context) {
    Widget cell(String value, String label) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTheme.serif(
              size: 26,
              weight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            cell('${stats.words}', 'chữ'),
            cell('${stats.minutes}', 'phút đọc'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            cell('${stats.blocks}', 'khối nội dung'),
            cell('${stats.images}', 'hình ảnh'),
          ],
        ),
      ],
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: colors.outline),
      ),
      child: Text(
        label,
        style: AppTheme.mono(
          size: 11,
          weight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Phụ trợ
// ═════════════════════════════════════════════════════════════════════════

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Icon(icon, color: colors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
    );
  }
}

class _EditorMessage extends StatelessWidget {
  const _EditorMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: colors.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ô nhập "trần" cho mặt giấy soạn thảo: không nền, không viền ở mọi trạng
/// thái (ghi đè inputDecorationTheme của app).
InputDecoration _bareDecoration({
  required String hintText,
  TextStyle? hintStyle,
}) => InputDecoration(
  hintText: hintText,
  hintStyle: hintStyle,
  isCollapsed: true,
  filled: false,
  contentPadding: EdgeInsets.zero,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
);
