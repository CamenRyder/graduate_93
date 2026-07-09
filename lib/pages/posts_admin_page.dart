import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../services/post_service.dart';
import '../services/storage_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/theme_toggle_button.dart';

/// Trang quản lý BÀI VIẾT cho admin: danh sách bài (tiêu đề, ngày, trạng
/// thái Đăng/Nháp), tạo bài mới, sửa, xóa.
///
/// - Nội dung bài: Firestore collection `posts` (xem PostService).
/// - Ảnh trong bài: Supabase Storage prefix `posts/` — xóa bài sẽ xóa kèm ảnh.
class PostsAdminPage extends StatefulWidget {
  const PostsAdminPage({super.key});

  @override
  State<PostsAdminPage> createState() => _PostsAdminPageState();
}

class _PostsAdminPageState extends State<PostsAdminPage> {
  final _service = PostService();
  final _storage = StorageService();

  late final Stream<List<Post>> _stream = _service.watchPosts();

  /// Id các bài đang có thao tác chạy (đổi trạng thái / xóa) — khóa nút lại.
  final _busyIds = <String>{};

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

  /// Xóa bài viết + toàn bộ ảnh của bài trên Storage.
  Future<void> _delete(Post post) async {
    final imageCount = post.imagePaths.length;
    final confirm = await showConfirmDialog(
      context,
      title: 'Xóa bài viết?',
      message: imageCount > 0
          ? 'Bài "${post.title}" và $imageCount ảnh trong bài sẽ bị xóa vĩnh viễn.'
          : 'Bài "${post.title}" sẽ bị xóa vĩnh viễn.',
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
                child: Text('Lỗi khi đọc bài viết:\n${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data!;
          if (posts.isEmpty) {
            return const Center(
              child: Text('Chưa có bài viết — bấm "Viết bài" để tạo'),
            );
          }
          // Cột nội dung hẹp (~720px) như 1 trang blog, hợp cả điện thoại.
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: posts.length,
                itemBuilder: (context, i) => _postCard(posts[i]),
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
        onTap: busy ? null : () => context.push('/posts/${post.id}'),
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
                          fontSize: 16, fontWeight: FontWeight.w600),
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
