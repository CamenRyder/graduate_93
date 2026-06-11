import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quản lý đăng nhập admin bằng Firebase Authentication (email/password),
/// kèm cơ chế khóa phía client sau khi nhập sai quá nhiều lần.
///
/// Bảo mật thật nằm ở:
///  - Firebase Auth: mật khẩu lưu/băm phía Google, không nằm trong code.
///  - Firestore Security Rules: chỉ admin đã đăng nhập mới đọc/ghi được data.
///
/// Phần khóa 3 lần dưới đây chỉ là lớp UX phụ (lưu ở localStorage, có thể bị
/// xóa). Firebase cũng tự chặn (`too-many-requests`) khi thử quá nhiều lần.
class AuthController extends ChangeNotifier {
  static const String adminEmail = 'mhieusz.23.dkc@gmail.com';

  /// Số lần nhập sai tối đa trước khi khóa (phía client).
  static const int maxAttempts = 3;

  static const String _prefsFailed = 'failed_attempts';
  static const String _prefsLocked = 'is_locked';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  bool get isLoggedIn => _user != null;

  int _failedAttempts = 0;
  int get failedAttempts => _failedAttempts;

  bool _locked = false;
  bool get isLocked => _locked;

  int get remainingAttempts =>
      (maxAttempts - _failedAttempts).clamp(0, maxAttempts);

  /// Đọc trạng thái khóa đã lưu + khôi phục phiên đăng nhập Firebase.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _failedAttempts = prefs.getInt(_prefsFailed) ?? 0;
    _locked = prefs.getBool(_prefsLocked) ?? false;

    // firebase_auth tự lưu phiên trên web -> chờ trạng thái ban đầu.
    _user = await _auth.authStateChanges().first;
    _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Đăng nhập. Trả về `null` nếu thành công, hoặc chuỗi lỗi nếu sai/bị khóa.
  Future<String?> login(String email, String password) async {
    if (_locked) {
      return 'Tài khoản đã bị khóa do nhập sai quá $maxAttempts lần.';
    }

    final prefs = await SharedPreferences.getInstance();

    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Đăng nhập đúng -> reset bộ đếm. _user cập nhật qua authStateChanges.
      _failedAttempts = 0;
      await prefs.setInt(_prefsFailed, 0);
      return null;
    } on FirebaseAuthException catch (e) {
      // Firebase tự tạm khóa khi thử quá nhiều lần.
      if (e.code == 'too-many-requests') {
        return 'Quá nhiều lần thử. Firebase tạm khóa, hãy thử lại sau ít phút.';
      }

      _failedAttempts++;
      await prefs.setInt(_prefsFailed, _failedAttempts);

      if (_failedAttempts >= maxAttempts) {
        _locked = true;
        await prefs.setBool(_prefsLocked, true);
        notifyListeners();
        return 'Sai quá $maxAttempts lần. Tài khoản đã bị khóa vĩnh viễn.';
      }

      notifyListeners();
      // (mã: ${e.code}) là thông tin chẩn đoán tạm thời — sẽ gỡ sau khi xong.
      return 'Email hoặc mật khẩu không đúng (mã: ${e.code}). '
          'Còn $remainingAttempts lần thử.';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    // _user -> null qua authStateChanges.
  }
}

/// Instance dùng chung toàn app.
final authController = AuthController();
