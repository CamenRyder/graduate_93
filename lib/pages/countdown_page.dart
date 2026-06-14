import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../controllers/guest_controller.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../services/guest_cache.dart';
import '../widgets/theme_toggle_button.dart';

/// Trang công khai: đếm ngược đến 09:00 ngày 26/06/2026.
///
/// Phía dưới là luồng nhập 2 bước:
///   1. Nhập mã code -> tra Firestore.
///        - Không trùng       : báo "sai mã".
///        - Trùng & isActive   : đã đăng nhập trước đó -> sang trang chào.
///        - Trùng & chưa active: fade sang bước nhập số điện thoại.
///   2. Nhập số điện thoại -> ghi xuống Firestore + bật isActive -> trang chào.
class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

/// Bước hiện tại của form nhập.
enum _Step { code, phone }

class _CountdownPageState extends State<CountdownPage> {
  /// Mốc đích: 09:00 26/06/2026 (giờ máy/địa phương).
  static final DateTime _target = DateTime(2026, 6, 26, 9);

  final _service = FirestoreService();
  final _codeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  Timer? _timer;
  Duration _remaining = Duration.zero;

  _Step _step = _Step.code;
  AppUser? _matched; // user tìm được theo mã (chờ kích hoạt ở bước phone)
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _loadCache();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _remaining = _target.difference(DateTime.now()));
  }

  Future<void> _loadCache() async {
    final cached = await GuestCache.load();
    if (!mounted || cached.code == null) return;
    setState(() => _codeCtrl.text = cached.code.toString());
  }

  /// Bước 1: xác thực mã code.
  Future<void> _submitCode() async {
    final code = int.tryParse(_codeCtrl.text.trim());
    if (code == null) {
      setState(() => _error = 'Vui lòng nhập mã code');
      return;
    }

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
          _error = 'Mã code không đúng, vui lòng thử lại';
        });
        return;
      }

      // Đã kích hoạt trước đó -> vào thẳng trang chào.
      if (user.isActive) {
        await guestController.signIn(
          code: user.userId,
          email: user.email,
          name: user.name,
          who: user.who,
          me: user.me,
          confirmed: user.isConfirm,
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Có lỗi xảy ra: $e';
      });
    }
  }

  /// Bước 2: lưu số điện thoại + bật isActive.
  Future<void> _submitPhone() async {
    final user = _matched;
    final phone = _phoneCtrl.text.trim();
    if (user == null) {
      setState(() => _step = _Step.code);
      return;
    }
    if (phone.isEmpty) {
      setState(() => _error = 'Vui lòng nhập số điện thoại');
      return;
    }

    final router = GoRouter.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _service.activateGuest(docId: user.id, phone: phone);
      await guestController.signIn(
        code: user.userId,
        email: user.email,
        name: user.name,
        who: user.who,
        me: user.me,
        confirmed: user.isConfirm,
      );
      if (!mounted) return;
      router.go('/welcome');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không lưu được, vui lòng thử lại: $e';
      });
    }
  }

  void _backToCode() {
    setState(() {
      _step = _Step.code;
      _matched = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final finished = _remaining.isNegative;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: const ThemeToggleButton(),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Đếm ngược đến sự kiện',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (finished)
                        Text(
                          'Sự kiện đã bắt đầu! 🎉',
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        )
                      else
                        _Countdown(duration: _remaining),
                      const SizedBox(height: 12),
                      Text(
                        '09:00 · 26/06/2026',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      _stepArea(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Khu vực nhập với hiệu ứng fade khi đổi bước.
  Widget _stepArea() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _step == _Step.code
          ? _codeStep(key: const ValueKey('code'))
          : _phoneStep(key: const ValueKey('phone')),
    );
  }

  Widget _codeStep({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: false,
          enabled: !_loading,
          style: const TextStyle(fontSize: 22, letterSpacing: 4),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          onSubmitted: (_) => _loading ? null : _submitCode(),
          decoration: const InputDecoration(
            hintText: 'Nhập mã code',
            hintStyle: TextStyle(letterSpacing: 0),
          ),
        ),
        _errorBox(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _submitCode,
          child: _loading
              ? const _BtnSpinner()
              : const Text('Tiếp tục'),
        ),
      ],
    );
  }

  Widget _phoneStep({required Key key}) {
    final name = (_matched?.name.isNotEmpty ?? false) ? _matched!.name : 'bạn';
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Xin chào $name!',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Nhập số điện thoại để hoàn tất',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          textAlign: TextAlign.center,
          autofocus: true,
          enabled: !_loading,
          style: const TextStyle(fontSize: 20),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            LengthLimitingTextInputFormatter(15),
          ],
          onSubmitted: (_) => _loading ? null : _submitPhone(),
          decoration: const InputDecoration(
            hintText: 'Nhập số điện thoại',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        _errorBox(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _submitPhone,
          child: _loading ? const _BtnSpinner() : const Text('Hoàn tất'),
        ),
        TextButton(
          onPressed: _loading ? null : _backToCode,
          child: const Text('Quay lại'),
        ),
      ],
    );
  }

  Widget _errorBox() {
    if (_error == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: colorScheme.onErrorContainer, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BtnSpinner extends StatelessWidget {
  const _BtnSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

/// Countdown không khung, dạng "dd ngày - hh:mm:ss".
/// Bọc trong [FittedBox] nên tự co lại vừa bề ngang trên thiết bị di động.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(hours)}:${two(minutes)}:${two(seconds)}';

    final numberStyle = TextStyle(
      fontSize: 60,
      fontWeight: FontWeight.bold,
      height: 1,
      color: colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final labelStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurfaceVariant,
    );
    final sepStyle = TextStyle(
      fontSize: 44,
      fontWeight: FontWeight.w300,
      color: colorScheme.primary,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$days', style: numberStyle),
            TextSpan(text: ' ngày', style: labelStyle),
            TextSpan(text: '  -  ', style: sepStyle),
            TextSpan(text: time, style: numberStyle),
          ],
        ),
        maxLines: 1,
        textAlign: TextAlign.center,
      ),
    );
  }
}
