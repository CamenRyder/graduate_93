import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post.dart';

/// Lớp truy cập Firestore cho collection `posts` (bài viết).
///
/// File ảnh của bài viết nằm ở Supabase Storage (prefix `posts/`, xem
/// StorageService.uploadPostImage); Firestore chỉ lưu nội dung + link ảnh.
/// Rules sẵn có (catch-all) đã cho: đọc công khai, ghi chỉ admin — nên
/// KHÔNG cần sửa firestore.rules.
class PostService {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('posts');

  /// Lắng nghe danh sách bài viết theo thời gian thực, bài mới nhất lên đầu.
  ///
  /// LƯU Ý: trả về CẢ bản nháp — UI tự lọc theo `published` cho khách.
  /// (Cố tình không `where('published')` + `orderBy` cùng lúc để khỏi phải
  /// tạo composite index trên Firestore.)
  Stream<List<Post>> watchPosts() {
    return _col.orderBy('time_created', descending: true).snapshots().map(
          (snap) => [for (final doc in snap.docs) Post.fromFirestore(doc)],
        );
  }

  /// Lắng nghe 1 bài viết theo id; phát `null` nếu bài không tồn tại/đã xóa.
  Stream<Post?> watchPost(String id) {
    return _col
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? Post.fromFirestore(doc) : null);
  }

  /// Đọc 1 bài viết (1 lần) — dùng khi mở trình soạn để sửa bài.
  Future<Post?> getPost(String id) async {
    final doc = await _col.doc(id).get();
    return doc.exists ? Post.fromFirestore(doc) : null;
  }

  /// Tạo bài viết mới; `time_created`/`time_updated` theo giờ server.
  /// Trả về document id vừa tạo.
  Future<String> createPost(Post post) async {
    final data = post.toFirestore()
      ..['time_created'] = FieldValue.serverTimestamp()
      ..['time_updated'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    return ref.id;
  }

  /// Cập nhật bài viết đã có (giữ nguyên `time_created`).
  Future<void> updatePost(Post post) {
    final data = post.toFirestore()
      ..['time_updated'] = FieldValue.serverTimestamp();
    return _col.doc(post.id).update(data);
  }

  /// Bật/tắt trạng thái "Đăng" (published) — ghi thẳng, không đụng nội dung.
  Future<void> setPublished(String id, bool published) {
    return _col.doc(id).update({
      'published': published,
      'time_updated': FieldValue.serverTimestamp(),
    });
  }

  /// Xóa bài viết. Ảnh trong bài (Supabase Storage) xóa riêng qua
  /// StorageService.deletePostImages — xem nơi gọi.
  Future<void> deletePost(String id) => _col.doc(id).delete();
}
