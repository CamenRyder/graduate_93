import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../models/post_category.dart';
import '../services/category_service.dart';
import '../services/post_service.dart';
import '../utils/post_slug.dart';
import '../widgets/theme_toggle_button.dart';

/// Trang danh sách dành cho người đọc, chỉ hiển thị bài đã đăng.
///
/// Bản nháp chỉ xuất hiện ở màn quản lý `/admin/posts`, kể cả khi trình duyệt
/// hiện vẫn còn phiên đăng nhập admin.
/// Chạm vào thẻ để mở bài chi tiết (`/posts/:id/:slug`).
class PostsPage extends StatefulWidget {
  const PostsPage({super.key, this.showBackButton = false, this.categorySlug});

  /// Route `/` là trang chủ nên không có nút quay lại. Route `/posts` có nút
  /// quay lại vì có thể được mở từ các màn khác.
  final bool showBackButton;

  /// Có giá trị khi mở `/categories/:slug`; null = hiển thị tất cả.
  final String? categorySlug;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  late final Stream<List<Post>> _stream = PostService().watchPosts();
  late final Stream<List<PostCategory>> _categoriesStream = CategoryService()
      .watchCategories();

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
      body: StreamBuilder<List<PostCategory>>(
        stream: _categoriesStream,
        builder: (context, categorySnapshot) {
          if (categorySnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không tải được danh mục:\n${categorySnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!categorySnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = categorySnapshot.data!
              .where((category) => category.visible)
              .toList(growable: false);
          PostCategory? selectedCategory;
          for (final category in categories) {
            if (category.slug == widget.categorySlug) {
              selectedCategory = category;
              break;
            }
          }
          if (widget.categorySlug != null && selectedCategory == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Danh mục không tồn tại hoặc đang được ẩn.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<List<Post>>(
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

              // Trang công khai tuyệt đối không hiện bản nháp, kể cả khi
              // trình duyệt đang giữ phiên đăng nhập admin.
              final posts = snapshot.data!
                  .where(
                    (post) =>
                        post.published &&
                        (selectedCategory == null ||
                            post.categoryId == selectedCategory.id),
                  )
                  .toList(growable: false);
              final categoryById = {
                for (final category in categories) category.id: category,
              };

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      _categoryBar(categories, selectedCategory),
                      if (selectedCategory?.description.isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(selectedCategory!.description),
                          ),
                        ),
                      Expanded(
                        child: posts.isEmpty
                            ? Center(
                                child: Text(
                                  selectedCategory == null
                                      ? 'Chưa có bài viết nào.'
                                      : 'Danh mục này chưa có bài viết.',
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  2,
                                  16,
                                  32,
                                ),
                                itemCount: posts.length,
                                itemBuilder: (context, index) => _postCard(
                                  posts[index],
                                  categoryById[posts[index].categoryId],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _categoryBar(
    List<PostCategory> categories,
    PostCategory? selectedCategory,
  ) {
    if (categories.isEmpty) return const SizedBox(height: 12);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Tất cả'),
            selected: selectedCategory == null,
            onSelected: (_) => context.go('/'),
          ),
          for (final category in categories) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(category.name),
              selected: selectedCategory?.id == category.id,
              onSelected: (_) => context.go('/categories/${category.slug}'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _postCard(Post post, PostCategory? category) {
    final colorScheme = Theme.of(context).colorScheme;
    final cover = post.coverUrl;
    final snippet = post.snippet;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push(postDetailPath(id: post.id, title: post.title)),
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
                  if (category != null) ...[
                    const SizedBox(height: 7),
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.folder_outlined, size: 16),
                      label: Text(category.name),
                      onPressed: () =>
                          context.go('/categories/${category.slug}'),
                    ),
                  ],
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
