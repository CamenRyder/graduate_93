import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../services/post_service.dart';
import '../services/storage_service.dart';
import '../utils/post_slug.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/theme_toggle_button.dart';

/// Trang quản lý BÀI VIẾT cho admin: danh sách bài (tiêu đề, ngày, trạng
/// thái Đăng/Nháp), tạo bài mới, sửa, xóa.
///
/// - Nội dung bài: Firestore collection `posts` (xem PostService).
/// - Ảnh mới dùng kho ảnh chung nên xóa bài chỉ gỡ liên kết. Riêng ảnh cũ dưới
///   prefix `posts/` vẫn được xóa kèm để không để lại file rác.
class PostsAdminPage extends StatefulWidget {
  const PostsAdminPage({super.key});

  @override
  State<PostsAdminPage> createState() => _PostsAdminPageState();
}

class _PostsAdminPageState extends State<PostsAdminPage> {
  final _service = PostService();
  final _storage = StorageService();
  final _titleSearchController = TextEditingController();

  late final Stream<List<Post>> _stream = _service.watchPosts();

  String _titleQuery = '';
  DateTimeRange? _timeRange;

  /// Id các bài đang có thao tác chạy (đổi trạng thái / xóa) — khóa nút lại.
  final _busyIds = <String>{};

  bool get _hasSearch => _titleQuery.trim().isNotEmpty || _timeRange != null;

  @override
  void dispose() {
    _titleSearchController.dispose();
    super.dispose();
  }

  DateTime? _postTime(Post post) => post.timeUpdated ?? post.timeCreated;

  List<Post> _applySearch(List<Post> posts) {
    final query = _titleQuery.trim().toLowerCase();
    final range = _timeRange;
    final rangeStart = range == null
        ? null
        : DateTime(range.start.year, range.start.month, range.start.day);
    final rangeEndExclusive = range == null
        ? null
        : DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
          ).add(const Duration(days: 1));

    return posts
        .where((post) {
          if (query.isNotEmpty && !post.title.toLowerCase().contains(query)) {
            return false;
          }
          if (rangeStart != null && rangeEndExclusive != null) {
            final postTime = _postTime(post);
            if (postTime == null ||
                postTime.isBefore(rangeStart) ||
                !postTime.isBefore(rangeEndExclusive)) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  Future<void> _selectTimeRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10, 12, 31),
      initialDateRange: _timeRange,
      helpText: 'Chọn khoảng thời gian đăng bài',
      cancelText: 'Hủy',
      confirmText: 'Áp dụng',
      saveText: 'Áp dụng',
      fieldStartHintText: 'Từ ngày',
      fieldEndHintText: 'Đến ngày',
      fieldStartLabelText: 'Từ ngày',
      fieldEndLabelText: 'Đến ngày',
    );
    if (selected == null || !mounted) return;
    setState(() => _timeRange = selected);
  }

  void _clearSearch() {
    setState(() {
      _titleSearchController.clear();
      _titleQuery = '';
      _timeRange = null;
    });
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

  /// Bật/tắt "Đăng" ngay trên danh sách.
  Future<void> _togglePublished(Post post, bool value) async {
    setState(() => _busyIds.add(post.id));
    try {
      await _service.setPublished(post.id, value);
      if (!mounted) return;
      setState(() => _busyIds.remove(post.id));
      _showToast(value ? 'Đã đăng bài viết' : 'Đã chuyển về bản nháp');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyIds.remove(post.id));
      _showToast('Lỗi khi đổi trạng thái: $e', isError: true);
    }
  }

