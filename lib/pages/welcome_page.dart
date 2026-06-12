import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/guest_cache.dart';
import '../widgets/typing_text.dart';

/// Trang chủ sau khi khách xác thực xong (hiện là placeholder).
/// Chưa có thông tin trong cache -> quay về trang nhập code.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  Future<void> _checkCache() async {
    final cached = await GuestCache.load();
    if (!mounted) return;
    if (cached.code == null) {
      GoRouter.of(context).go('/');
      return;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _loading
            ? const SizedBox.shrink()
            : TypingText(
                'Trang chủ hẹ hẹ',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
      ),
    );
  }
}
