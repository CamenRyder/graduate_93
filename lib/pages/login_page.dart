import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../widgets/theme_toggle_button.dart';

/// Trang đăng nhập admin.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final error = await authController.login(
      _emailCtrl.text,
      _passwordCtrl.text,
    );
    if (!mounted) return;
    // Đăng nhập đúng -> router tự chuyển sang /admin.
    // Sai -> hiện lỗi.
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final locked = authController.isLocked;
    // Khi đã khóa: ưu tiên hiện thông báo khóa kể cả chưa thử lần nào trong phiên.
    final message = locked
        ? 'Tài khoản đã bị khóa do nhập sai mật khẩu quá '
            '${AuthController.maxAttempts} lần.'
        : _error;

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
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: locked
                                ? colorScheme.errorContainer
                                : colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            locked
                                ? Icons.gpp_bad_outlined
                                : Icons.lock_outline,
                            size: 32,
                            color: locked
                                ? colorScheme.onErrorContainer
                                : colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Đăng nhập để quản lý dữ liệu',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _emailCtrl,
                          enabled: !locked,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Vui lòng nhập email'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordCtrl,
                          enabled: !locked,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => locked ? null : _submit(),
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            prefixIcon: const Icon(Icons.key_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Vui lòng nhập mật khẩu'
                              : null,
                        ),
                        if (message != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  locked
                                      ? Icons.lock_outline
                                      : Icons.error_outline,
                                  color: colorScheme.onErrorContainer,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    message,
                                    style: TextStyle(
                                      color: colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: (_loading || locked) ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(locked ? 'Đã bị khóa' : 'Đăng nhập'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
