import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../services/image_compressor.dart';
import '../services/post_service.dart';
import '../services/storage_service.dart';
import '../theme/post_styles.dart';
import '../theme/row_palette.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/theme_toggle_button.dart';

/// Trình soạn bài viết dạng KHỐI (tự viết, không dùng thư viện editor):
/// tiêu đề + danh sách khối theo thứ tự, mỗi khối là Đề mục / Đề mục phụ /
/// Đoạn văn / Trích dẫn / Ảnh.
///
/// - Khối văn bản: TextField nhiều dòng tự giãn theo nội dung, đổi được loại,
///   tô được màu nền (tái dùng RowPalette — hợp cả Sáng lẫn Tối).
/// - Khối ảnh: chọn file như kho ảnh (FilePicker, withData) -> nén -> upload
///   lên Supabase Storage prefix `posts/` -> xem trước ngay. Gỡ khối ảnh sẽ
///   xóa luôn file trên Storage.
/// - Sắp xếp: nút lên/xuống trên từng khối; Lưu = tạo/cập nhật document.
///
/// [postId] = null -> viết bài mới; khác null -> sửa bài đã có.
class PostEditorPage extends StatefulWidget {
  const PostEditorPage({super.key, this.postId});

  final String? postId;

  @override
  State<PostEditorPage> createState() => _PostEditorPageState();
}

/// Bản nháp 1 khối trong trình soạn (giữ TextEditingController riêng cho
/// khối văn bản; khối ảnh chỉ giữ url + path đã upload).
class _BlockDraft {
  _BlockDraft.text(this.type, {String text = '', this.highlight = ''})
      : ctrl = TextEditingController(text: text),
        url = '',
        path = '';

  _BlockDraft.image({required this.url, required this.path})
      : type = PostBlockType.image,
        ctrl = null,
        highlight = '';

  PostBlockType type;
  final TextEditingController? ctrl;
  String highlight;
  final String url;
  final String path;

  /// Chuyển thành [PostBlock] để ghi lên Firestore.
  PostBlock toBlock() => type == PostBlockType.image
      ? PostBlock(type: type, url: url, path: path)
      : PostBlock(type: type, text: ctrl!.text.trim(), highlight: highlight);
}

class _PostEditorPageState extends State<PostEditorPage> {
  final _service = PostService();
  final _storage = StorageService();

  final _titleCtrl = TextEditingController();
  final _blocks = <_BlockDraft>[];

  /// Controller của các khối đã gỡ — chỉ dispose khi trang đóng (dispose ngay
  /// lúc gỡ thì TextField còn sống trong frame hiện tại sẽ lỗi).
  final _removedCtrls = <TextEditingController>[];

  bool _published = false;
  bool _loading = false;
  String? _loadError;
  bool _saving = false;
  bool _uploading = false;

