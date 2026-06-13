import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

/// Lớp truy cập Firestore cho collection `users`.
///
/// Dùng `withConverter` để Firestore tự chuyển document <-> [AppUser],
/// nên ở UI ta làm việc trực tiếp với đối tượng AppUser thay vì Map.
class FirestoreService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<AppUser> get _usersRef => _db
      .collection('users')
      .withConverter<AppUser>(
        fromFirestore: (snapshot, _) => AppUser.fromFirestore(snapshot),
        toFirestore: (user, _) => user.toFirestore(),
      );

  // Ref "thô" (không converter) dùng cho việc ghi, để có thể chèn
  // FieldValue.serverTimestamp() cho field time_updated.
  CollectionReference<Map<String, dynamic>> get _rawUsersRef =>
      _db.collection('users');

  /// Lắng nghe danh sách users theo thời gian thực, sắp xếp theo `index`.
  Stream<List<AppUser>> watchUsers() {
    return _usersRef.orderBy('index').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
        );
  }

  /// Tra cứu user CHỈ theo code (= field `ID`, số 4 chữ số).
  /// Trả về user đầu tiên khớp mã, hoặc null nếu không có mã nào trùng.
  Future<AppUser?> findByCodeOnly(int code) async {
    final snap = await _usersRef.where('ID', isEqualTo: code).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data();
  }

  /// Sinh một mã `ID` ngẫu nhiên gồm 4 chữ số (1000–9999) CHƯA được dùng.
  /// Đọc toàn bộ user hiện có để loại các mã đã tồn tại, đảm bảo không trùng.
  /// Ném [StateError] nếu đã dùng hết toàn bộ mã 4 chữ số.
  Future<int> generateUniqueUserId() async {
    const minId = 1000;
    const maxId = 9999;

    final snap = await _rawUsersRef.get();
    final used = <int>{};
    for (final doc in snap.docs) {
      final id = (doc.data()['ID'] as num?)?.toInt();
      if (id != null) used.add(id);
    }

    if (used.length >= (maxId - minId + 1)) {
      throw StateError('Đã dùng hết mã ID 4 chữ số.');
    }

    final rnd = Random();
    int candidate;
    do {
      candidate = minId + rnd.nextInt(maxId - minId + 1);
    } while (used.contains(candidate));
    return candidate;
  }

  /// Khách kích hoạt lần đầu: lưu số điện thoại và bật `isActive = true`.
  /// Chỉ ghi đúng 3 field (Phone, isActive, time_updated) để khớp với
  /// Firestore rules cho phép khách (chưa đăng nhập) cập nhật.
  Future<void> activateGuest({
    required String docId,
    required String phone,
  }) {
    return _rawUsersRef.doc(docId).update({
      'Phone': phone,
      'isActive': true,
      'time_updated': FieldValue.serverTimestamp(),
    });
  }

  /// Thêm 1 user mới vào CUỐI danh sách (index = max + 1).
  /// `time_updated` đặt theo giờ server.
  Future<void> addUser(AppUser user) async {
    final lastSnap =
        await _rawUsersRef.orderBy('index', descending: true).limit(1).get();
    final nextIndex = lastSnap.docs.isEmpty
        ? 0
        : ((lastSnap.docs.first.data()['index'] as num?)?.toInt() ?? -1) + 1;

    final data = user.toFirestore()
      ..['index'] = nextIndex
      ..['time_updated'] = FieldValue.serverTimestamp();
    await _rawUsersRef.add(data);
  }

  /// Sao chép [source] thành 1 user mới đặt NGAY DƯỚI nó.
  /// Bản sao có index = source.index + 1; các user phía dưới được đẩy
  /// xuống 1 bậc để chừa chỗ (giữ index liền mạch).
  /// [newUserId] là mã `ID` mới (không trùng) cấp cho bản sao.
  /// Trả về document id của bản sao (để vào chế độ sửa ngay).
  Future<String> copyUser(AppUser source, {required int newUserId}) async {
    final newIndex = source.index + 1;

    // Các user đang ở vị trí >= newIndex -> dịch xuống 1.
    final shiftSnap = await _rawUsersRef
        .where('index', isGreaterThanOrEqualTo: newIndex)
        .get();

    final batch = _db.batch();
    for (final doc in shiftSnap.docs) {
      final cur = (doc.data()['index'] as num?)?.toInt() ?? 0;
      batch.update(doc.reference, {'index': cur + 1});
    }

    // Tạo bản sao (Firestore tự sinh document id mới), gán mã ID mới.
    final newRef = _rawUsersRef.doc();
    final data = source.toFirestore()
      ..['ID'] = newUserId
      ..['index'] = newIndex
      ..['time_updated'] = FieldValue.serverTimestamp();
    batch.set(newRef, data);

    await batch.commit();
    return newRef.id;
  }

  /// Cập nhật user đã có (theo document id). Giữ nguyên `index`.
  Future<void> updateUser(AppUser user) {
    final data = user.toFirestore()
      ..['time_updated'] = FieldValue.serverTimestamp();
    return _rawUsersRef.doc(user.id).update(data);
  }

  /// Lưu lại thứ tự hiển thị sau khi kéo-thả: gán index = vị trí mới cho
  /// từng user (chỉ ghi những doc có index thay đổi để tiết kiệm).
  Future<void> persistOrder(List<AppUser> orderedUsers) {
    final batch = _db.batch();
    for (var i = 0; i < orderedUsers.length; i++) {
      if (orderedUsers[i].index != i) {
        batch.update(_rawUsersRef.doc(orderedUsers[i].id), {'index': i});
      }
    }
    return batch.commit();
  }

  /// Xóa user, sau đó dồn lại index về 0, 1, 2, ... cho liền mạch.
  Future<void> deleteUser(String id) async {
    await _rawUsersRef.doc(id).delete();
    await _repackIndices();
  }

  /// Gán lại index 0..n-1 theo thứ tự hiện tại.
  Future<void> _repackIndices() async {
    final snap = await _rawUsersRef.orderBy('index').get();
    final batch = _db.batch();
    for (var i = 0; i < snap.docs.length; i++) {
      batch.update(snap.docs[i].reference, {'index': i});
    }
    await batch.commit();
  }
}
