import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Thông tin liên hệ của chủ web.
const String _phone = '0337254483';
const String _facebookUrl = 'https://www.facebook.com/seanz018/';
const String _zaloUrl = 'https://zalo.me/$_phone';

/// Mở URL ngoài (app chạy trên web).
///
/// - Link web (Facebook/Zalo): mở tab mới.
/// - `tel:`: điều hướng cùng tab để trình duyệt bật trình gọi điện, tránh để
///   lại một tab trắng.
void _openUrl(String url, {bool sameTab = false}) {
  if (sameTab) {
    web.window.location.href = url;
  } else {
    web.window.open(url, '_blank');
  }
}

/// Dòng "Liên hệ Minh Hiếu" cố định dưới đáy màn hình. Nhấn vào sẽ mở popup 3
/// lựa chọn liên hệ: Messenger Facebook / Zalo / Gọi số điện thoại.
class ContactFooter extends StatelessWidget {
  const ContactFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _showContactSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          'Liên hệ Minh Hiếu',
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: colorScheme.onSurfaceVariant,
            decoration: TextDecoration.underline,
            decorationColor: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _showContactSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Liên hệ Minh Hiếu',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
            ),
            _ContactTile(
              icon: Icons.facebook,
              label: 'Messenger Facebook',
              onTap: () {
                _openUrl(_facebookUrl);
                Navigator.of(ctx).pop();
              },
            ),
            _ContactTile(
              icon: Icons.chat_bubble_outline,
              label: 'Zalo',
              onTap: () {
                _openUrl(_zaloUrl);
                Navigator.of(ctx).pop();
              },
            ),
            _ContactTile(
              icon: Icons.call_outlined,
              label: 'Gọi số điện thoại',
              onTap: () {
                _openUrl('tel:$_phone', sameTab: true);
                Navigator.of(ctx).pop();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}
