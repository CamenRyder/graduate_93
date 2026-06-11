import 'package:shared_preferences/shared_preferences.dart';

/// Lưu/đọc thông tin khách (code, email, name) trong localStorage để tiện
/// dùng lại (điền sẵn ô nhập, hiển thị trang chào).
class GuestCache {
  static const String _kCode = 'guest_code';
  static const String _kEmail = 'guest_email';
  static const String _kName = 'guest_name';

  static Future<void> save({
    required int code,
    required String email,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCode, code);
    await prefs.setString(_kEmail, email);
    await prefs.setString(_kName, name);
  }

  static Future<({int? code, String? email, String? name})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      code: prefs.getInt(_kCode),
      email: prefs.getString(_kEmail),
      name: prefs.getString(_kName),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCode);
    await prefs.remove(_kEmail);
    await prefs.remove(_kName);
  }
}
