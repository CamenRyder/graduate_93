import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/guest_cache.dart';
import '../widgets/theme_toggle_button.dart';

/// Trang chào sau khi nhập đúng code + email. Tên lấy từ cache (đã tra cứu
/// theo code ở trang countdown).
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _loading = true;
  int? _code;
  String? _email;
  String? _name;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await GuestCache.load();
    if (!mounted) return;
    setState(() {
      _code = cached.code;
      _email = cached.email;
      _name = cached.name;
      _loading = false;
    });
  }

  Future<void> _exit() async {
    final router = GoRouter.of(context);
    await GuestCache.clear();
    if (!mounted) return;
    router.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                constraints: const BoxConstraints(maxWidth: 480),
                child: _loading
                    ? const CircularProgressIndicator()
                    : (_code == null
                        ? _noInfo(context)
                        : _greeting(context, theme, colorScheme)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _greeting(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    final name = (_name == null || _name!.isEmpty) ? 'bạn' : _name!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.celebration,
                  size: 36, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 20),
            Text(
              'Xin chào',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_email != null && _email!.isNotEmpty)
              _infoLine(context, Icons.email_outlined, _email!),
            if (_code != null)
              _infoLine(context, Icons.tag, 'Code: $_code'),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: _exit,
              icon: const Icon(Icons.logout),
              label: const Text('Thoát'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _noInfo(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Chưa có thông tin. Vui lòng nhập code và email.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => GoRouter.of(context).go('/'),
              child: const Text('Về trang đếm ngược'),
            ),
          ],
        ),
      ),
    );
  }
}
