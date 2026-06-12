import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../services/guest_cache.dart';
import '../widgets/typing_text.dart';

/// Trang xác thực khách mời (thiết kế tối giản, scale cho UI điện thoại).
///
/// Luồng 2 bước:
///   1. Nhập mã code 4 số (ghi trong thư mời) -> tra Firestore.
///        - Sai mã            : đổi lời nhắn + nút X đỏ.
///        - Đúng & isActive   : đã kích hoạt trước đó -> vào thẳng trang chủ.
///        - Đúng & chưa active: fade sang bước nhập số điện thoại.
///   2. Nhập số điện thoại -> lưu Firestore + bật isActive -> trang chủ.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

enum _Step { code, phone }

class _AuthPageState extends State<AuthPage> {
  static const Color _green = Color(0xFF34A12C);
  static const Color _red = Color(0xFF8E1B1B);

  final _service = FirestoreService();
  final _codeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  _Step _step = _Step.code;
  AppUser? _matched; // user khớp mã, chờ kích hoạt ở bước phone
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCache() async {
    final cached = await GuestCache.load();
    if (!mounted || cached.code == null) return;
    setState(() => _codeCtrl.text = cached.code.toString());
  }

  bool get _codeValid => _codeCtrl.text.trim().length == 4;
  bool get _phoneValid => _phoneCtrl.text.trim().length >= 9;

  /// Bước 1: xác thực mã code.
  Future<void> _submitCode() async {
    final code = int.tryParse(_codeCtrl.text.trim());
    if (code == null) return;

    final router = GoRouter.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _service.findByCodeOnly(code);
      if (!mounted) return;

      if (user == null) {
        setState(() {
          _loading = false;
          _error = 'Mã anh/chị nhập chưa chính xác, '
              'xem kỹ rùi nhập lại nhen.';
        });
        return;
      }

      // Đã kích hoạt trước đó -> vào thẳng trang chủ.
      if (user.isActive) {
        await GuestCache.save(
          code: user.userId,
          email: user.email,
          name: user.name,
        );
        if (!mounted) return;
        router.go('/welcome');
        return;
      }

      // Chưa active -> fade sang bước nhập số điện thoại.
      _phoneCtrl.text = user.phone;
      setState(() {
        _loading = false;
        _matched = user;
        _step = _Step.phone;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Mạng lag hay sao á, anh/chị bấm thử lại giúp em nhen.';
      });
    }
  }

  /// Bước 2: lưu số điện thoại + bật isActive.
  Future<void> _submitPhone() async {
    final user = _matched;
    if (user == null) {
      setState(() => _step = _Step.code);
      return;
    }

    final router = GoRouter.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _service.activateGuest(
        docId: user.id,
        phone: _phoneCtrl.text.trim(),
      );
      await GuestCache.save(
        code: user.userId,
        email: user.email,
        name: user.name,
      );
      if (!mounted) return;
      router.go('/welcome');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Chưa lưu được rồi, anh/chị bấm thử lại giúp em nhen.';
      });
    }
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: _step == _Step.code
                        ? _form(
                            key: const ValueKey('code'),
                            prompt: 'Hi, anh/chị hãy nhập mã code 4 số '
                                'đã được em ghi trong thư mời nhe.',
                            field: _codeField(),
                            valid: _codeValid,
                            icon: Icons.arrow_forward,
                            // Bước code: luôn lộ mũi tên kể cả khi chưa nhập.
                            showIdleIcon: true,
                            onSubmit: _submitCode,
                          )
                        : _form(
                            key: const ValueKey('phone'),
                            prompt: 'Ohhh ${_displayName()}. Em rất vui vì '
                                'anh/chị đăng nhập web của em. '
                                'anh/chị nhập sđt nha',
                            field: _phoneField(),
                            valid: _phoneValid,
                            icon: Icons.check,
                            showIdleIcon: false,
                            onSubmit: _submitPhone,
                          ),
                  ),
                ),
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 28),
                child: _ContactFooter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName() {
    final name = _matched?.name.trim() ?? '';
    return name.isEmpty ? 'anh/chị' : name;
  }

  /// Khối lời nhắn + ô nhập + nút hành động, dùng chung cho 2 bước.
  Widget _form({
    required Key key,
    required String prompt,
    required Widget field,
    required bool valid,
    required IconData icon,
    required bool showIdleIcon,
    required VoidCallback onSubmit,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lời nhắn gõ từng chữ; đổi sang lời báo lỗi thì gõ lại từ đầu.
        TypingText(
          _error ?? prompt,
          style: TextStyle(
            fontSize: 15,
            height: 1.55,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: field),
            const SizedBox(width: 12),
            _actionButton(
              valid: valid,
              icon: icon,
              showIdleIcon: showIdleIcon,
              onSubmit: onSubmit,
            ),
          ],
        ),
      ],
    );
  }

  Widget _codeField() {
    return _input(
      controller: _codeCtrl,
      hint: 'Nhập mã tại đây',
      maxLength: 4,
      onSubmitted: () => _codeValid ? _submitCode() : null,
    );
  }

  Widget _phoneField() {
    return _input(
      controller: _phoneCtrl,
      hint: 'Nhập số đt',
      maxLength: 11,
      onSubmitted: () => _phoneValid ? _submitPhone() : null,
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    required VoidCallback onSubmitted,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      enabled: !_loading,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      style: const TextStyle(fontSize: 16),
      onChanged: (_) {
        // Gõ lại là gỡ trạng thái lỗi + cập nhật màu nút.
        _clearError();
        setState(() {});
      },
      onSubmitted: (_) => _loading ? null : onSubmitted(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        fillColor: colorScheme.surfaceContainerHighest,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        // Theo thiết kế: ô nhập phẳng, không viền kể cả khi focus.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Nút vuông bo góc bên phải ô nhập, đổi theo trạng thái:
  /// xám (chưa hợp lệ) -> xanh (hợp lệ) -> spinner (đang xử lý)
  /// -> đỏ với dấu X (lỗi, bấm để nhập lại).
  Widget _actionButton({
    required bool valid,
    required IconData icon,
    required bool showIdleIcon,
    required VoidCallback onSubmit,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    const size = 48.0;

    if (_loading) {
      return SizedBox(
        width: size,
        height: size,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: CircularProgressIndicator(
            strokeWidth: 4.5,
            strokeCap: StrokeCap.round,
            color: _green,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      );
    }

    final hasError = _error != null;
    final Color background = hasError
        ? _red
        : valid
            ? _green
            : colorScheme.surfaceContainerHighest;
    final IconData? shownIcon = hasError
        ? Icons.close
        : (valid || showIdleIcon)
            ? icon
            : null;
    final Color iconColor =
        (hasError || valid) ? Colors.white : colorScheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          // Lỗi: bấm X để quay lại nhập; bình thường: chỉ bấm được khi hợp lệ.
          onTap: hasError ? _clearError : (valid ? onSubmit : null),
          child: shownIcon == null
              ? null
              : Icon(shownIcon, size: 22, color: iconColor),
        ),
      ),
    );
  }
}

/// Chữ ký nhỏ cố định dưới đáy màn hình.
class _ContactFooter extends StatelessWidget {
  const _ContactFooter();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Liên hệ Minh Hiếu',
      style: TextStyle(
        fontSize: 13,
        fontStyle: FontStyle.italic,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
