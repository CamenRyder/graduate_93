import 'package:flutter/foundation.dart';

import '../services/guest_cache.dart';

/// Trạng thái khách mời (đã xác thực hay chưa) giữ trong bộ nhớ để router điều
/// hướng đồng bộ, đồng thời lưu xuống localStorage qua [GuestCache].
///
/// Khi khách đã xác thực (`isAuthenticated == true`) thì router đưa vào trong;
/// nếu đã xác nhận tham dự (`confirmed == true`) thì vào thẳng màn lịch hẹn.
class GuestController extends ChangeNotifier {
  int? _code;
  String _name = '';
  String _email = '';
  String _who = '';
  String _me = '';
  String _rowColor = '';
  bool _confirmed = false;
  bool _showAllPhotos = false;

  /// Đã nhập đúng code (đã vào được trang chủ) hay chưa.
  bool get isAuthenticated => _code != null;
  int? get code => _code;
  String get name => _name;
  String get email => _email;

  /// Cách xưng hô với khách (field `who`) và cách chủ thiệp tự xưng (field `me`),
  /// dùng để cá nhân hóa lời nhắn ở các màn sau khi đăng nhập.
  String get who => _who;
  String get me => _me;

  /// Khóa màu "holder" của khách (field `rowColor`), vd "blue". Rỗng = không có
  /// màu -> khách không được xem ảnh nào của admin (xem [UserGalleryPage]).
  String get rowColor => _rowColor;

  /// Khách đã bấm "Gửi" xác nhận tham dự (isConfirm == true) hay chưa.
  /// Dùng để sau khi auth thì vào thẳng màn lịch hẹn thay vì trang chào.
  bool get confirmed => _confirmed;

  /// Khách được phép xem toàn bộ ảnh (true) hay chỉ xem theo màu sắc (false).
  bool get showAllPhotos => _showAllPhotos;

  /// Nạp trạng thái đã lưu lúc khởi động app.
  Future<void> load() async {
    final cached = await GuestCache.load();
    _code = cached.code;
    _name = cached.name ?? '';
    _email = cached.email ?? '';
    _who = cached.who ?? '';
    _me = cached.me ?? '';
    _rowColor = cached.rowColor ?? '';
    _confirmed = cached.confirmed ?? false;
    _showAllPhotos = cached.showAllPhotos ?? false;
    notifyListeners();
  }

  /// Xác thực thành công -> lưu cache + thông báo để router điều hướng vào trong.
  Future<void> signIn({
    required int code,
    required String email,
    required String name,
    String who = '',
    String me = '',
    String rowColor = '',
    bool confirmed = false,
    bool showAllPhotos = false,
  }) async {
    await GuestCache.save(
      code: code,
      email: email,
      name: name,
      who: who,
      me: me,
      rowColor: rowColor,
      confirmed: confirmed,
      showAllPhotos: showAllPhotos,
    );
    _code = code;
    _email = email;
    _name = name;
    _who = who;
    _me = me;
    _rowColor = rowColor;
    _confirmed = confirmed;
    _showAllPhotos = showAllPhotos;
    notifyListeners();
  }

  /// Đánh dấu đã xác nhận tham dự (sau khi ghi isConfirm = true lên Firestore).
  /// Giúp lần điều hướng / tải lại tiếp theo vào thẳng màn lịch hẹn.
  Future<void> markConfirmed() async {
    _confirmed = true;
    await GuestCache.saveConfirmed(true);
    notifyListeners();
  }

  /// Xóa trạng thái khách -> quay lại trang nhập code.
  Future<void> signOut() async {
    await GuestCache.clear();
    _code = null;
    _email = '';
    _name = '';
    _who = '';
    _me = '';
    _rowColor = '';
    _confirmed = false;
    _showAllPhotos = false;
    notifyListeners();
  }
}

/// Instance dùng chung toàn app.
final guestController = GuestController();
