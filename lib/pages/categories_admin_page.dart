import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../models/post_category.dart';
import '../services/category_service.dart';
import '../services/post_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/theme_toggle_button.dart';

/// Màn quản lý danh mục bài viết dành cho admin.
class CategoriesAdminPage extends StatefulWidget {
  const CategoriesAdminPage({super.key});

  @override
  State<CategoriesAdminPage> createState() => _CategoriesAdminPageState();
}

class _CategoriesAdminPageState extends State<CategoriesAdminPage> {
  final _categoryService = CategoryService();
  final _postService = PostService();
  final _busyIds = <String>{};

  late final Stream<List<PostCategory>> _categoriesStream = _categoryService
      .watchCategories();
  late final Stream<List<Post>> _postsStream = _postService.watchPosts();

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

  Future<void> _openEditor([PostCategory? category]) async {
    final draft = await showDialog<_CategoryDraft>(
      context: context,
      builder: (_) => _CategoryEditorDialog(category: category),
    );
    if (draft == null || !mounted) return;

    final busyId = category?.id ?? '__new__';
    setState(() => _busyIds.add(busyId));
    try {
      if (category == null) {
        await _categoryService.createCategory(
          name: draft.name,
          description: draft.description,
          visible: draft.visible,
          sortOrder: draft.sortOrder,
        );
        if (!mounted) return;
        _showToast('Đã tạo danh mục "${draft.name}"');
      } else {
        await _categoryService.updateCategory(
          PostCategory(
            id: category.id,
            name: draft.name,
            description: draft.description,
            visible: draft.visible,
            sortOrder: draft.sortOrder,
            timeCreated: category.timeCreated,
            timeUpdated: category.timeUpdated,
          ),
        );
        if (!mounted) return;
        _showToast('Đã cập nhật danh mục');
      }
    } catch (error) {
      if (!mounted) return;
      _showToast('Không thể lưu danh mục: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(busyId));
    }
  }

  Future<void> _toggleVisible(PostCategory category, bool visible) async {
    setState(() => _busyIds.add(category.id));
    try {
      await _categoryService.setVisible(category.id, visible);
      if (!mounted) return;
      _showToast(visible ? 'Đã hiện danh mục' : 'Đã ẩn danh mục');
    } catch (error) {
      if (!mounted) return;
      _showToast('Không thể đổi trạng thái: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(category.id));
    }
  }

  Future<void> _delete(PostCategory category, int postCount) async {
    if (postCount > 0) {
      _showToast(
        'Danh mục đang có $postCount bài viết. Hãy chuyển các bài sang danh '
        'mục khác trước khi xóa.',
        isError: true,
      );
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Xóa danh mục?',
      message: 'Danh mục "${category.name}" sẽ bị xóa vĩnh viễn.',
      confirmLabel: 'Xóa',
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyIds.add(category.id));
    try {
      // Kiểm tra lại trên server để tránh xóa nhầm nếu vừa có bài mới.
      if (await _postService.hasPostsInCategory(category.id)) {
        if (!mounted) return;
        _showToast(
          'Danh mục vừa được gán cho một bài viết nên không thể xóa.',
          isError: true,
        );
        return;
      }
      await _categoryService.deleteCategory(category.id);
      if (!mounted) return;
      _showToast('Đã xóa danh mục');
    } catch (error) {
      if (!mounted) return;
      _showToast('Không thể xóa danh mục: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(category.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục bài viết'),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busyIds.contains('__new__') ? null : _openEditor,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Thêm danh mục'),
      ),
      body: StreamBuilder<List<PostCategory>>(
        stream: _categoriesStream,
        builder: (context, categorySnapshot) {
          if (categorySnapshot.hasError) {
            return _ErrorMessage(
              message: 'Không tải được danh mục:\n${categorySnapshot.error}',
            );
          }
          if (!categorySnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<List<Post>>(
            stream: _postsStream,
            builder: (context, postSnapshot) {
              if (postSnapshot.hasError) {
                return _ErrorMessage(
                  message: 'Không tải được bài viết:\n${postSnapshot.error}',
                );
              }
              if (!postSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final categories = categorySnapshot.data!;
              final posts = postSnapshot.data!;
              if (categories.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Chưa có danh mục nào. Bấm “Thêm danh mục” để bắt đầu.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final postCount = posts
                          .where((post) => post.categoryId == category.id)
                          .length;
                      return _categoryCard(category, postCount);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _categoryCard(PostCategory category, int postCount) {
    final colors = Theme.of(context).colorScheme;
    final busy = _busyIds.contains(category.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('$postCount bài'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '/categories/${category.slug} · Thứ tự ${category.sortOrder}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (category.description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      category.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: category.visible,
              onChanged: busy
                  ? null
                  : (value) => _toggleVisible(category, value),
            ),
            IconButton(
              tooltip: 'Sửa danh mục',
              icon: const Icon(Icons.edit_outlined),
              onPressed: busy ? null : () => _openEditor(category),
            ),
            busy
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Xóa danh mục',
                    color: colors.error,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(category, postCount),
                  ),
          ],
        ),
      ),
    );
  }
}

class _CategoryDraft {
  const _CategoryDraft({
    required this.name,
    required this.description,
    required this.visible,
    required this.sortOrder,
  });

  final String name;
  final String description;
  final bool visible;
  final int sortOrder;
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({this.category});

  final PostCategory? category;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _orderController;
  late bool _visible;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _descriptionController = TextEditingController(
      text: category?.description ?? '',
    );
    _orderController = TextEditingController(
      text: (category?.sortOrder ?? 0).toString(),
    );
    _visible = category?.visible ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _CategoryDraft(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        visible: _visible,
        sortOrder: int.parse(_orderController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.category != null;
    return AlertDialog(
      title: Text(editing ? 'Sửa danh mục' : 'Thêm danh mục'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Tên danh mục'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập tên danh mục'
                      : null,
                ),
                if (editing) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Đường dẫn: /categories/${widget.category!.slug}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả (không bắt buộc)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _orderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Thứ tự hiển thị',
                  ),
                  validator: (value) =>
                      int.tryParse(value?.trim() ?? '') == null
                      ? 'Thứ tự phải là số nguyên'
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hiển thị công khai'),
                  value: _visible,
                  onChanged: (value) => setState(() => _visible = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Lưu')),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
