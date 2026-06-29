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
    required this.who,
    required this.me,
    required this.email,
    required this.phone,
    required this.address,
    required this.message,
    required this.des1,
    required this.des2,
    required this.des3,
    required this.isActive,
    required this.isConfirm,
    required this.rowColor,
    required this.timeMeeting,
    required this.timeEnding,
    required this.timeUpdated,
    required this.showAllPhotos,
  });

  /// ID của document (Firestore tự sinh, vd: "SKysEciyPSJdF6FvmkdB").
  final String id;

  /// Vị trí hiển thị (0, 1, 2, ...). Dùng để sắp xếp và di chuyển thứ tự.
  final int index;

  /// Field `ID` (kiểu số) bên trong document.
  final int userId;
  final String name;

  /// Field `who` (kiểu chuỗi). User cũ chưa có field này sẽ mặc định "Mày".
  final String who;

  /// Field `Me` (kiểu chuỗi). User cũ chưa có field này mặc định rỗng.
  final String me;
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

  /// Khóa màu "holder" của hàng (vd "blue", "maroon"). Rỗng = không tô màu.
  /// Lưu khóa ngữ nghĩa thay vì mã RGB để tự hợp cả Sáng lẫn Tối.
  final String rowColor;
  final String timeMeeting;
  final String timeEnding;
  final DateTime? timeUpdated;

  /// Cho phép xem toàn bộ ảnh (true) hay chỉ xem theo màu sắc (false).
  final bool showAllPhotos;

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
      who: data['who']?.toString() ?? 'Mày',
      me: data['Me']?.toString() ?? '',
      email: data['Email']?.toString() ?? '',
      phone: data['Phone']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      des1: data['Des_1']?.toString() ?? '',
      des2: data['Des_2']?.toString() ?? '',
      des3: data['Des_3']?.toString() ?? '',
      isActive: data['isActive'] as bool? ?? true,
      isConfirm: data['isConfirm'] as bool? ?? false,
      // Mặc định KHÔNG màu khi import lần đầu; admin tự set sau.
      rowColor: data['rowColor']?.toString() ?? '',
      timeMeeting: data['timeMeeting']?.toString() ?? '',
      timeEnding: data['timeEnding']?.toString() ?? '',
      timeUpdated: (data['time_updated'] as Timestamp?)?.toDate(),
      showAllPhotos: data['showAllPhotos'] as bool? ?? false,
    );
  }

  /// Chuyển ngược lại thành Map để ghi lên Firestore (dùng khi thêm/sửa).
  Map<String, dynamic> toFirestore() {
    return {
      'index': index,
      'ID': userId,
      'Name': name,
      'who': who,
      'Me': me,
      'Email': email,
      'Phone': phone,
      'address': address,
      'message': message,
      'Des_1': des1,
      'Des_2': des2,
      'Des_3': des3,
      'isActive': isActive,
      'isConfirm': isConfirm,
      'rowColor': rowColor,
      'timeMeeting': timeMeeting,
      'timeEnding': timeEnding,
      'time_updated':
          timeUpdated == null ? null : Timestamp.fromDate(timeUpdated!),
      'showAllPhotos': showAllPhotos,
    };
  }
}
