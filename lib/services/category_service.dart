import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post_category.dart';
import '../utils/post_slug.dart';

/// Truy cập collection `categories` của blog.
class CategoryService {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('categories');

  /// Lấy toàn bộ danh mục rồi sắp xếp phía client để dữ liệu cũ thiếu
  /// `sort_order` vẫn xuất hiện và không cần thêm Firestore index.
  Stream<List<PostCategory>> watchCategories() {
    return _col.snapshots().map((snapshot) {
      final categories = [
        for (final doc in snapshot.docs) PostCategory.fromFirestore(doc),
      ];
      categories.sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return categories;
    });
  }

  Future<String> createCategory({
    required String name,
    String description = '',
    bool visible = true,
    int sortOrder = 0,
  }) async {
    final normalizedName = name.trim();
    final slug = postSlug(normalizedName);
    if (normalizedName.isEmpty) {
      throw ArgumentError('Tên danh mục không được để trống.');
    }
    if (slug.isEmpty) {
      throw ArgumentError('Tên danh mục phải có ít nhất một chữ hoặc số.');
    }

    final ref = _col.doc(slug);
    if ((await ref.get()).exists) {
      throw StateError('Đã có danh mục với đường dẫn "$slug".');
    }

    final category = PostCategory(
      id: slug,
      name: normalizedName,
      description: description,
      visible: visible,
      sortOrder: sortOrder,
    );
    await ref.set({
      ...category.toFirestore(),
      'time_created': FieldValue.serverTimestamp(),
      'time_updated': FieldValue.serverTimestamp(),
    });
    return slug;
  }

  Future<void> updateCategory(PostCategory category) {
    return _col.doc(category.id).update({
      ...category.toFirestore(),
      'time_updated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setVisible(String id, bool visible) {
    return _col.doc(id).update({
      'visible': visible,
      'time_updated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCategory(String id) => _col.doc(id).delete();
}
