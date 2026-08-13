import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/theme_toggle_button.dart';

/// Trang tổng quan mặc định của admin, tập trung vào công việc viết blog.
class BlogAdminDashboard extends StatefulWidget {
  const BlogAdminDashboard({super.key, this.postsStream});

  /// Cho phép bơm dữ liệu giả khi kiểm thử UI; production dùng Firestore.
  final Stream<List<Post>>? postsStream;

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
            icon: const Icon(Icons.open_in_new),
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
  });

  final List<Post> posts;
  final bool loading;
  final String? error;

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
                  const _WelcomePanel(),
                  const SizedBox(height: 18),
                  if (loading) const LinearProgressIndicator(minHeight: 3),
                  if (error != null) ...[
                    _DashboardError(message: error!),
                    const SizedBox(height: 18),
                  ],
                  _StatsGrid(
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

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer,
            colors.tertiaryContainer.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 20,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KHÔNG GIAN VIẾT CỦA BẠN',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Kể câu chuyện mới, theo cách của riêng bạn.',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Viết, hoàn thiện bản nháp và xuất bản mọi thứ từ một nơi.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onPrimaryContainer.withValues(alpha: 0.78),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => context.push('/admin/posts/edit'),
            icon: const Icon(Icons.edit_note),
            label: const Text('Viết bài mới'),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
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
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final stats = [
          _StatData('Tổng bài viết', '$total', Icons.article_outlined),
          _StatData('Đã xuất bản', '$published', Icons.public_outlined),
          _StatData('Bản nháp', '$drafts', Icons.drafts_outlined),
          _StatData('Ảnh trong bài', '$images', Icons.image_outlined),
        ];

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final stat in stats)
              SizedBox(
                width: width,
                child: _StatCard(data: stat),
              ),
          ],
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
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
    return _SectionCard(
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
                  if (index != posts.length - 1) const Divider(height: 1),
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/admin/posts/edit/${post.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
    return _SectionCard(
      title: 'Lối tắt',
      child: Column(
        children: [
          _ShortcutTile(
            icon: Icons.add_circle_outline,
            title: 'Viết bài mới',
            subtitle: 'Mở trình soạn thảo',
            onTap: () => context.push('/admin/posts/edit'),
          ),
          _ShortcutTile(
            icon: Icons.article_outlined,
            title: 'Quản lý bài viết',
            subtitle: 'Bản nháp và bài đã đăng',
            onTap: () => context.go('/admin/posts'),
          ),
          _ShortcutTile(
            icon: Icons.photo_library_outlined,
            title: 'Kho ảnh',
            subtitle: 'Quản lý tài nguyên hình ảnh',
            onTap: () => context.go('/gallery'),
          ),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
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
      onTap: onTap,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
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