  /// Xóa bài viết và chỉ xóa file ảnh cũ mà bài sở hữu riêng.
  Future<void> _delete(Post post) async {
    final ownedImageCount = post.imagePaths
        .where(StorageService.isPostOwnedImagePath)
        .length;
    final confirm = await showConfirmDialog(
      context,
      title: 'Xóa bài viết?',
      message: ownedImageCount > 0
          ? 'Bài "${post.title}" và $ownedImageCount ảnh cũ lưu riêng sẽ '
                'bị xóa. Ảnh thuộc kho dùng chung vẫn được giữ lại.'
          : 'Bài "${post.title}" sẽ bị xóa. Ảnh trong kho dùng chung vẫn '
                'được giữ lại.',
      confirmLabel: 'Xóa',
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (!confirm || !mounted) return;

    setState(() => _busyIds.add(post.id));
    try {
      await _service.deletePost(post.id);
      // Xóa file ảnh sau khi xóa document; lỗi ảnh không chặn việc xóa bài.
      await _storage.deletePostImages(post.imagePaths);
      if (!mounted) return;
      setState(() => _busyIds.remove(post.id));
      _showToast('Đã xóa bài viết');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyIds.remove(post.id));
      _showToast('Lỗi khi xóa: $e', isError: true);
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  }

  Widget _searchPanel({required int total, required int shown}) {
    final colorScheme = Theme.of(context).colorScheme;
    final range = _timeRange;
    final rangeLabel = range == null
        ? 'Chọn khoảng thời gian'
        : '${_formatDate(range.start)} – ${_formatDate(range.end)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tìm kiếm bài viết',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleSearchController,
            onChanged: (value) => setState(() => _titleQuery = value),
            decoration: InputDecoration(
              labelText: 'Tiêu đề bài viết',
              hintText: 'Nhập tiêu đề cần tìm',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _titleQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tiêu đề tìm kiếm',
                      onPressed: () {
                        _titleSearchController.clear();
                        setState(() => _titleQuery = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _selectTimeRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(rangeLabel),
              ),
              if (range != null)
                IconButton.outlined(
                  tooltip: 'Xóa khoảng thời gian',
                  onPressed: () => setState(() => _timeRange = null),
                  icon: const Icon(Icons.close),
                ),
              if (_hasSearch)
                TextButton.icon(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Xóa tìm kiếm'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _hasSearch ? 'Tìm thấy $shown/$total bài viết' : '$total bài viết',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý bài viết'),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          IconButton(
            tooltip: 'Xem trang bài viết (như khách nhìn thấy)',
            icon: const Icon(Icons.menu_book_outlined),
            // push để bấm back từ trang đọc quay lại đây.
            onPressed: () => context.push('/posts'),
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/posts/edit'),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Viết bài'),
      ),
      body: StreamBuilder<List<Post>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Lỗi khi đọc bài viết:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allPosts = snapshot.data!;
          if (allPosts.isEmpty) {
            return const Center(
              child: Text('Chưa có bài viết — bấm "Viết bài" để tạo'),
            );
          }
          final posts = _applySearch(allPosts);
          // Cột nội dung hẹp (~720px) như 1 trang blog, hợp cả điện thoại.
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: posts.isEmpty ? 2 : posts.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _searchPanel(
                      total: allPosts.length,
                      shown: posts.length,
                    );
                  }
                  if (index == 1) {
                    return posts.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text('Không tìm thấy bài viết phù hợp.'),
                            ),
                          )
                        : const SizedBox(height: 14);
                  }
                  return _postCard(posts[index - 2]);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _postCard(Post post) {
    final colorScheme = Theme.of(context).colorScheme;
    final busy = _busyIds.contains(post.id);
    final title = post.title.trim().isEmpty ? '(Chưa có tiêu đề)' : post.title;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Chạm vào thẻ -> xem thử bài như trang đọc.
        onTap: busy
            ? null
            : () =>
                  context.push(postDetailPath(id: post.id, title: post.title)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatTime(post.timeUpdated ?? post.timeCreated)}'
                      ' · ${post.published ? 'Đã đăng' : 'Nháp'}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: post.published
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: post.published
                    ? 'Đang đăng — tắt để về bản nháp'
                    : 'Bản nháp — bật để đăng',
                child: Switch(
                  value: post.published,
                  onChanged: busy ? null : (v) => _togglePublished(post, v),
                ),
              ),
              IconButton(
                tooltip: 'Sửa bài',
                icon: const Icon(Icons.edit_outlined, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: busy
                    ? null
                    : () => context.push('/admin/posts/edit/${post.id}'),
              ),
              busy
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Xóa bài',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: colorScheme.error,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _delete(post),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
