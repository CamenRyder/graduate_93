import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/guest_controller.dart';
import '../theme/app_styles.dart';
import '../widgets/mobile_page.dart';
import '../widgets/typing_text.dart';

/// Trang chào sau khi khách xác thực xong (nhập code + số điện thoại).
///
/// Router đảm bảo chỉ khách đã xác thực mới vào được đây, và không cho quay lại
/// trang nhập code (xem redirect trong `router.dart`).
///
/// Lời nhắn gồm 2 đoạn hiện lần lượt: gõ kiểu typewriter từng đoạn, gõ xong
/// đoạn trước thì chờ 3s rồi mới gõ đoạn sau. Gõ xong đoạn cuối, chờ 3s rồi
/// fade out cả khối và chuyển sang màn chi tiết lời mời (`/invite`).
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  /// Khoảng nghỉ sau khi gõ xong 1 đoạn (trước khi gõ đoạn kế / trước khi fade).
  static const Duration _gap = Duration(seconds: 3);
  static const Duration _fadeDuration = Duration(milliseconds: 600);

  // Lời nhắn cá nhân hóa: "em" -> field `who`, "anh" -> field `me` của user.
  late final List<String> _messages = _buildMessages();

  int _visible = 1; // số đoạn đang được hiển thị
  bool _fadeOut = false; // bắt đầu mờ dần để rời trang
  Timer? _timer;

  List<String> _buildMessages() {
    // Field trống thì lùi về xưng hô gốc cho lời nhắn không bị hụt chữ.
    final who = _orElse(guestController.who, 'em');
    final me = _orElse(guestController.me, 'anh');
    final name = _orElse(guestController.name, 'bạn'); // tên khách (vd "Kiều Vy")

    return [
      'Hii $who, $name thật mừng vì $who đã quét mã QR và đọc được thông tin '
          'thiệp Online này. ${_cap(who)} danh 1 ít thời gian đến dự tốt nghiệp '
          'của $me nha.',
      '${_cap(me)} rất vui và mong chờ được gặp $who trong lễ tốt nghiệp của '
          'mình. Mặc dù là nó diễn ra trễ hơn rất nhiều so với bạn bè đồng '
          'trang lứa :v',
    ];
  }

  static String _orElse(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  // Viết hoa chữ cái đầu cho token đứng đầu câu (vd "em" -> "Em").
  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Gõ xong đoạn mới nhất:
  ///  - còn đoạn sau  -> chờ 3s rồi mở đoạn kế tiếp.
  ///  - đã là đoạn cuối -> chờ 3s rồi fade out để sang `/invite`.
  void _onParagraphDone() {
    _timer?.cancel();
    if (_visible < _messages.length) {
      _timer = Timer(_gap, () {
        if (mounted) setState(() => _visible++);
      });
    } else {
      _timer = Timer(_gap, () {
        if (mounted) setState(() => _fadeOut = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobilePage(
      child: AnimatedOpacity(
        opacity: _fadeOut ? 0 : 1,
        duration: _fadeDuration,
        // Mờ hẳn rồi mới rời trang để chuyển cảnh mượt.
        onEnd: () {
          if (_fadeOut && mounted) context.go('/invite');
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < _visible; i++) ...[
              if (i > 0) const SizedBox(height: 18),
              TypingText(
                _messages[i],
                style: messageTextStyle(context),
                // Chỉ đoạn mới nhất mới hẹn giờ mở đoạn kế / fade out.
                onCompleted: i == _visible - 1 ? _onParagraphDone : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
