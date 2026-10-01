import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../models/post_category.dart';
import '../services/category_service.dart';
import '../services/post_service.dart';
import '../theme.dart';
import '../utils/post_slug.dart';
import '../widgets/publication_chrome.dart';

/// Trang chủ theo hướng ấn phẩm cá nhân: bài viết là nội dung trung tâm,
/// không dùng hero marketing hay lưới card kiểu portfolio.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialSection});

  final String? initialSection;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scrollController = ScrollController();
  final _writingKey = GlobalKey();
  final _notesKey = GlobalKey();
  final _aboutKey = GlobalKey();
  bool _initialScrollScheduled = false;

  late final Stream<List<Post>> _posts = PostService().watchPosts();
  late final Stream<List<PostCategory>> _categories = CategoryService()
      .watchCategories();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.04,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: PublicationHeader(
                onWriting: () => _goTo(_writingKey),
                onNotes: () => _goTo(_notesKey),
                onAbout: () => _goTo(_aboutKey),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1060),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Introduction(),
                        StreamBuilder<List<PostCategory>>(
                          stream: _categories,
                          builder: (context, categorySnapshot) {
                            final categories =
                                (categorySnapshot.data ?? const [])
                                    .where((category) => category.visible)
                                    .toList(growable: false);
                            return StreamBuilder<List<Post>>(
                              stream: _posts,
                              builder: (context, postSnapshot) {
                                if (postSnapshot.hasError) {
                                  return _InlineMessage(
                                    key: _writingKey,
                                    text:
                                        'Không thể tải bài viết lúc này. Vui lòng thử lại sau.',
                                  );
                                }
                                if (!postSnapshot.hasData) {
                                  return _LoadingPublication(key: _writingKey);
                                }
                                _scheduleInitialScroll();
                                final posts = postSnapshot.data!
                                    .where((post) => post.published)
                                    .toList(growable: false);
                                return _PublicationBody(
                                  writingKey: _writingKey,
                                  notesKey: _notesKey,
                                  aboutKey: _aboutKey,
                                  posts: posts,
                                  categories: categories,
                                );
                              },
                            );
                          },
                        ),
                        const PublicationFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleInitialScroll() {
    if (_initialScrollScheduled || widget.initialSection == null) return;
    _initialScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (widget.initialSection) {
        case 'notes':
          _goTo(_notesKey);
        case 'about':
          _goTo(_aboutKey);
      }
    });
  }
}

