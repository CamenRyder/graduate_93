import 'package:cloud_firestore/cloud_firestore.dart';

/// Model ứng với 1 document trong collection `users` trên Firestore.
///
/// Các giá trị được đọc "an toàn": nếu field thiếu hoặc sai kiểu thì dùng
/// giá trị mặc định, tránh app bị crash khi dữ liệu trên Firestore không đầy đủ.
class AppUser {
  AppUser({
    required this.id,
    required this.index,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.message,
    required this.des1,
    required this.des2,
    required this.des3,
    required this.isActive,
    required this.isConfirm,
    required this.timeMeeting,
    required this.timeEnding,
    required this.timeUpdated,
  });

  /// ID của document (Firestore tự sinh, vd: "SKysEciyPSJdF6FvmkdB").
  final String id;

  /// Vị trí hiển thị (0, 1, 2, ...). Dùng để sắp xếp và di chuyển thứ tự.
  final int index;

  /// Field `ID` (kiểu số) bên trong document.
  final int userId;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String message;
  final String des1;
  final String des2;
  final String des3;

  /// Tài khoản đang hoạt động hay không.
  final bool isActive;
  final bool isConfirm;
  final String timeMeeting;
  final String timeEnding;
  final DateTime? timeUpdated;

  /// Tạo [AppUser] từ 1 document Firestore.
  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppUser(
      id: doc.id,
      index: (data['index'] as num?)?.toInt() ?? 0,
      userId: (data['ID'] as num?)?.toInt() ?? 0,
      name: data['Name']?.toString() ?? '',
      email: data['Email']?.toString() ?? '',
      phone: data['Phone']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      des1: data['Des_1']?.toString() ?? '',
      des2: data['Des_2']?.toString() ?? '',
      des3: data['Des_3']?.toString() ?? '',
      isActive: data['isActive'] as bool? ?? true,
      isConfirm: data['isConfirm'] as bool? ?? false,
      timeMeeting: data['timeMeeting']?.toString() ?? '',
      timeEnding: data['timeEnding']?.toString() ?? '',
      timeUpdated: (data['time_updated'] as Timestamp?)?.toDate(),
    );
  }

  /// Chuyển ngược lại thành Map để ghi lên Firestore (dùng khi thêm/sửa).
  Map<String, dynamic> toFirestore() {
    return {
      'index': index,
      'ID': userId,
      'Name': name,
      'Email': email,
      'Phone': phone,
      'address': address,
      'message': message,
      'Des_1': des1,
      'Des_2': des2,
      'Des_3': des3,
      'isActive': isActive,
      'isConfirm': isConfirm,
      'timeMeeting': timeMeeting,
      'timeEnding': timeEnding,
      'time_updated':
          timeUpdated == null ? null : Timestamp.fromDate(timeUpdated!),
    };
  }
}
