import 'package:flutter/material.dart';

/// Hiệu ứng fade in / fade out theo vị trí cuộn cho từng component.
///
/// Độ mờ được tính trực tiếp từ vị trí của widget trong khung nhìn (không phải
/// animation chạy 1 lần): phần tử trồi lên từ mép dưới thì hiện dần + trượt
/// nhẹ lên, trôi ra mép trên thì mờ dần. Cuộn ngược lại thì đảo ngược — luôn
/// khớp với tay người đọc.
///
/// - Chỉ dùng transform + opacity (không gây layout lại).
/// - Tắt hoàn toàn khi hệ thống bật "giảm chuyển động"
///   (`MediaQuery.disableAnimations`) hoặc khi không nằm trong Scrollable.
class ScrollReveal extends StatefulWidget {
  const ScrollReveal({
    super.key,
    required this.child,
    this.fadeDistance = 120,
    this.offset = 22,
    this.fadeOutAtTop = true,
  });

  final Widget child;

  /// Quãng đường (px) tính từ mép khung nhìn để đi từ mờ hẳn đến rõ hẳn.
  final double fadeDistance;

  /// Độ trượt dọc tối đa (px) khi phần tử còn mờ.
  final double offset;

  /// Có mờ dần khi trôi ra mép trên hay không (header/tiêu đề đầu trang nên
  /// tắt để không bị mờ ngay khi vừa mở trang).
  final bool fadeOutAtTop;

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal> {
  final _progress = ValueNotifier<double>(1);
  ScrollPosition? _position;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_scheduleUpdate);
      // Đo SAU khi frame layout xong: lúc listener chạy, vị trí của sliver
      // vẫn là của frame trước nên cuộn mạnh 1 nhịp sẽ đo sai.
      _position = position?..addListener(_scheduleUpdate);
    }
    _scheduleUpdate();
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleUpdate);
    _progress.dispose();
    super.dispose();
  }

  void _scheduleUpdate() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted) _update();
      })
      ..ensureVisualUpdate();
  }

  void _update() {
    final box = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    final viewportBox = scrollable?.context.findRenderObject();
    if (box is! RenderBox ||
        viewportBox is! RenderBox ||
        !box.hasSize ||
        !box.attached ||
        !viewportBox.attached) {
      return;
    }

    final top = box.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
    final bottom = top + box.size.height;
    final viewport = viewportBox.size.height;
    // Phần tử cao hơn quãng mờ thì dùng chiều cao của nó làm mốc, để khối lớn
    // (ảnh, đoạn dài) không phải cuộn quá xa mới rõ.
    final distance = widget.fadeDistance
        .clamp(1, box.size.height.clamp(1, double.infinity))
        .toDouble();

    // Đi vào từ mép dưới: mép trên của phần tử so với đáy khung nhìn.
    final enter = ((viewport - top) / distance).clamp(0.0, 1.0);
    // Rời khỏi mép trên: mép dưới của phần tử so với đỉnh khung nhìn.
    final exit = widget.fadeOutAtTop
        ? (bottom / distance).clamp(0.0, 1.0)
        : 1.0;
    final next = enter < exit ? enter : exit;
    if ((next - _progress.value).abs() > 0.004 || next == 0 || next == 1) {
      _progress.value = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) || _position == null) {
      return widget.child;
    }
    // Kích thước phần tử thay đổi (ảnh tải xong…) thì tính lại.
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _scheduleUpdate();
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: ValueListenableBuilder<double>(
          valueListenable: _progress,
          child: widget.child,
          builder: (context, value, child) {
            // easeOut cho cảm giác "đáp" mềm thay vì tuyến tính.
            final t = Curves.easeOut.transform(value);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * widget.offset),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}
