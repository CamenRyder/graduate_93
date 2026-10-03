import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../models/post_category.dart';
import '../services/category_service.dart';
import '../services/page_meta.dart';
import '../services/post_service.dart';
import '../theme.dart';
import '../utils/post_search.dart';
import '../utils/post_slug.dart';
import '../utils/seo.dart';
import '../widgets/publication_chrome.dart';

/// Kho bài viết công khai, trình bày như mục lục của một ấn phẩm thay vì lưới
/// thẻ. Bản nháp luôn bị loại khỏi luồng công khai.
class PostsPage extends StatefulWidget {
  const PostsPage({
    super.key,
    this.showBackButton = false,
    this.categorySlug,
    this.initialQuery = '',
    @visibleForTesting this.postsStream,
    @visibleForTesting this.categoriesStream,
  });

  final bool showBackButton;
  final String? categorySlug;

  /// Từ khóa ban đầu lấy từ `?q=` để link tìm kiếm mở ra đã lọc sẵn.
  final String initialQuery;

  /// Nguồn dữ liệu thay thế cho test (mặc định đọc Firestore).
  final Stream<List<Post>>? postsStream;
  final Stream<List<PostCategory>>? categoriesStream;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  late final Stream<List<Post>> _posts =
      widget.postsStream ?? PostService().watchPosts();
  late final Stream<List<PostCategory>> _categories =
      widget.categoriesStream ?? CategoryService().watchCategories();
  late final TextEditingController _search = TextEditingController(
    text: widget.initialQuery,
  );
  late String _query = widget.initialQuery;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    if (value == _query) return;
    setState(() => _query = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PublicationHeader(),
            Expanded(
              child: StreamBuilder<List<PostCategory>>(
                stream: _categories,
                builder: (context, categorySnapshot) {
                  if (categorySnapshot.hasError) {
                    return const _ArchiveState(
                      text: 'Không thể tải danh mục lúc này.',
                    );
                  }
                  if (!categorySnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final categories = categorySnapshot.data!
                      .where((category) => category.visible)
                      .toList(growable: false);
                  final selected = _selectedCategory(categories);
                  if (widget.categorySlug != null && selected == null) {
                    return const _ArchiveState(
                      text: 'Danh mục này không tồn tại hoặc đang được ẩn.',
                    );
                  }

                  return StreamBuilder<List<Post>>(
                    stream: _posts,
                    builder: (context, postSnapshot) {
                      if (postSnapshot.hasError) {
                        return const _ArchiveState(
                          text: 'Không thể tải bài viết lúc này.',
                        );
                      }
                      if (!postSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final visible = postSnapshot.data!
                          .where(
                            (post) =>
                                post.published &&
                                (selected == null ||
                                    post.categoryId == selected.id),
                          )
                          .toList(growable: false);
                      // Lọc nháp TRƯỚC rồi mới tìm, để từ khóa không bao
                      // giờ làm lộ bản nháp.
                      final posts = searchPosts(
                        visible,
                        _query,
                        categoryNames: {
                          for (final category in categories)
                            category.id: category.name,
                        },
                      );
                      return _archive(
                        posts: posts,
                        categories: categories,
                        selected: selected,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  PostCategory? _selectedCategory(List<PostCategory> categories) {
    if (widget.categorySlug == null) return null;
    for (final category in categories) {
      if (category.slug == widget.categorySlug) return category;
    }
    return null;
  }

  Widget _archive({
    required List<Post> posts,
    required List<PostCategory> categories,
    required PostCategory? selected,
  }) {
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    // Trang kết quả tìm kiếm vẫn canonical về trang danh sách gốc.
    PageMeta.set(
      SeoMeta(
        path: selected == null ? '/posts' : '/categories/${selected.slug}',
        title: selected?.name ?? 'Tất cả bài viết',
        description: selected?.description.isNotEmpty == true
            ? selected!.description
            : archiveDescription,
      ),
    );
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 62),
                    if (widget.showBackButton)
                      InkWell(
                        onTap: () => context.go('/'),
                        child: Text(
                          '←  TRANG CHỦ',
                          style: _metaStyle(context, accent: true),
                        ),
                      ),
                    const SizedBox(height: 30),
                    Text(
                      selected?.name ?? 'Tất cả bài viết',
                      style: TextStyle(
                        fontFamily: AppTheme.serifFont,
                        fontSize: MediaQuery.sizeOf(context).width < 640
                            ? 42
                            : 56,
                        height: 1.08,
                        letterSpacing: -1.1,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(
                        selected?.description.isNotEmpty == true
                            ? selected!.description
                            : archiveDescription,
                        style: TextStyle(
                          fontFamily: AppTheme.serifFont,
                          fontSize: 18,
                          height: 1.65,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 42),
                    _CategoryIndex(categories: categories, selected: selected),
                    const SizedBox(height: 28),
                    _SearchField(
                      controller: _search,
                      onChanged: _setQuery,
                      onClear: () {
                        _search.clear();
                        _setQuery('');
                      },
                    ),
                    const SizedBox(height: 36),
                    _ArchiveCount(count: posts.length, query: _query),
                    const SizedBox(height: 8),
                    if (posts.isEmpty)
                      _EmptyArchive(query: _query)
                    else
                      for (final post in posts)
                        _ArchiveRow(
                          post: post,
                          category: categoryById[post.categoryId],
                        ),
                    const SizedBox(height: 96),
                    const PublicationFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryIndex extends StatelessWidget {
  const _CategoryIndex({required this.categories, this.selected});

  final List<PostCategory> categories;
  final PostCategory? selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 17),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 13,
        children: [
          _CategoryLink(
            label: 'Tất cả',
            selected: selected == null,
            onTap: () => context.go('/posts'),
          ),
          for (final category in categories)
            _CategoryLink(
              label: category.name,
              selected: selected?.id == category.id,
              onTap: () => context.go('/categories/${category.slug}'),
            ),
        ],
      ),
    );
  }
}

class _CategoryLink extends StatelessWidget {
  const _CategoryLink({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.monoFont,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.primary : colors.onSurfaceVariant,
            decoration: selected ? TextDecoration.underline : null,
            decorationColor: colors.primary,
            decorationThickness: 1.5,
            decorationStyle: TextDecorationStyle.solid,
          ),
        ),
      ),
    );
  }
}

/// Ô tìm kiếm kiểu "dòng kẻ" hợp với mục lục ấn phẩm: không khung, chỉ gạch
/// dưới, chữ mono giống các nhãn meta.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(
            fontFamily: AppTheme.serifFont,
            fontSize: 18,
            color: colors.onSurface,
          ),
          decoration: InputDecoration(
            isDense: true,
            // Theme chung dùng ô có nền; ô tìm kiếm của mục lục chỉ cần gạch dưới.
            filled: false,
            hintText: 'Tìm bài viết',
            hintStyle: TextStyle(
              fontFamily: AppTheme.serifFont,
              fontSize: 18,
              color: colors.onSurfaceVariant,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 32),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClear,
                  ),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.outlineVariant),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.outlineVariant),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.primary, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchiveCount extends StatelessWidget {
  const _ArchiveCount({required this.count, required this.query});

  final int count;
  final String query;

  @override
  Widget build(BuildContext context) {
    final trimmed = query.trim();
    return Text(
      trimmed.isEmpty
          ? '$count BÀI VIẾT'
          : '$count KẾT QUẢ CHO “${trimmed.toUpperCase()}”',
      style: _metaStyle(context, accent: true),
    );
  }
}

class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({required this.post, this.category});

  final Post post;
  final PostCategory? category;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            context.push(postDetailPath(id: post.id, title: post.title)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metadata = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(post.timeCreated ?? post.timeUpdated),
                    style: _metaStyle(context),
                  ),
                  if (category != null && category!.name.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      category!.name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _metaStyle(context, accent: true),
                    ),
                  ],
                ],
              );
              final article = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title.trim().isEmpty
                        ? '(Chưa có tiêu đề)'
                        : post.title,
                    style: TextStyle(
                      fontFamily: AppTheme.serifFont,
                      fontSize: 27,
                      height: 1.22,
                      letterSpacing: -0.35,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  if (post.snippet.isNotEmpty) ...[
                    const SizedBox(height: 11),
                    Text(
                      post.snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.serifFont,
                        fontSize: 16.5,
                        height: 1.55,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              );

              if (constraints.maxWidth < 680) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    metadata,
                    const SizedBox(height: 15),
                    article,
                    const SizedBox(height: 13),
                    Text(
                      '${_readingMinutes(post)} PHÚT ĐỌC  →',
                      style: _metaStyle(context),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 160, child: metadata),
                  Expanded(child: article),
                  const SizedBox(width: 36),
                  SizedBox(
                    width: 96,
                    child: Text(
                      '${_readingMinutes(post)} PHÚT\nĐỌC  →',
                      textAlign: TextAlign.right,
                      style: _metaStyle(context),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Text(
        query.trim().isEmpty
            ? 'Chưa có bài viết nào trong mục này.'
            : 'Không tìm thấy bài viết nào khớp “${query.trim()}”.',
        style: TextStyle(
          fontFamily: AppTheme.serifFont,
          fontSize: 18,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ArchiveState extends StatelessWidget {
  const _ArchiveState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.serifFont,
            fontSize: 19,
            height: 1.6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

TextStyle _metaStyle(BuildContext context, {bool accent = false}) {
  final colors = Theme.of(context).colorScheme;
  return TextStyle(
    fontFamily: AppTheme.monoFont,
    fontSize: 11.5,
    height: 1.45,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.45,
    color: accent ? colors.primary : colors.onSurfaceVariant,
  );
}

String _formatDate(DateTime? value) {
  if (value == null) return '';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year}';
}

int _readingMinutes(Post post) {
  final words = post.blocks
      .where((block) => block.type.isText && block.type != PostBlockType.code)
      .expand((block) => block.text.trim().split(RegExp(r'\s+')))
      .where((word) => word.isNotEmpty)
      .length;
  return (words / 220).ceil().clamp(1, 99);
}
