import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../theme/post_styles.dart';
import '../theme/row_palette.dart';
import '../widgets/theme_toggle_button.dart';

/// Trang ĐỌC 1 bài viết: hiển thị tiêu đề + các khối theo đúng thứ tự.
///
/// - Đề mục: chữ to in đậm; Đề mục phụ: chữ vừa in đậm.
/// - Đoạn văn: chữ thường, giãn dòng ~1.6 cho dễ đọc.
/// - Trích dẫn: viền trái + in nghiêng.
/// - Ảnh: bo góc, chạm để xem lớn (phóng to được).
/// - Khối văn bản có `highlight`: tô màu nền (RowPalette — hợp Sáng lẫn Tối).
///
/// Bản nháp chỉ admin xem được; khách mở link bản nháp sẽ thấy "không tồn tại".
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late final Stream<Post?> _stream = PostService().watchPost(widget.postId);

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/posts');
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
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<Post?>(
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final post = snapshot.data;
          // Bài không tồn tại, hoặc là bản nháp mà người xem không phải admin.
          if (post == null ||
              (!post.published && !authController.isLoggedIn)) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bài viết không tồn tại hoặc đã bị gỡ.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _content(post);
        },
      ),
    );
  }

  Widget _content(Post post) {
    final colorScheme = Theme.of(context).colorScheme;

    // Cột nội dung hẹp (~720px) như trang blog, hợp cả điện thoại.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          children: [
            // Nhãn bản nháp — chỉ admin mở tới được nhánh này.
            if (!post.published)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Bản nháp — chỉ admin nhìn thấy',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(post.timeCreated ?? post.timeUpdated),
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final block in post.blocks) _blockView(block),
          ],
        ),
      ),
    );
  }

  /// Render 1 khối theo loại của nó.
  Widget _blockView(PostBlock block) {
    if (block.type == PostBlockType.image) return _imageView(block);

    final text = block.text.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final style = postBlockTextStyle(context, block.type);

    // Trích dẫn: viền trái + in nghiêng (style đã nghiêng sẵn).
    Widget content = block.type == PostBlockType.quote
        ? Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: colorScheme.primary, width: 4),
              ),
            ),
            padding: const EdgeInsets.only(left: 14),
            child: Text(text, style: style),
          )
        : Text(text, style: style);

    // Khoảng cách dọc theo loại: đề mục tách rõ khỏi phần trước.
    final margin = switch (block.type) {
      PostBlockType.heading => const EdgeInsets.only(top: 18, bottom: 6),
      PostBlockType.subheading => const EdgeInsets.only(top: 14, bottom: 4),
      PostBlockType.quote => const EdgeInsets.symmetric(vertical: 10),
      _ => const EdgeInsets.symmetric(vertical: 6),
    };

    // Tô màu nền nếu khối có highlight (cùng logic màu với trình soạn).
    final highlightBg =
        RowPalette.backgroundFor(block.highlight, Theme.of(context).brightness);
    if (highlightBg != null) {
      content = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: highlightBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: content,
      );
    }

    return Padding(padding: margin, child: content);
  }

  Widget _imageView(PostBlock block) {
    if (block.url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: GestureDetector(
        onTap: () => _openFullScreen(block.url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            block.url,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (context, error, stack) => const SizedBox(
              height: 120,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      ),
    );
  }

  /// Xem ảnh lớn toàn màn hình: chụm/lăn để phóng to, chạm nền hoặc nút X
  /// để đóng.
  void _openFullScreen(String url) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Đóng',
      barrierColor: Colors.black,
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
                                      color: Colors.white),
                                ),
                      errorBuilder: (context, error, stack) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.white),
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
