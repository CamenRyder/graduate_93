import 'package:cloud_firestore/cloud_firestore.dart';

/// Metadata của toàn bộ kho ảnh tại một thời điểm (1 lần đọc snapshot).
class GalleryMetaSnapshot {
  const GalleryMetaSnapshot({required this.colors, required this.folders});

  /// {tên ảnh -> khóa màu}. Ảnh không có màu sẽ không xuất hiện trong map.
  final Map<String, String> colors;

  /// {tên ảnh -> id thư mục}. Ảnh chưa phân loại sẽ không xuất hiện trong map.
  final Map<String, String> folders;
}

/// Lưu "cấu hình" cho từng ảnh gallery trên Firestore.
///
/// File ảnh nằm ở Supabase Storage; còn metadata của mỗi ảnh lưu ở Firestore
/// (collection `gallery`, document id = TÊN ảnh):
/// - field `color`  = khóa màu của [RowPalette], vd "blue" — để lọc theo màu.
/// - field `folder` = id thư mục (collection `gallery_folders`) — mỗi ảnh
///   thuộc TỐI ĐA 1 thư mục; không có field = "Chưa phân loại".
/// Tách vậy để phân loại mà không cần di chuyển file trong Storage, đồng thời
/// tận dụng Firestore rules sẵn có (admin ghi, đọc công khai).
class GalleryMetaService {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('gallery');

  /// Firestore giới hạn 500 thao tác / batch — chia nhỏ cho an toàn.
  static const int _batchLimit = 450;

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

  /// Lắng nghe CẢ màu lẫn thư mục của mọi ảnh theo thời gian thực (1 listener
  /// duy nhất trên collection — trang admin dùng cái này thay vì nghe 2 lần).
  Stream<GalleryMetaSnapshot> watchMetas() {
    return _col.snapshots().map((snap) {
      final colors = <String, String>{};
      final folders = <String, String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final color = data['color']?.toString() ?? '';
        if (color.isNotEmpty) colors[doc.id] = color;
        final folder = data['folder']?.toString() ?? '';
        if (folder.isNotEmpty) folders[doc.id] = folder;
      }
      return GalleryMetaSnapshot(colors: colors, folders: folders);
    });
  }

  /// Gán màu cho 1 ảnh. [colorKey] rỗng = bỏ màu (chỉ gỡ field `color`,
  /// GIỮ NGUYÊN field `folder` nếu có — không xóa cả document).
  Future<void> setColor(String imageName, String colorKey) =>
      setColors([imageName], colorKey);

  /// Gán màu cho NHIỀU ảnh cùng lúc (batch). [colorKey] rỗng = bỏ màu.
  Future<void> setColors(Iterable<String> imageNames, String colorKey) {
    return _batched(imageNames, (batch, ref) {
      batch.set(
        ref,
        {
          'color': colorKey.isEmpty ? FieldValue.delete() : colorKey,
          'time_updated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Chuyển NHIỀU ảnh vào thư mục [folderId] (batch). [folderId] rỗng =
  /// đưa về "Chưa phân loại" (gỡ field `folder`, GIỮ NGUYÊN màu).
  Future<void> setFolder(Iterable<String> imageNames, String folderId) {
    return _batched(imageNames, (batch, ref) {
      batch.set(
        ref,
        {
          'folder': folderId.isEmpty ? FieldValue.delete() : folderId,
          'time_updated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Gỡ field `folder` khỏi MỌI ảnh đang thuộc thư mục [folderId] — gọi khi
  /// xóa thư mục để ảnh quay về "Chưa phân loại" (file KHÔNG bị xóa).
  Future<void> clearFolder(String folderId) async {
    if (folderId.isEmpty) return;
    final snap = await _col.where('folder', isEqualTo: folderId).get();
    await _batched(snap.docs.map((d) => d.id), (batch, ref) {
      batch.set(
        ref,
        {
          'folder': FieldValue.delete(),
          'time_updated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Xóa metadata của nhiều ảnh (gọi khi xóa ảnh khỏi Storage).
  Future<void> deleteMetas(Iterable<String> imageNames) {
    return _batched(imageNames, (batch, ref) => batch.delete(ref));
  }

  /// Chạy [op] cho từng ảnh trong [imageNames], tự chia thành nhiều batch
  /// (Firestore giới hạn 500 thao tác/batch) rồi commit tuần tự.
  Future<void> _batched(
    Iterable<String> imageNames,
    void Function(WriteBatch batch, DocumentReference<Map<String, dynamic>> ref)
        op,
  ) async {
    final names = imageNames.toList();
    for (var i = 0; i < names.length; i += _batchLimit) {
      final batch = FirebaseFirestore.instance.batch();
      for (final name in names.skip(i).take(_batchLimit)) {
        op(batch, _col.doc(name));
      }
      await batch.commit();
    }
  }
}
