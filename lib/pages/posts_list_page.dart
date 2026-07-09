import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../controllers/guest_controller.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../widgets/theme_toggle_button.dart';

/// Trang ĐỌC danh sách bài viết — cho khách đã xác thực lẫn admin.
///
/// - Khách: chỉ thấy bài đã đăng (`published == true`).
/// - Admin: thấy cả bản nháp (gắn nhãn "Nháp") để xem trước.
/// Chạm vào thẻ để mở bài chi tiết (`/posts/:id`).
class PostsListPage extends StatefulWidget {
  const PostsListPage({super.key});

  @override
  State<PostsListPage> createState() => _PostsListPageState();
}

class _PostsListPageState extends State<PostsListPage> {
  late final Stream<List<Post>> _stream = PostService().watchPosts();

  /// Quay lại nơi hợp lý: pop nếu được (vd admin push từ trang quản lý),
  /// không thì khách về lịch hẹn, admin về trang quản lý bài viết.
  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else if (guestController.isAuthenticated) {
      context.go('/scheduled');
    } else {
      context.go('/admin/posts');
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = authController.isLoggedIn;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài viết'),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<List<Post>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Không tải được bài viết:\n${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Khách chỉ thấy bài đã đăng; admin thấy cả nháp để xem trước.
          final posts = isAdmin
              ? snapshot.data!
              : snapshot.data!.where((p) => p.published).toList();
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
                  loadingBuilder: (context, child, progress) =>
                      progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (context, error, stack) => const Center(
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          post.title.trim().isEmpty
                              ? '(Chưa có tiêu đề)'
                              : post.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ),
                      // Bản nháp — chỉ admin nhìn thấy trong danh sách.
                      if (!post.published) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Nháp',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
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