class _Introduction extends StatelessWidget {
  const _Introduction();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 82, bottom: 104),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'XIN CHÀO, MÌNH LÀ MINH HIẾU.',
              style: TextStyle(
                fontFamily: AppTheme.monoFont,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ghi chép về công nghệ, những thứ đang xây dựng và các bài học đáng giữ lại.',
              style: TextStyle(
                fontFamily: AppTheme.serifFont,
                fontSize: MediaQuery.sizeOf(context).width < 640 ? 40 : 58,
                height: 1.08,
                letterSpacing: -1.4,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 590),
              child: Text(
                'Đây là nơi mình viết chậm hơn, nghĩ kỹ hơn và ghi lại quá trình làm sản phẩm — cả những điều đã rõ lẫn những câu hỏi còn mở.',
                style: TextStyle(
                  fontFamily: AppTheme.serifFont,
                  fontSize: 19,
                  height: 1.65,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicationBody extends StatelessWidget {
  const _PublicationBody({
    required this.writingKey,
    required this.notesKey,
    required this.aboutKey,
    required this.posts,
    required this.categories,
  });

  final GlobalKey writingKey;
  final GlobalKey notesKey;
  final GlobalKey aboutKey;
  final List<Post> posts;
  final List<PostCategory> categories;

  @override
  Widget build(BuildContext context) {
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final featured = posts.isEmpty ? null : posts.first;
    final latest = posts.length <= 1
        ? const <Post>[]
        : posts.skip(1).take(6).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          key: writingKey,
          number: '01',
          label: 'Bài viết nổi bật',
        ),
        const SizedBox(height: 28),
        if (featured == null)
          const _EmptyWriting()
        else
          _FeaturedArticle(
            post: featured,
            category: categoryById[featured.categoryId],
          ),
        const SizedBox(height: 92),
        _SectionHeading(
          number: '02',
          label: 'Bài viết mới',
          trailing: posts.length > 7
              ? _EditorialLink(
                  label: 'Xem tất cả',
                  onTap: () => context.go('/posts'),
                )
              : null,
        ),
        const SizedBox(height: 18),
        if (latest.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              posts.isEmpty
                  ? 'Chưa có bài viết được xuất bản.'
                  : 'Bài viết tiếp theo đang được viết.',
              style: _serifBody(context, muted: true),
            ),
          )
        else
          for (final post in latest)
            _WritingRow(post: post, category: categoryById[post.categoryId]),
        const SizedBox(height: 100),
        _SectionHeading(key: notesKey, number: '03', label: 'Dự án & ghi chú'),
        const SizedBox(height: 18),
        const _ProjectRow(),
        for (final category in categories.take(4))
          _NoteRow(
            category: category,
            count: posts.where((post) => post.categoryId == category.id).length,
          ),
        const SizedBox(height: 104),
        _AboutSection(key: aboutKey),
        const SizedBox(height: 104),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    super.key,
    required this.number,
    required this.label,
    this.trailing,
  });

  final String number;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          number,
          style: TextStyle(
            fontFamily: AppTheme.monoFont,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.serifFont,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: colors.onSurface,
            ),
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _FeaturedArticle extends StatelessWidget {
  const _FeaturedArticle({required this.post, this.category});

  final Post post;
  final PostCategory? category;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final path = postDetailPath(id: post.id, title: post.title);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(path),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 30),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: colors.outlineVariant),
              bottom: BorderSide(color: colors.outlineVariant),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final text = _FeaturedCopy(post: post, category: category);
              final image = post.coverUrl.isEmpty
                  ? null
                  : _EditorialImage(url: post.coverUrl);
              if (!wide || image == null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (image != null) ...[image, const SizedBox(height: 28)],
                    text,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: text),
                  const SizedBox(width: 56),
                  Expanded(flex: 5, child: image),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FeaturedCopy extends StatelessWidget {
  const _FeaturedCopy({required this.post, this.category});

  final Post post;
  final PostCategory? category;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetadataLine(post: post, category: category),
        const SizedBox(height: 20),
        Text(
          post.title.trim().isEmpty ? '(Chưa có tiêu đề)' : post.title,
          style: TextStyle(
            fontFamily: AppTheme.serifFont,
            fontSize: MediaQuery.sizeOf(context).width < 640 ? 34 : 43,
            height: 1.12,
            letterSpacing: -0.8,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
        if (post.snippet.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            post.snippet,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: _serifBody(context, muted: true),
          ),
        ],
        const SizedBox(height: 26),
        Text(
          'Đọc bài viết  →',
          style: TextStyle(
            fontFamily: AppTheme.monoFont,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: colors.primary,
          ),
        ),
      ],
    );
  }
}

