import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../models/post_category.dart';
import '../services/category_service.dart';
import '../services/post_service.dart';
import '../services/storage_service.dart';
import '../utils/post_slug.dart';
import '../theme.dart';
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
  final _categoryService = CategoryService();
  final _storage = StorageService();
  final _titleSearchController = TextEditingController();

  late final Stream<List<Post>> _stream = _service.watchPosts();
  late final Stream<List<PostCategory>> _categoriesStream = _categoryService
      .watchCategories();

  String _titleQuery = '';
  DateTimeRange? _timeRange;
  String? _categoryFilter;

  /// null = tất cả; true = đã đăng; false = bản nháp.
  bool? _statusFilter;

  /// Id các bài đang có thao tác chạy (đổi trạng thái / xóa) — khóa nút lại.
  final _busyIds = <String>{};

  bool get _hasSearch =>
      _titleQuery.trim().isNotEmpty ||
      _timeRange != null ||
      _categoryFilter != null ||
      _statusFilter != null;

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
          if (_categoryFilter != null && post.categoryId != _categoryFilter) {
            return false;
          }
          if (_statusFilter != null && post.published != _statusFilter) {
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
      _categoryFilter = null;
      _statusFilter = null;
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

  Widget _filterBar({
    required List<Post> allPosts,
    required int shown,
    required List<PostCategory> categories,
  }) {
    final colors = Theme.of(context).colorScheme;
    final range = _timeRange;
    final published = allPosts.where((p) => p.published).length;
    final drafts = allPosts.length - published;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<bool?>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: null,
                label: Text('Tất cả · ${allPosts.length}'),
              ),
              ButtonSegment(value: true, label: Text('Đã đăng · $published')),
              ButtonSegment(value: false, label: Text('Nháp · $drafts')),
            ],
            selected: {_statusFilter},
            onSelectionChanged: (value) =>
                setState(() => _statusFilter = value.first),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _titleSearchController,
                onChanged: (value) => setState(() => _titleQuery = value),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Tìm theo tiêu đề',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _titleQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tiêu đề tìm kiếm',
                          onPressed: () {
                            _titleSearchController.clear();
                            setState(() => _titleQuery = '');
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                key: ValueKey(_categoryFilter),
                initialValue: _categoryFilter,
                isExpanded: true,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.folder_outlined, size: 19),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tất cả danh mục'),
                  ),
                  const DropdownMenuItem<String?>(
                    value: '',
                    child: Text('Chưa phân loại'),
                  ),
                  for (final category in categories)
                    DropdownMenuItem<String?>(
                      value: category.id,
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _categoryFilter = value),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _selectTimeRange,
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text(
                range == null
                    ? 'Khoảng thời gian'
                    : '${_formatDate(range.start)} – ${_formatDate(range.end)}',
              ),
            ),
            if (range != null)
              IconButton(
                tooltip: 'Xóa khoảng thời gian',
                onPressed: () => setState(() => _timeRange = null),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            if (_hasSearch)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: colors.primary),
                onPressed: _clearSearch,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Xóa bộ lọc'),
              ),
          ],
        ),
        if (_hasSearch) ...[
          const SizedBox(height: 12),
          Text(
            'Tìm thấy $shown/${allPosts.length} bài viết',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;
            return Column(
              children: [
                _topBar(compact: compact),
                Expanded(
                  child: _content(compact: compact, colors: colors),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topBar({required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Về Blog Studio',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/admin'),
          ),
          const SizedBox(width: 4),
          Text(
            'Blog Studio',
            style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Quản lý danh mục',
            icon: const Icon(Icons.folder_outlined),
            onPressed: () => context.push('/admin/categories'),
          ),
          IconButton(
            tooltip: 'Xem trang bài viết (như khách nhìn thấy)',
            icon: const Icon(Icons.menu_book_outlined),
            // push để bấm back từ trang đọc quay lại đây.
            onPressed: () => context.push('/posts'),
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => context.push('/admin/posts/edit'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(compact ? 'Viết' : 'Viết bài mới'),
          ),
        ],
      ),
    );
  }

  Widget _content({required bool compact, required ColorScheme colors}) {
    return StreamBuilder<List<PostCategory>>(
      stream: _categoriesStream,
      builder: (context, categorySnapshot) {
        if (categorySnapshot.hasError) {
          return _message(
            Icons.error_outline,
            'Lỗi khi đọc danh mục',
            '${categorySnapshot.error}',
          );
        }
        if (!categorySnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final categories = categorySnapshot.data!;
        final categoryById = {
          for (final category in categories) category.id: category,
        };

        return StreamBuilder<List<Post>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _message(
                Icons.error_outline,
                'Lỗi khi đọc bài viết',
                '${snapshot.error}',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final allPosts = snapshot.data!;
            final posts = _applySearch(allPosts);

            return ListView(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 32,
                compact ? 24 : 40,
                compact ? 16 : 32,
                80,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bài viết',
                          style: AppTheme.serif(
                            size: compact ? 34 : 44,
                            weight: FontWeight.w600,
                            letterSpacing: -1,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Soạn, đăng và sắp xếp các bài viết của ấn phẩm.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 28),
                        if (allPosts.isEmpty)
                          _emptyAll()
                        else ...[
                          _filterBar(
                            allPosts: allPosts,
                            shown: posts.length,
                            categories: categories,
                          ),
                          const SizedBox(height: 20),
                          if (posts.isEmpty)
                            _message(
                              Icons.search_off_rounded,
                              'Không có bài viết phù hợp',
                              'Thử đổi từ khóa hoặc xóa bộ lọc.',
                            )
                          else
                            Card(
                              child: Column(
                                children: [
                                  for (var i = 0; i < posts.length; i++) ...[
                                    if (i > 0) const Divider(),
                                    _postRow(
                                      posts[i],
                                      categoryById[posts[i].categoryId],
                                      compact: compact,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _emptyAll() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: [
          Text(
            'Trang giấy đang trống.',
            style: AppTheme.serif(
              size: 26,
              weight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bắt đầu bài viết đầu tiên — bạn có thể lưu nháp bất cứ lúc nào.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/admin/posts/edit'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Viết bài đầu tiên'),
          ),
        ],
      ),
    );
  }

  Widget _message(IconData icon, String title, String detail) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _postRow(Post post, PostCategory? category, {required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    final busy = _busyIds.contains(post.id);
    final title = post.title.trim().isEmpty ? '(Chưa có tiêu đề)' : post.title;
    final statusColor = post.published ? AppTheme.success : AppTheme.warning;
    final meta = AppTheme.mono(
      size: 11.5,
      letterSpacing: 0.2,
      color: colors.onSurfaceVariant,
    );

    return InkWell(
      // Chạm vào hàng -> mở trình soạn.
      onTap: busy ? null : () => context.push('/admin/posts/edit/${post.id}'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(compact ? 14 : 20, 16, 8, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          post.published ? 'Đã đăng' : 'Nháp',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          category?.name ?? 'Chưa phân loại',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: meta,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.serif(
                      size: compact ? 19 : 21,
                      weight: FontWeight.w600,
                      height: 1.25,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cập nhật ${_formatTime(post.timeUpdated ?? post.timeCreated)}'
                    '  ·  ${post.blocks.length} khối',
                    style: meta,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: post.published
                  ? 'Đang đăng — tắt để về bản nháp'
                  : 'Bản nháp — bật để đăng',
              child: Switch(
                value: post.published,
                onChanged: busy ? null : (v) => _togglePublished(post, v),
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              PopupMenuButton<String>(
                tooltip: 'Thao tác',
                icon: const Icon(Icons.more_horiz_rounded),
                position: PopupMenuPosition.under,
                onSelected: (value) => switch (value) {
                  'edit' => context.push('/admin/posts/edit/${post.id}'),
                  'view' => context.push(
                    postDetailPath(id: post.id, title: post.title),
                  ),
                  'delete' => _delete(post),
                  _ => null,
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined, size: 19),
                      title: Text('Sửa bài'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'view',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.visibility_outlined, size: 19),
                      title: Text('Xem như khách'),
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: colors.error,
                      ),
                      title: Text(
                        'Xóa bài',
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
