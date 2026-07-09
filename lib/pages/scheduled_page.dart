import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/guest_controller.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../theme/app_styles.dart';
import '../widgets/mobile_page.dart';

/// Màn "lịch hẹn" — vào sau khi khách bấm Gửi (đã xác nhận tham dự).
///
/// Hiện 2 đoạn lời nhắn (canh giữa, fade in) về điểm hẹn & lời dặn, kèm link
/// "xem hướng dẫn" mở màn hướng dẫn di chuyển.
class ScheduledPage extends StatefulWidget {
  const ScheduledPage({super.key});

  @override
  State<ScheduledPage> createState() => _ScheduledPageState();
}

class _ScheduledPageState extends State<ScheduledPage> {
  /// Mốc đích đếm ngược: 09:00 ngày tốt nghiệp 26/06/2026 (giờ địa phương).
  static final DateTime _gradDay = DateTime(2026, 6, 26, 9);

  final _service = FirestoreService();

  AppUser? _user;
  bool _loading = true;
  String? _error;

  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _loadUser();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _remaining = _gradDay.difference(DateTime.now()));
  }

  Future<void> _loadUser() async {
    final code = guestController.code;
    if (code == null) {
      setState(() {
        _loading = false;
        _error = 'Phiên đã hết, anh/chị mở lại từ đầu giúp em nhen.';
      });
      return;
    }
    try {
      final user = await _service.findByCodeOnly(code);
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
        if (user == null) {
          _error = 'Không tìm thấy thông tin, anh/chị thử lại giúp em nhen.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Mạng lag hay sao á, anh/chị tải lại giúp em nhen.';
      });
    }
  }

  // Xưng hô / giờ hẹn; field trống thì lùi về chữ gốc để câu không hụt.
  // Ưu tiên dữ liệu đã lưu lúc đăng nhập (guestController) để vẫn cá nhân hóa
  // được kể cả khi fetch lại _user chậm hoặc trả về thiếu who/me.
  String get _who => _first([_user?.who, guestController.who], 'anh');
  String get _me => _first([_user?.me, guestController.me], 'em');
  String get _timeMeeting => _orElse(_user?.timeMeeting, '11h30');

  static String _orElse(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  /// Lấy chuỗi không-rỗng đầu tiên trong [values], không có thì trả [fallback].
  static String _first(List<String?> values, String fallback) {
    for (final v in values) {
      final trimmed = v?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return MobilePage(child: _body());
  }

  Widget _body() {
    if (_loading) {
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

    if (_error != null) {
      return Text(
        _error!,
        style: messageTextStyle(context),
        textAlign: TextAlign.center,
      );
    }

    final style = messageTextStyle(context);

    // Toàn bộ nội dung fade in một lần khi vào màn (canh giữa).
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Đoạn 1 — in đậm giờ hẹn gặp.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$_me đã nhận thông tin nhe. Hẹn $_who lúc '),
                TextSpan(
                  text: _timeMeeting,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' tại '),
                const TextSpan(
                  text: 'hồ cá Koi',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: ' ở trường $_me nhe. Sơ đồ trường $_me và vị trí trên '
                      'map $_me có cung cấp bên dưới. Hôm thứ 6 nếu $_who không rõ '
                      'thông tin thì cứ quét QR mã và xem thông tin tổng hợp '
                      'nhoa',
                ),
              ],
            ),
            style: style,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _countdown(), 
          const SizedBox(height: 28),
          // Đoạn 2 — in nghiêng.
          Text(
            'Không cần mua quà hay hoa đâu, $_me muốn chụp 1 2 tấm hình cho '
            'dịp tốt nghiệp này để lưu lại thôi. ',
            style: style.copyWith(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // Đếm ngược tới ngày tốt nghiệp + dòng ngày nhỏ bên dưới.
          // Nút mở màn hướng dẫn di chuyển — style nút giống màn đăng nhập.
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kBrandGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => context.go('/guide'),
            child: const Text('xem hướng dẫn'),
          ),
          const SizedBox(height: 8),
          // Link nhỏ mở trang bài viết (nhật ký / chia sẻ của chủ thiệp).
          TextButton(
            style: TextButton.styleFrom(foregroundColor: kBrandGreen),
            onPressed: () => context.go('/posts'),
            child: const Text('xem bài viết'),
          ),
        ],
      ),
    );
  }

  /// Đồng hồ đếm ngược (Ngày / Giờ / Phút / Giây) tới ngày tốt nghiệp,
  /// kèm dòng chữ nhỏ ghi ngày bên dưới.
  Widget _countdown() {
    final colorScheme = Theme.of(context).colorScheme;
    // Tới giờ rồi (hoặc đã qua) thì giữ ở 0 để không hiện số âm.
    final d = _remaining.isNegative ? Duration.zero : _remaining;
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _unit(days, 'Ngày'),
              _sep(),
              _unit(hours, 'Giờ'),
              _sep(),
              _unit(minutes, 'Phút'),
              _sep(),
              _unit(seconds, 'Giây'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Thời gian: 26/06/2026',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Một ô số đếm ngược: số to bên trên, nhãn nhỏ bên dưới.
  Widget _unit(int value, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            value.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1,
              color: colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Dấu ":" ngăn giữa các ô số.
  Widget _sep() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w300,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