class _EditorialImage extends StatelessWidget {
  const _EditorialImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : ColoredBox(color: colors.surfaceContainerLow),
          errorBuilder: (context, error, stackTrace) => ColoredBox(
            color: colors.surfaceContainerLow,
            child: Center(
              child: Text(
                'Không tải được ảnh',
                style: TextStyle(
                  fontFamily: AppTheme.monoFont,
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WritingRow extends StatelessWidget {
  const _WritingRow({required this.post, this.category});

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
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final title = Text(
                post.title.trim().isEmpty ? '(Chưa có tiêu đề)' : post.title,
                style: TextStyle(
                  fontFamily: AppTheme.serifFont,
                  fontSize: 22,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              );
              if (constraints.maxWidth < 680) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 10),
                    _MetadataLine(post: post, category: category),
                  ],
                );
              }
              return Row(
                children: [
                  SizedBox(
                    width: 116,
                    child: Text(
                      _formatDate(post.timeCreated ?? post.timeUpdated),
                      style: _metadataStyle(context),
                    ),
                  ),
                  Expanded(child: title),
                  const SizedBox(width: 28),
                  SizedBox(
                    width: 150,
                    child: Text(
                      category?.name ?? '${_readingMinutes(post)} phút đọc',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: _metadataStyle(context),
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

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.post, this.category});

  final Post post;
  final PostCategory? category;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (category != null && category!.name.isNotEmpty) category!.name,
      _formatDate(post.timeCreated ?? post.timeUpdated),
      '${_readingMinutes(post)} phút đọc',
    ].where((part) => part.isNotEmpty).toList(growable: false);
    return Text(parts.join('  ·  '), style: _metadataStyle(context));
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow();

  @override
  Widget build(BuildContext context) {
    return _IndexRow(
      eyebrow: 'DỰ ÁN · 2026',
      title: 'Graduation 2026',
      description:
          'Một không gian riêng cho lời mời, lịch trình và những khoảnh khắc của cột mốc tốt nghiệp.',
      onTap: () => context.go('/countdown'),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.category, required this.count});

  final PostCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    return _IndexRow(
      eyebrow: 'GHI CHÚ · $count BÀI',
      title: category.name,
      description: category.description.isEmpty
          ? 'Các bài viết và ghi chép được lưu theo chủ đề này.'
          : category.description,
      onTap: () => context.go('/categories/${category.slug}'),
    );
  }
}

class _IndexRow extends StatelessWidget {
  const _IndexRow({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final label = Text(eyebrow, style: _metadataStyle(context));
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTheme.serifFont,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: AppTheme.serifFont,
                      fontSize: 16.5,
                      height: 1.55,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 680) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, const SizedBox(height: 12), copy],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 170, child: label),
                  Expanded(child: copy),
                  const SizedBox(width: 24),
                  Text('→', style: _metadataStyle(context)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.outlineVariant),
          bottom: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heading = Text(
            'Về mình',
            style: TextStyle(
              fontFamily: AppTheme.serifFont,
              fontSize: 31,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          );
          final body = Text(
            'Mình là Minh Hiếu. Mình làm sản phẩm số và viết để hiểu rõ hơn cách công nghệ, thiết kế và con người gặp nhau trong công việc hằng ngày.',
            style: TextStyle(
              fontFamily: AppTheme.serifFont,
              fontSize: 19,
              height: 1.7,
              color: colors.onSurfaceVariant,
            ),
          );
          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 18), body],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 260, child: heading),
              const SizedBox(width: 48),
              Expanded(child: body),
            ],
          );
        },
      ),
    );
  }
}

class _LoadingPublication extends StatelessWidget {
  const _LoadingPublication({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(number: '01', label: 'Bài viết nổi bật'),
          const SizedBox(height: 28),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              border: Border.symmetric(
                horizontal: BorderSide(color: colors.outlineVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 96),
      child: Text(text, style: _serifBody(context, muted: true)),
    );
  }
}

class _EmptyWriting extends StatelessWidget {
  const _EmptyWriting();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Text(
        'Bài viết đầu tiên đang được hoàn thiện.',
        style: _serifBody(context, muted: true),
      ),
    );
  }
}

class _EditorialLink extends StatelessWidget {
  const _EditorialLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '$label  →',
          style: TextStyle(
            fontFamily: AppTheme.monoFont,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.primary,
          ),
        ),
      ),
    );
  }
}

TextStyle _metadataStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return TextStyle(
    fontFamily: AppTheme.monoFont,
    fontSize: 12,
    height: 1.4,
    letterSpacing: 0.25,
    color: colors.onSurfaceVariant,
  );
}

TextStyle _serifBody(BuildContext context, {bool muted = false}) {
  final colors = Theme.of(context).colorScheme;
  return TextStyle(
    fontFamily: AppTheme.serifFont,
    fontSize: 18,
    height: 1.65,
    color: muted ? colors.onSurfaceVariant : colors.onSurface,
  );
}

String _formatDate(DateTime? value) {
  if (value == null) return '';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year}';
}

int _readingMinutes(Post post) {
  final words = post.blocks
      .where((block) => block.type.isText)
      .expand((block) => block.text.trim().split(RegExp(r'\s+')))
      .where((word) => word.isNotEmpty)
      .length;
  return (words / 220).ceil().clamp(1, 99);
}
