import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../services/storage_service.dart';
import '../supabase_config.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/theme_toggle_button.dart';

/// Trang tổng quan mặc định của admin, tập trung vào công việc viết blog.
class BlogAdminDashboard extends StatefulWidget {
  const BlogAdminDashboard({
    super.key,
    this.postsStream,
    this.galleryImagesFuture,
  });

  /// Cho phép bơm dữ liệu giả khi kiểm thử UI; production dùng Firestore.
  final Stream<List<Post>>? postsStream;

  /// Cho phép bơm kho ảnh giả khi kiểm thử; production đọc từ Supabase.
  final Future<List<GalleryImage>>? galleryImagesFuture;

  @override
  State<BlogAdminDashboard> createState() => _BlogAdminDashboardState();
}

class _BlogAdminDashboardState extends State<BlogAdminDashboard> {
  late final Stream<List<Post>> _postsStream =
      widget.postsStream ?? PostService().watchPosts();

  Future<void> _logout() async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Đăng xuất?',
      message: 'Bạn muốn đăng xuất khỏi trang quản trị blog?',
      confirmLabel: 'Đăng xuất',
      icon: Icons.logout,
    );
    if (confirm) await authController.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blog Studio'),
        actions: [
          IconButton(
            tooltip: 'Xem blog',
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () => context.go('/'),
          ),
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Post>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          return _DashboardContent(
            posts: snapshot.data ?? const <Post>[],
            loading: !snapshot.hasData && !snapshot.hasError,
            error: snapshot.hasError ? '${snapshot.error}' : null,
            galleryImagesFuture: widget.galleryImagesFuture,
          );
        },
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.posts,
    required this.loading,
    required this.error,
    this.galleryImagesFuture,
  });

  final List<Post> posts;
  final bool loading;
  final String? error;
  final Future<List<GalleryImage>>? galleryImagesFuture;

  @override
  Widget build(BuildContext context) {
    final published = posts.where((post) => post.published).length;
    final drafts = posts.length - published;
    final images = posts.fold<int>(
      0,
      (total, post) =>
          total + post.blocks.where((block) => !block.type.isText).length,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 720 ? 28.0 : 16.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GallerySlider(imagesFuture: galleryImagesFuture),
                  const SizedBox(height: 18),
                  if (loading) const LinearProgressIndicator(minHeight: 3),
                  if (error != null) ...[
                    _DashboardError(message: error!),
                    const SizedBox(height: 18),
                  ],
                  _StatsStrip(
                    total: posts.length,
                    published: published,
                    drafts: drafts,
                    images: images,
                  ),
                  const SizedBox(height: 18),
                  _Workspace(posts: posts),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GallerySlider extends StatefulWidget {
  const _GallerySlider({this.imagesFuture});

  final Future<List<GalleryImage>>? imagesFuture;

  @override
  State<_GallerySlider> createState() => _GallerySliderState();
}

class _GallerySliderState extends State<_GallerySlider> {
  static const int _initialPage = 5000;
  static const Duration _autoScrollInterval = Duration(seconds: 4);

  final PageController _pageController = PageController(
    initialPage: _initialPage,
  );

  List<GalleryImage>? _images;
  String? _error;
  Timer? _autoScrollTimer;
  int _currentPage = _initialPage;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void didUpdateWidget(covariant _GallerySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagesFuture != widget.imagesFuture) _loadImages();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    if (widget.imagesFuture == null && !SupabaseConfig.isConfigured) {
      _autoScrollTimer?.cancel();
      if (mounted) setState(() => _images = const <GalleryImage>[]);
      return;
    }

    _autoScrollTimer?.cancel();
    setState(() {
      _images = null;
      _error = null;
    });
    try {
      final allImages =
          await (widget.imagesFuture ?? StorageService().listImages());
      final randomized = allImages.toList()..shuffle();
      if (!mounted) return;
      setState(() {
        _currentPage = _initialPage;
        _images = randomized.take(15).toList(growable: false);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_initialPage);
        }
        _startAutoScroll();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if ((_images?.length ?? 0) < 2) return;
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      _moveToPage(_currentPage + 1);
    });
  }

  void _moveToPage(int page, {bool restartAutoScroll = false}) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
    );
    if (restartAutoScroll) _startAutoScroll();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final availableSliderWidth = compact
            ? constraints.maxWidth
            : constraints.maxWidth - 212;
        final previousHeight = (availableSliderWidth / (compact ? 1.35 : 2.1))
            .clamp(compact ? 220.0 : 300.0, compact ? 360.0 : 420.0);
        return SizedBox(
          width: double.infinity,
          height: previousHeight * 1.35,
          child: _buildSlider(),
        );
      },
    );
  }

  Widget _buildSlider() {
    final colors = Theme.of(context).colorScheme;
    if (_error != null) {
      return _GallerySliderMessage(
        icon: Icons.error_outline,
        message: 'Không tải được ảnh từ kho.',
        actionLabel: 'Thử lại',
        onAction: _loadImages,
      );
    }

    final images = _images;
    if (images == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (images.isEmpty) {
      return const _GallerySliderMessage(
        icon: Icons.photo_library_outlined,
        message: 'Kho ảnh chưa có hình để hiển thị.',
      );
    }

    final borderRadius = BorderRadius.circular(18);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: colors.primary),
          ColoredBox(color: Colors.black.withValues(alpha: 0.42)),
          PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => _currentPage = page,
            itemBuilder: (context, page) {
              final image = images[page % images.length];
              return GestureDetector(
                key: ValueKey('gallery-preview-$page-${image.fullPath}'),
                onTap: () => context.go('/gallery'),
                child: Image.network(
                  image.url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Center(
                          child: CircularProgressIndicator(
                            color: colors.onPrimary,
                          ),
                        ),
                  errorBuilder: (_, _, _) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: colors.onPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
          if (images.length > 1) ...[
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filled(
                  tooltip: 'Ảnh trước',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.48),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () =>
                      _moveToPage(_currentPage - 1, restartAutoScroll: true),
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filled(
                  tooltip: 'Ảnh tiếp theo',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.48),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () =>
                      _moveToPage(_currentPage + 1, restartAutoScroll: true),
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GallerySliderMessage extends StatelessWidget {
  const _GallerySliderMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(icon, color: colors.onSurfaceVariant),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.total,
    required this.published,
    required this.drafts,
    required this.images,
  });

  final int total;
  final int published;
  final int drafts;
  final int images;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stats = [
          _StatData('Tổng bài viết', '$total', Icons.article_outlined),
          _StatData('Đã xuất bản', '$published', Icons.public_outlined),
          _StatData('Bản nháp', '$drafts', Icons.drafts_outlined),
          _StatData('Ảnh trong bài', '$images', Icons.image_outlined),
        ];
        const dividerWidth = 1.0;
        final compact = constraints.maxWidth < 720;
        final itemWidth = compact
            ? 184.0
            : (constraints.maxWidth - dividerWidth * (stats.length - 1)) /
                  stats.length;

        return Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < stats.length; index++) ...[
                  SizedBox(
                    width: itemWidth,
                    child: _StatItem(data: stats[index]),
                  ),
                  if (index != stats.length - 1)
                    const SizedBox(
                      height: 58,
                      child: VerticalDivider(
                        width: dividerWidth,
                        thickness: dividerWidth,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatData {
  const _StatData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(data.icon, color: colors.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
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

class _Workspace extends StatelessWidget {
  const _Workspace({required this.posts});

  final List<Post> posts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final recent = _RecentPosts(posts: posts.take(5).toList());
        const shortcuts = _Shortcuts();
        if (constraints.maxWidth < 860) {
          return Column(
            children: [recent, const SizedBox(height: 18), shortcuts],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: recent),
            const SizedBox(width: 18),
            const Expanded(child: shortcuts),
          ],
        );
      },
    );
  }
}

class _RecentPosts extends StatelessWidget {
  const _RecentPosts({required this.posts});

  final List<Post> posts;

  String _formatDate(DateTime? value) {
    if (value == null) return 'Chưa có thời gian';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    return _DashboardSection(
      title: 'Bài viết gần đây',
      trailing: TextButton(
        onPressed: () => context.go('/admin/posts'),
        child: const Text('Xem tất cả'),
      ),
      child: posts.isEmpty
          ? const _EmptyPosts()
          : Column(
              children: [
                for (var index = 0; index < posts.length; index++) ...[
                  _PostRow(
                    post: posts[index],
                    date: _formatDate(
                      posts[index].timeUpdated ?? posts[index].timeCreated,
                    ),
                  ),
                  if (index != posts.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({required this.post, required this.date});

  final Post post;
  final String date;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _BorderedDashboardItem(
      onTap: () => context.push('/admin/posts/edit/${post.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: post.coverUrl.isEmpty
                  ? const Icon(Icons.notes_outlined)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        post.coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title.trim().isEmpty
                        ? '(Chưa có tiêu đề)'
                        : post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$date · ${post.published ? 'Đã đăng' : 'Bản nháp'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: post.published
                          ? colors.onSurfaceVariant
                          : colors.tertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _EmptyPosts extends StatelessWidget {
  const _EmptyPosts();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.edit_note, size: 42, color: colors.onSurfaceVariant),
          const SizedBox(height: 10),
          const Text('Chưa có bài viết nào.'),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.push('/admin/posts/edit'),
            child: const Text('Bắt đầu bài viết đầu tiên'),
          ),
        ],
      ),
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    return _DashboardSection(
      title: 'Lối tắt',
      child: Column(
        children: [
          _ShortcutTile(
            icon: Icons.add_circle_outline,
            title: 'Viết bài mới',
            subtitle: 'Mở trình soạn thảo',
            onTap: () => context.push('/admin/posts/edit'),
          ),
          const SizedBox(height: 10),
          _ShortcutTile(
            icon: Icons.article_outlined,
            title: 'Quản lý bài viết',
            subtitle: 'Bản nháp và bài đã đăng',
            onTap: () => context.go('/admin/posts'),
          ),
          const SizedBox(height: 10),
          _ShortcutTile(
            icon: Icons.photo_library_outlined,
            title: 'Kho ảnh',
            subtitle: 'Quản lý tài nguyên hình ảnh',
            onTap: () => context.go('/gallery'),
          ),
          const SizedBox(height: 10),
          _ShortcutTile(
            icon: Icons.public_outlined,
            title: 'Xem blog',
            subtitle: 'Mở trang dành cho người đọc',
            onTap: () => context.go('/'),
          ),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _BorderedDashboardItem(
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: colors.onSecondaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _BorderedDashboardItem extends StatelessWidget {
  const _BorderedDashboardItem({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(14);
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(borderRadius: borderRadius, onTap: onTap, child: child),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Không tải được dữ liệu bài viết:\n$message',
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
