import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/guest_controller.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../theme/app_styles.dart';
import '../widgets/mobile_page.dart';

/// Màn "chi tiết lời mời" sau trang chào.
///
/// Lấy lại thông tin user theo `code` của phiên khách (để có `who`, `me`,
/// `timeMeeting`, `timeEnding` và doc id dùng khi ghi câu trả lời).
///
/// Session 1: fade in đoạn script về thời gian & địa điểm, lời mời nhắn câu
/// trả lời + ô nhập (lưu vào `address`) + nút "Gửi". Bấm "Gửi" sẽ ghi câu trả
/// lời + bật `isConfirm = true` rồi điều hướng sang màn lịch hẹn (`/scheduled`).
class InviteDetailPage extends StatefulWidget {
  const InviteDetailPage({super.key});

  @override
  State<InviteDetailPage> createState() => _InviteDetailPageState();
}

class _InviteDetailPageState extends State<InviteDetailPage> {
  final _service = FirestoreService();
  final _answerCtrl = TextEditingController();

  AppUser? _user;
  bool _loadingUser = true;
  String? _loadError;

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final code = guestController.code;
    if (code == null) {
      setState(() {
        _loadingUser = false;
        _loadError = 'Phiên đã hết, anh/chị mở lại từ đầu giúp em nhen.';
      });
      return;
    }
    try {
      final user = await _service.findByCodeOnly(code);
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _loadingUser = false;
          _loadError = 'Không tìm thấy thông tin, anh/chị thử lại giúp em nhen.';
        });
        return;
      }
      _answerCtrl.text = user.address; // điền sẵn nếu đã trả lời trước đó
      setState(() {
        _user = user;
        _loadingUser = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingUser = false;
        _loadError = 'Mạng lag hay sao á, anh/chị tải lại giúp em nhen.';
      });
    }
  }

  // Xưng hô / giờ giấc; field trống thì lùi về chữ gốc để câu không hụt.
  String get _who => _orElse(_user?.who, 'anh');
  String get _me => _orElse(_user?.me, 'em');
  String get _timeEnding => _orElse(_user?.timeEnding, '2 tiếng rưỡi');
  String get _timeMeeting => _orElse(_user?.timeMeeting, '11h30');

  static String _orElse(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  /// Đoạn script thời gian & địa điểm, in đậm giờ làm lễ và giờ hẹn gặp.
  List<InlineSpan> _scriptSpans() {
    const bold = TextStyle(fontWeight: FontWeight.bold);
    return [
      const TextSpan(
        text: 'Trường Hutech bên khu công nghệ cao Quận 9 tổ chức làm lễ '
            'vào lúc ',
      ),
      const TextSpan(text: '7h30 sáng (26/06/2026)', style: bold),
      TextSpan(
        text: ' nhưng thời gian làm lễ và nhận bằng sẽ kéo dài tầm '
            '$_timeEnding. Để thuận tiện cho $_who $_me mình, ',
      ),
      TextSpan(text: 'tầm $_timeMeeting', style: bold),
      TextSpan(text: ' mìh gặp nhau $_who thấy ổn hog?'),
    ];
  }

  bool get _canSend => _answerCtrl.text.trim().isNotEmpty;

  Future<void> _send() async {
    final user = _user;
    if (user == null || !_canSend) return;

    setState(() => _sending = true);
    try {
      await _service.confirmAndSaveAddress(
        docId: user.id,
        address: _answerCtrl.text.trim(),
      );
      if (!mounted) return;
      // Đã xác nhận (isConfirm = true) -> nhớ cờ rồi sang màn lịch hẹn.
      await guestController.markConfirmed();
      if (!mounted) return;
      context.go('/scheduled');
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa gửi được rồi, thử lại giúp em nhen.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobilePage(child: _body());
  }

  Widget _body() {
    if (_loadingUser) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 4.5,
              strokeCap: StrokeCap.round,
              color: kBrandGreen,
            ),
          ),
        ),
      );
    }

    if (_loadError != null) {
      return Text(_loadError!, style: messageTextStyle(context));
    }

    // Toàn bộ thông tin session 1 fade in một lần (chạy 1 lần lúc tải xong;
    // các setState sau đó — gõ phím, gửi — không làm chạy lại hiệu ứng).
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: _scriptSpans()),
            style: messageTextStyle(context),
          ),
          const SizedBox(height: 20),
          Text(
            'Nhắn $_me câu trả lời nhe $_who.',
            style: messageTextStyle(context),
          ),
          const SizedBox(height: 14),
          _answerField(),
          const SizedBox(height: 14),
          _sendButton(),
        ],
      ),
    );
  }

  /// Ô nhập câu trả lời — style phẳng giống ô nhập ở màn auth.
  Widget _answerField() {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: _answerCtrl,
      enabled: !_sending,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.send,
      minLines: 1,
      maxLines: 4,
      maxLength: 300,
      style: const TextStyle(fontSize: 16),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _canSend ? _send() : null,
      decoration: InputDecoration(
        hintText: 'Nhập câu trả lời tại đây',
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        fillColor: colorScheme.surfaceContainerHighest,
        filled: true,
        counterText: '',
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        // Ô phẳng, không viền kể cả khi focus (đồng bộ với màn auth).
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Nút "Gửi": xám khi chưa nhập -> xanh (chữ trắng) khi có nội dung ->
  /// spinner khi đang gửi. Cùng style với màn auth.
  Widget _sendButton() {
    final colorScheme = Theme.of(context).colorScheme;
    const height = 48.0;

    if (_sending) {
      return const SizedBox(
        height: height,
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 4.5,
              strokeCap: StrokeCap.round,
              color: kBrandGreen,
            ),
          ),
        ),
      );
    }

    final enabled = _canSend;
    final Color background =
        enabled ? kBrandGreen : colorScheme.surfaceContainerHighest;
    final Color foreground =
        enabled ? Colors.white : colorScheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? _send : null,
          child: Center(
            child: Text(
              'Gửi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
