import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../services/firestore_service.dart';
import '../services/guest_cache.dart';
import '../widgets/theme_toggle_button.dart';

/// Trang công khai: đếm ngược đến 09:00 ngày 26/06/2026, kèm form nhập
/// code + email để vào trang chào.
class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  /// Mốc đích: 09:00 26/06/2026 (giờ máy/địa phương).
  static final DateTime _target = DateTime(2026, 6, 26, 9);

  final _service = FirestoreService();
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  Timer? _timer;
  Duration _remaining = Duration.zero;
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
    _emailCtrl.dispose();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _remaining = _target.difference(DateTime.now()));
  }

  Future<void> _loadCache() async {
    final cached = await GuestCache.load();
    if (!mounted) return;
    setState(() {
      if (cached.code != null) _codeCtrl.text = cached.code.toString();
      if (cached.email != null) _emailCtrl.text = cached.email!;
    });
  }

  Future<void> _submit() async {
    final code = int.tryParse(_codeCtrl.text.trim());
    final email = _emailCtrl.text.trim();

    if (_codeCtrl.text.trim().isEmpty || email.isEmpty) {
      setState(() => _error = 'Vui lòng nhập đủ code và email');
      return;
    }
    if (code == null) {
      setState(() => _error = 'Code phải là số');
      return;
    }

    final router = GoRouter.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _service.findByCode(code, email);
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _loading = false;
          _error = 'Code hoặc email không đúng';
        });
        return;
      }
      await GuestCache.save(
        code: user.userId,
        email: user.email,
        name: user.name,
      );
      if (!mounted) return;
      router.go('/welcome');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Lỗi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _remaining.isNegative ? Duration.zero : _remaining;
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
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Đếm ngược đến sự kiện',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '09:00 · 26/06/2026',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 24),
                    if (finished)
                      Text(
                        'Sự kiện đã bắt đầu! 🎉',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      )
                    else
                      _Countdown(duration: d),
                    const SizedBox(height: 36),
                    _form(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nhập thông tin để tiếp tục',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(
                labelText: 'Code (4 số)',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _loading ? null : _submit(),
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
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
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Tiếp tục'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hiển thị countdown theo dạng dd - hh/mm/ss.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _block(context, days, 'Ngày'),
        _sep(context, '-'),
        _block(context, hours, 'Giờ'),
        _sep(context, '/'),
        _block(context, minutes, 'Phút'),
        _sep(context, '/'),
        _block(context, seconds, 'Giây'),
      ],
    );
  }

  Widget _block(BuildContext context, int value, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _sep(BuildContext context, String symbol) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
