import 'package:flutter/foundation.dart';

import '../services/guest_cache.dart';

/// Trạng thái khách mời (đã xác thực hay chưa) giữ trong bộ nhớ để router điều
/// hướng đồng bộ, đồng thời lưu xuống localStorage qua [GuestCache].
///
/// Khi khách đã xác thực (`isAuthenticated == true`) thì router luôn đưa về
/// `/welcome` và chặn quay lại trang nhập code (`/`) — kể cả khi bấm back trên
/// trình duyệt hay tải lại trang.
class GuestController extends ChangeNotifier {
  int? _code;
  String _name = '';
  String _email = '';

  /// Đã nhập đúng code (đã vào được trang chủ) hay chưa.
  bool get isAuthenticated => _code != null;
  int? get code => _code;
  String get name => _name;
  String get email => _email;

  /// Nạp trạng thái đã lưu lúc khởi động app.
  Future<void> load() async {
    final cached = await GuestCache.load();
    _code = cached.code;
    _name = cached.name ?? '';
    _email = cached.email ?? '';
    notifyListeners();
  }

  /// Xác thực thành công -> lưu cache + thông báo để router sang `/welcome`.
  Future<void> signIn({
    required int code,
    required String email,
    required String name,
  }) async {
    await GuestCache.save(code: code, email: email, name: name);
    _code = code;
    _email = email;
    _name = name;
    notifyListeners();
  }

  /// Xóa trạng thái khách -> quay lại trang nhập code.
  Future<void> signOut() async {
    await GuestCache.clear();
    _code = null;
    _email = '';
    _name = '';
    notifyListeners();
  }
}

/// Instance dùng chung toàn app.
final guestController = GuestController();