  bool get _isEdit => widget.postId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _load();
    } else {
      // Bài mới: sẵn 1 đoạn văn trống cho tiện gõ ngay.
      _blocks.add(_BlockDraft.text(PostBlockType.paragraph));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final d in _blocks) {
      d.ctrl?.dispose();
    }
    for (final c in _removedCtrls) {
      c.dispose();
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
        ..addAll(post.blocks.map(
          (b) => b.type == PostBlockType.image
              ? _BlockDraft.image(url: b.url, path: b.path)
              : _BlockDraft.text(b.type, text: b.text, highlight: b.highlight),
        ));
      setState(() {
        _published = post.published;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$e';
      });
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

  // ── Thêm / gỡ / di chuyển khối ────────────────────────────────────────────

  /// Bảng chọn loại khối muốn thêm (cuối bài).
  Future<void> _showAddMenu() async {
    final type = await showModalBottomSheet<PostBlockType>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Thêm khối nội dung',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final t in PostBlockType.values)
              ListTile(
                leading: Icon(_typeIcon(t)),
                title: Text(t.label),
                onTap: () => Navigator.pop(ctx, t),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    if (type == PostBlockType.image) {
      await _pickAndUploadImages();
    } else {
      setState(() => _blocks.add(_BlockDraft.text(type)));
    }
  }

  IconData _typeIcon(PostBlockType t) => switch (t) {
        PostBlockType.heading => Icons.title,
        PostBlockType.subheading => Icons.text_fields,
        PostBlockType.paragraph => Icons.notes,
        PostBlockType.quote => Icons.format_quote,
        PostBlockType.image => Icons.image_outlined,
      };

  /// Chọn ảnh từ máy (như kho ảnh: withData để có bytes trên web), nén rồi
  /// upload lên `posts/` — mỗi ảnh thành 1 khối ảnh ở cuối bài.
  Future<void> _pickAndUploadImages() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true, // bắt buộc trên web để có bytes.
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    setState(() => _uploading = true);
    var fail = 0;
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        fail++;
        continue;
      }
      try {
        final c = await compressImage(bytes, file.name);
        final img = await _storage.uploadPostImage(
          bytes: c.bytes,
          filename: c.filename,
          contentType: c.contentType,
        );
        if (!mounted) return;
        setState(
          () => _blocks.add(_BlockDraft.image(url: img.url, path: img.fullPath)),
        );
      } catch (_) {
        fail++;
      }
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    if (fail > 0) _showToast('Tải lên lỗi $fail ảnh', isError: true);
  }

  /// Gỡ 1 khối. Khối ảnh -> hỏi xác nhận rồi xóa luôn file trên Storage;
  /// khối văn bản còn chữ -> hỏi xác nhận cho khỏi lỡ tay.
  Future<void> _removeBlock(int index) async {
    final d = _blocks[index];

    if (d.type == PostBlockType.image) {
      final confirm = await showConfirmDialog(
        context,
        title: 'Gỡ ảnh khỏi bài?',
        message: 'Ảnh sẽ bị xóa vĩnh viễn khỏi kho lưu trữ.',
        confirmLabel: 'Gỡ ảnh',
        icon: Icons.delete_outline,
        destructive: true,
      );
      if (!confirm || !mounted) return;
      try {
        await _storage.deletePostImages([d.path]);
      } catch (e) {
        if (mounted) _showToast('Xóa file ảnh thất bại: $e', isError: true);
      }
      if (!mounted) return;
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
      final removed = _blocks.removeAt(index);
      final ctrl = removed.ctrl;
      if (ctrl != null) _removedCtrls.add(ctrl);
    });
  }

  /// Đổi chỗ khối [index] với khối liền kề ([delta] = -1 lên / +1 xuống).
  void _moveBlock(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _blocks.length) return;
    setState(() {
      final d = _blocks.removeAt(index);
      _blocks.insert(target, d);
    });
  }

  // ── Lưu ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _showToast('Vui lòng nhập tiêu đề bài viết', isError: true);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa bài viết' : 'Viết bài mới'),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/admin/posts'),
        ),
        actions: [
          // Công tắc Đăng / Nháp — giá trị được ghi khi bấm "Lưu".
          Text(
            _published ? 'Đăng' : 'Nháp',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Switch(
            value: _published,
            onChanged:
                _saving ? null : (v) => setState(() => _published = v),
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: (_loading || _loadError != null)
          ? null
          : FloatingActionButton.extended(
              onPressed: (_saving || _uploading) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Đang lưu…' : 'Lưu'),
            ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_loadError!, textAlign: TextAlign.center),
        ),
      );
    }

    // Cột nội dung hẹp (~720px) như trang blog — soạn trên máy tính lẫn
    // điện thoại đều thoải mái.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          children: [
            TextField(
              controller: _titleCtrl,
              minLines: 1,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
              decoration: const InputDecoration(
                hintText: 'Tiêu đề bài viết…',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _blocks.length; i++) _blockCard(i),
            const SizedBox(height: 8),
            if (_uploading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Đang tải ảnh lên…'),
                  ],
                ),
              ),
            Center(
              child: OutlinedButton.icon(
                onPressed: _uploading ? null : _showAddMenu,
                icon: const Icon(Icons.add),
                label: const Text('Thêm khối'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Khung 1 khối: thanh công cụ nhỏ bên trên (đổi loại, tô màu, lên/xuống,
  /// gỡ) + nội dung (ô nhập chữ hoặc ảnh xem trước) bên dưới.
  Widget _blockCard(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final d = _blocks[index];
    // Màu nền tô sáng của khối — cùng logic với trang đọc.
    final highlightBg =
        RowPalette.backgroundFor(d.highlight, Theme.of(context).brightness);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 2, 8, 10),
      decoration: BoxDecoration(
        color: highlightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              d.type.isText ? _typeMenu(d) : _imageLabel(),
              const Spacer(),
              if (d.type.isText) _highlightMenu(d),
              _iconBtn(
                Icons.arrow_upward,
                'Chuyển lên',
                index == 0 ? null : () => _moveBlock(index, -1),
              ),
              _iconBtn(
                Icons.arrow_downward,
                'Chuyển xuống',
                index == _blocks.length - 1
                    ? null
                    : () => _moveBlock(index, 1),
              ),
              _iconBtn(
                Icons.delete_outline,
                'Gỡ khối',
                () => _removeBlock(index),
                color: colorScheme.error,
              ),
            ],
          ),
          if (d.type.isText)
            TextField(
              controller: d.ctrl,
              minLines: 1,
              maxLines: null, // tự giãn theo nội dung.
              keyboardType: TextInputType.multiline,
              style: postBlockTextStyle(context, d.type),
              decoration: InputDecoration(
                isDense: true,
                hintText: postBlockHint(d.type),
                border: InputBorder.none,
              ),
            )
          else
            _imagePreview(d),
        ],
      ),
    );
  }

  /// Nhãn loại + menu đổi loại cho khối văn bản.
  Widget _typeMenu(_BlockDraft d) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<PostBlockType>(
      tooltip: 'Đổi loại khối',
      position: PopupMenuPosition.under,
      onSelected: (t) => setState(() => d.type = t),
      itemBuilder: (ctx) => [
        for (final t in PostBlockType.textTypes)
          PopupMenuItem(
            value: t,
            child: Row(
              children: [
                Icon(_typeIcon(t), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(t.label)),
                if (t == d.type)
                  Icon(Icons.check, size: 18, color: colorScheme.primary),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_typeIcon(d.type), size: 16,
                color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              d.type.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 18,
                color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _imageLabel() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 16,
              color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            'Ảnh',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Nút chọn màu tô sáng cho khối văn bản (Không tô + bảng màu RowPalette),
  /// giống nút chọn màu hàng ở bảng users.
  Widget _highlightMenu(_BlockDraft d) {
    final colorScheme = Theme.of(context).colorScheme;
    final current = RowPalette.byKey(d.highlight);
    return PopupMenuButton<String>(
      tooltip: 'Tô màu nền',
      position: PopupMenuPosition.under,
      onSelected: (key) => setState(() => d.highlight = key),
      itemBuilder: (ctx) => [
        _highlightItem(RowPalette.none, 'Không tô', null, d.highlight.isEmpty),
        ...RowPalette.options.map(
          (o) => _highlightItem(o.key, o.label, o, o.key == d.highlight),
        ),
      ],
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: current == null
              ? Icon(Icons.format_color_fill, size: 18,
                  color: colorScheme.onSurfaceVariant)
              : ColorDot(option: current, size: 18),
        ),
      ),
    );
  }

  PopupMenuItem<String> _highlightItem(
    String key,
    String label,
    RowColorOption? option,
    bool selected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuItem<String>(
      value: key,
      child: Row(
        children: [
          ColorDot(option: option, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (selected) Icon(Icons.check, size: 18, color: colorScheme.primary),
        ],
      ),
    );
  }

  Widget _imagePreview(_BlockDraft d) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: Image.network(
            d.url,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (context, error, stack) => const SizedBox(
              height: 120,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed, {
    Color? color,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      color: color,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
    );
  }
}
