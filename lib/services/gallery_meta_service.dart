import 'package:cloud_firestore/cloud_firestore.dart';

/// Lưu "cấu hình màu" cho từng ảnh gallery trên Firestore.
///
/// File ảnh nằm ở Supabase Storage; còn MÀU gán cho mỗi ảnh lưu ở Firestore
/// (collection `gallery`, document id = TÊN ảnh, field `color` = khóa màu của
/// [RowPalette], vd "blue"). Tách vậy để lọc/phân loại theo màu giống bảng
/// users, đồng thời tận dụng Firestore rules sẵn có (admin ghi, đọc công khai).
class GalleryMetaService {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('gallery');

  /// Lắng nghe map {tên ảnh -> khóa màu} theo thời gian thực.
  /// Ảnh không có màu sẽ không xuất hiện trong map.
  Stream<Map<String, String>> watchColors() {
    return _col.snapshots().map((snap) {
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final color = doc.data()['color']?.toString() ?? '';
        if (color.isNotEmpty) map[doc.id] = color;
      }
      return map;
    });
  }

  /// Gán màu cho 1 ảnh. [colorKey] rỗng = bỏ màu (xóa document).
  Future<void> setColor(String imageName, String colorKey) {
    final ref = _col.doc(imageName);
    if (colorKey.isEmpty) return ref.delete();
    return ref.set({
      'color': colorKey,
      'time_updated': FieldValue.serverTimestamp(),
    });
  }

  /// Gán màu cho NHIỀU ảnh cùng lúc (1 batch). [colorKey] rỗng = bỏ màu.
  Future<void> setColors(Iterable<String> imageNames, String colorKey) {
    final batch = FirebaseFirestore.instance.batch();
    for (final name in imageNames) {
      final ref = _col.doc(name);
      if (colorKey.isEmpty) {
        batch.delete(ref);
      } else {
        batch.set(ref, {
          'color': colorKey,
          'time_updated': FieldValue.serverTimestamp(),
        });
      }
    }
    return batch.commit();
  }

  /// Xóa metadata màu của nhiều ảnh (gọi khi xóa ảnh khỏi Storage).
  Future<void> deleteMetas(Iterable<String> imageNames) {
    final batch = FirebaseFirestore.instance.batch();
    for (final name in imageNames) {
      batch.delete(_col.doc(name));
    }
    return batch.commit();
  }
}
