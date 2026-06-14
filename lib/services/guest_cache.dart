import 'package:shared_preferences/shared_preferences.dart';

/// Lưu/đọc thông tin khách (code, email, name, who, me, confirmed) trong
/// localStorage để dùng lại: điền sẵn ô nhập, cá nhân hóa lời nhắn, và điều
/// hướng đúng màn sau khi tải lại trang.
class GuestCache {
  static const String _kCode = 'guest_code';
  static const String _kEmail = 'guest_email';
  static const String _kName = 'guest_name';
  static const String _kWho = 'guest_who';
  static const String _kMe = 'guest_me';
  static const String _kConfirmed = 'guest_confirmed';

  static Future<void> save({
    required int code,
    required String email,
    required String name,
    required String who,
    required String me,
    required bool confirmed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCode, code);
    await prefs.setString(_kEmail, email);
    await prefs.setString(_kName, name);
    await prefs.setString(_kWho, who);
    await prefs.setString(_kMe, me);
    await prefs.setBool(_kConfirmed, confirmed);
  }

  /// Cập nhật riêng cờ đã-xác-nhận (sau khi khách bấm "Gửi").
  static Future<void> saveConfirmed(bool confirmed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConfirmed, confirmed);
  }

  static Future<
      ({
        int? code,
        String? email,
        String? name,
        String? who,
        String? me,
        bool? confirmed,
      })> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      code: prefs.getInt(_kCode),
      email: prefs.getString(_kEmail),
      name: prefs.getString(_kName),
      who: prefs.getString(_kWho),
      me: prefs.getString(_kMe),
      confirmed: prefs.getBool(_kConfirmed),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCode);
    await prefs.remove(_kEmail);
    await prefs.remove(_kName);
    await prefs.remove(_kWho);
    await prefs.remove(_kMe);
    await prefs.remove(_kConfirmed);
  }
}
