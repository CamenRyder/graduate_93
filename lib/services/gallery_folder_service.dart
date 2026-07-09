import 'package:cloud_firestore/cloud_firestore.dart';

/// 1 thư mục ảnh trong kho ảnh (đọc từ Firestore).
class GalleryFolder {
  const GalleryFolder({
    required this.id,
    required this.name,
    this.timeCreated,
  });

  /// Id document trên Firestore — chính là giá trị lưu vào field `folder`
  /// của từng ảnh trong collection `gallery`.
  final String id;

  /// Tên thư mục do admin đặt (vd "Lễ tốt nghiệp", "Chụp với gia đình").
  final String name;

  /// Thời điểm tạo (server timestamp) — dùng để sắp xếp ổn định.
  final DateTime? timeCreated;
}

/// Quản lý danh sách THƯ MỤC của kho ảnh trên Firestore.
///
/// File ảnh vẫn nằm phẳng trong Supabase Storage, KHÔNG di chuyển/đổi tên;
/// "thư mục" chỉ là metadata: collection `gallery_folders` giữ danh sách
/// thư mục, còn mỗi ảnh thuộc thư mục nào lưu ở field `folder` trên document
/// của ảnh đó (collection `gallery` — xem [GalleryMetaService]). Nhờ vậy
/// tận dụng Firestore rules sẵn có (admin ghi, đọc công khai).
class GalleryFolderService {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('gallery_folders');

  /// Lắng nghe danh sách thư mục theo thời gian thực, cũ nhất lên đầu
  /// (thư mục tạo trước đứng trước cho ổn định, không nhảy vị trí).
  Stream<List<GalleryFolder>> watchFolders() {
    return _col.orderBy('time_created').snapshots().map((snap) {
      return snap.docs
          .map(
            (doc) => GalleryFolder(
              id: doc.id,
              name: doc.data()['name']?.toString() ?? '',
              timeCreated:
                  (doc.data()['time_created'] as Timestamp?)?.toDate(),
            ),
          )
          .toList();
    });
  }

  /// Tạo thư mục mới với [name]; trả về id document vừa tạo.
  Future<String> createFolder(String name) async {
    final ref = await _col.add({
      'name': name,
      'time_created': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Đổi tên thư mục [id] thành [name].
  Future<void> renameFolder(String id, String name) {
    return _col.doc(id).update({'name': name});
  }

  /// Xóa thư mục [id]. LƯU Ý: chỉ xóa document thư mục — việc gỡ field
  /// `folder` khỏi các ảnh bên trong do [GalleryMetaService.clearFolder]
  /// đảm nhiệm (ảnh quay về "Chưa phân loại", file KHÔNG bị xóa).
  Future<void> deleteFolder(String id) {
    return _col.doc(id).delete();
  }
}
