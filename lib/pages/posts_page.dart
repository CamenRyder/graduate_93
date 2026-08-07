import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../services/post_service.dart';
import '../widgets/theme_toggle_button.dart';

/// Trang danh sách dành cho người đọc, chỉ hiển thị bài đã đăng.
///
/// Bản nháp chỉ xuất hiện ở màn quản lý `/admin/posts`, kể cả khi trình duyệt
/// hiện vẫn còn phiên đăng nhập admin.
/// Chạm vào thẻ để mở bài chi tiết (`/posts/:id`).
class PostsPage extends StatefulWidget {
  const PostsPage({super.key, this.showBackButton = false});

  /// Route `/` là trang chủ nên không có nút quay lại. Route `/posts` có nút
  /// quay lại vì có thể được mở từ các màn khác.
  final bool showBackButton;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  late final Stream<List<Post>> _stream = PostService().watchPosts();

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài viết'),
        automaticallyImplyLeading: false,
        leading: widget.showBackButton
            ? IconButton(
                tooltip: 'Quay lại',
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<List<Post>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không tải được bài viết:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Đây luôn là màn hình của người đọc: tuyệt đối không hiện bản nháp,
          // kể cả trình duyệt đang giữ phiên đăng nhập admin.
          final posts = snapshot.data!.where((p) => p.published).toList();
          if (posts.isEmpty) {
            return const Center(child: Text('Chưa có bài viết nào.'));
          }

          // Cột nội dung hẹp (~720px) như trang blog, hợp cả điện thoại.
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
    final cover = post.coverUrl;
    final snippet = post.snippet;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/posts/${post.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh bìa = ảnh đầu tiên trong bài (nếu có).
            if (cover.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  cover,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (context, error, stack) =>
                      const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title.trim().isEmpty
                        ? '(Chưa có tiêu đề)'
                        : post.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(post.timeCreated ?? post.timeUpdated),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (snippet.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      snippet,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
