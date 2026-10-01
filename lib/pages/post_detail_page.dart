import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../models/post.dart';
import '../models/post_category.dart';
import '../services/category_service.dart';
import '../services/post_service.dart';
import '../theme.dart';
import '../theme/post_styles.dart';
import '../widgets/publication_chrome.dart';

/// Trang đọc tập trung: cột nội dung 720px, tiến độ đọc và mục lục cố định
/// bên phải trên desktop.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late final Stream<Post?> _stream = PostService().watchPost(widget.postId);
  late final Stream<List<PostCategory>> _categories = CategoryService()
      .watchCategories();
  final _scrollController = ScrollController();
  final _progress = ValueNotifier<double>(0);
  final Map<int, GlobalKey> _headingKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateProgress);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateProgress)
      ..dispose();
    _progress.dispose();
    super.dispose();
  }

  void _updateProgress() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final value = max <= 0 ? 0.0 : _scrollController.offset / max;
    _progress.value = value.clamp(0.0, 1.0);
  }

  GlobalKey _headingKey(int index) =>
      _headingKeys.putIfAbsent(index, GlobalKey.new);

  Future<void> _scrollToHeading(int index) async {
    final target = _headingKey(index).currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _progress,
              builder: (context, value, child) => SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.transparent,
                  color: colors.primary,
                ),
              ),
            ),
            const PublicationHeader(),
            Expanded(
              child: StreamBuilder<Post?>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const _MessageState(
                      text:
                          'Không thể tải bài viết lúc này.\nVui lòng thử lại sau.',
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final post = snapshot.data;
                  if (post == null ||
                      (!post.published && !authController.isLoggedIn)) {
                    return const _MessageState(
                      text: 'Bài viết không tồn tại hoặc đã được gỡ.',
                    );
                  }
                  return _articleLayout(post);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _articleLayout(Post post) {
    final headings = <({int index, PostBlock block})>[
      for (var index = 0; index < post.blocks.length; index++)
        if (post.blocks[index].type == PostBlockType.heading ||
            post.blocks[index].type == PostBlockType.subheading)
          (index: index, block: post.blocks[index]),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1060 && headings.isNotEmpty;
        if (!desktop) return _articleList(post, desktop: false);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _articleList(post, desktop: true)),
                const SizedBox(width: 34),
                SizedBox(
                  width: 230,
                  child: _TableOfContents(
                    headings: headings,
                    onSelected: _scrollToHeading,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _articleList(Post post, {required bool desktop}) {
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(desktop ? 24 : 20, 64, 20, 72),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ArticleHeader(post: post, categories: _categories),
                const SizedBox(height: 50),
                for (var index = 0; index < post.blocks.length; index++)
                  _blockView(post.blocks[index], index),
                const SizedBox(height: 70),
                const _ArticleEnd(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _blockView(PostBlock block, int index) {
    if (block.type == PostBlockType.image) return _imageView(block);

    final text = block.text.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    if (block.type == PostBlockType.code || _looksLikeFencedCode(text)) {
      return _CodeBlock(code: _stripCodeFence(text));
    }

    final colors = Theme.of(context).colorScheme;
    final style = postBlockTextStyle(context, block.type);
    Widget content = SelectableText(text, style: style);

    if (block.type == PostBlockType.quote) {
      content = Container(
        padding: const EdgeInsets.only(left: 22),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.primary, width: 2)),
        ),
        child: content,
      );
    }

    if (block.highlight.isNotEmpty) {
      content = Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 17),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.065),
          border: Border(left: BorderSide(color: colors.primary, width: 2)),
        ),
        child: content,
      );
    }

    final margin = switch (block.type) {
      PostBlockType.heading => const EdgeInsets.only(top: 48, bottom: 10),
      PostBlockType.subheading => const EdgeInsets.only(top: 34, bottom: 8),
      PostBlockType.quote => const EdgeInsets.symmetric(vertical: 25),
      _ => const EdgeInsets.symmetric(vertical: 8),
    };

    final keyed =
        block.type == PostBlockType.heading ||
            block.type == PostBlockType.subheading
        ? KeyedSubtree(key: _headingKey(index), child: content)
        : content;
    return Padding(padding: margin, child: keyed);
  }

  Widget _imageView(PostBlock block) {
    if (block.url.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Semantics(
        button: true,
        label: 'Mở ảnh ở chế độ toàn màn hình',
        child: GestureDetector(
          onTap: () => _openFullScreen(block.url),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Image.network(
              block.url,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : SizedBox(
                      height: 260,
                      child: ColoredBox(
                        color: colors.surfaceContainerLow,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
              errorBuilder: (context, error, stack) => SizedBox(
                height: 160,
                child: ColoredBox(
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
          ),
        ),
      ),
    );
  }

  void _openFullScreen(String url) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Đóng ảnh',
      barrierColor: const Color(0xF20B0C0E),
      pageBuilder: (ctx, _, _) => Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                      errorBuilder: (context, error, stack) => const Center(
                        child: Text(
                          'Không tải được ảnh',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleHeader extends StatelessWidget {
  const _ArticleHeader({required this.post, required this.categories});

  final Post post;
  final Stream<List<PostCategory>> categories;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = _formatDate(post.timeCreated ?? post.timeUpdated);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.go('/posts'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '←  TẤT CẢ BÀI VIẾT',
              style: TextStyle(
                fontFamily: AppTheme.monoFont,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: colors.primary,
              ),
            ),
          ),
        ),
        if (!post.published) ...[
          const SizedBox(height: 24),
          Text(
            'BẢN NHÁP · CHỈ ADMIN NHÌN THẤY',
            style: TextStyle(
              fontFamily: AppTheme.monoFont,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
        ],
        const SizedBox(height: 34),
        Text(
          post.title.trim().isEmpty ? '(Chưa có tiêu đề)' : post.title,
          style: TextStyle(
            fontFamily: AppTheme.serifFont,
            fontSize: MediaQuery.sizeOf(context).width < 680 ? 39 : 54,
            height: 1.08,
            letterSpacing: -1.15,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (post.categoryId.isNotEmpty)
              StreamBuilder<List<PostCategory>>(
                stream: categories,
                builder: (context, snapshot) {
                  final matching = (snapshot.data ?? const <PostCategory>[])
                      .where(
                        (category) =>
                            category.id == post.categoryId && category.visible,
                      );
                  if (matching.isEmpty) return const SizedBox.shrink();
                  final category = matching.first;
                  return InkWell(
                    onTap: () => context.go('/categories/${category.slug}'),
                    child: Text(
                      category.name.toUpperCase(),
                      style: _metaStyle(context, accent: true),
                    ),
                  );
                },
              ),
            if (date.isNotEmpty) Text(date, style: _metaStyle(context)),
            Text(
              '${_readingMinutes(post)} PHÚT ĐỌC',
              style: _metaStyle(context),
            ),
          ],
        ),
        const SizedBox(height: 36),
        Divider(height: 1, color: colors.outlineVariant),
      ],
    );
  }
}

class _TableOfContents extends StatelessWidget {
  const _TableOfContents({required this.headings, required this.onSelected});

  final List<({int index, PostBlock block})> headings;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 82, 0, 40),
      child: Container(
        padding: const EdgeInsets.only(left: 18),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.outlineVariant)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRONG BÀI VIẾT',
              style: TextStyle(
                fontFamily: AppTheme.monoFont,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.75,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 18),
            for (final heading in headings)
              InkWell(
                onTap: () => onSelected(heading.index),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    heading.block.type == PostBlockType.subheading ? 12 : 0,
                    7,
                    0,
                    7,
                  ),
                  child: Text(
                    heading.block.text.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.serifFont,
                      fontSize: heading.block.type == PostBlockType.heading
                          ? 15.5
                          : 14.5,
                      height: 1.35,
                      fontWeight: heading.block.type == PostBlockType.heading
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: heading.block.type == PostBlockType.heading
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lines = code.split('\n');
    final digits = lines.length.toString().length;
    final numbers = [
      for (var index = 0; index < lines.length; index++)
        (index + 1).toString().padLeft(digits),
    ].join('\n');
    const codeColor = Color(0xFFE9EAF0);
    const gutterColor = Color(0xFF777B87);
    const codeBackground = Color(0xFF17191E);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: codeBackground,
        border: Border(
          top: BorderSide(color: colors.primary, width: 2),
          left: const BorderSide(color: Color(0xFF30333B)),
          right: const BorderSide(color: Color(0xFF30333B)),
          bottom: const BorderSide(color: Color(0xFF30333B)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, 10),
            child: Text(
              'CODE',
              style: TextStyle(
                fontFamily: AppTheme.monoFont,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: gutterColor,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF30333B)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 17, 24, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  numbers,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: AppTheme.monoFont,
                    fontSize: 14,
                    height: 1.7,
                    color: gutterColor,
                  ),
                ),
                const SizedBox(width: 18),
                Container(
                  padding: const EdgeInsets.only(left: 18),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: Color(0xFF30333B))),
                  ),
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      fontFamily: AppTheme.monoFont,
                      fontSize: 14,
                      height: 1.7,
                      color: codeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleEnd extends StatelessWidget {
  const _ArticleEnd();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(top: 28),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Text('CẢM ƠN BẠN ĐÃ ĐỌC.', style: _metaStyle(context, accent: true)),
          const Spacer(),
          InkWell(
            onTap: () => context.go('/posts'),
            child: Text('BÀI VIẾT KHÁC  →', style: _metaStyle(context)),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.text});

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

bool _looksLikeFencedCode(String text) =>
    text.startsWith('```') && text.endsWith('```');

String _stripCodeFence(String text) {
  if (!_looksLikeFencedCode(text)) return text;
  final withoutStart = text.substring(3);
  final firstBreak = withoutStart.indexOf('\n');
  final body = firstBreak == -1
      ? withoutStart
      : withoutStart.substring(firstBreak + 1);
  return body.substring(0, body.length - 3).trimRight();
}
