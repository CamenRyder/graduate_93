import 'package:cloud_firestore/cloud_firestore.dart';

/// Danh mục chính của bài viết.
///
/// Document id được dùng làm slug ổn định (ví dụ `cong-nghe`) để vừa liên kết
/// từ `posts.category_id`, vừa tạo URL `/categories/cong-nghe`.
class PostCategory {
  const PostCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.visible = true,
    this.sortOrder = 0,
    this.timeCreated,
    this.timeUpdated,
  });

  final String id;
  final String name;
  final String description;
  final bool visible;
  final int sortOrder;
  final DateTime? timeCreated;
  final DateTime? timeUpdated;

  String get slug => id;

  factory PostCategory.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PostCategory.fromMap(id: doc.id, data: data);
  }

  factory PostCategory.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return PostCategory(
      id: id,
      name: data['name']?.toString().trim() ?? '',
      description: data['description']?.toString().trim() ?? '',
      visible: data['visible'] as bool? ?? true,
      sortOrder: (data['sort_order'] as num?)?.toInt() ?? 0,
      timeCreated: (data['time_created'] as Timestamp?)?.toDate(),
      timeUpdated: (data['time_updated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name.trim(),
    'description': description.trim(),
    'visible': visible,
    'sort_order': sortOrder,
  };
}
