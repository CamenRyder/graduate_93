import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/typing_text.dart';

/// Trang dành riêng cho người yêu — /love.
/// Công khai, không yêu cầu xác thực.
class LovePage extends StatefulWidget {
  const LovePage({super.key});

  @override
  State<LovePage> createState() => _LovePageState();
}

class _LovePageState extends State<LovePage>
    with SingleTickerProviderStateMixin {
  static const _pink = Color(0xFFF48FB1);
  static const _rose = Color(0xFFE91E63);
  static const _overlay1 = Color(0xBB0D0510);
  static const _overlay2 = Color(0xEE0D0510);
  static const _overlay3 = Color(0xF50D0510);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  int _step = 0;
  bool _showHeart = false;
  Timer? _nextTimer;

  static const _messages = [
    'Hii em...',
    'Anh không biết em tìm thấy trang này như thế nào,\nnhưng anh đã để dành nó cho em từ lâu rồi đó. 🌸',
    'Chỉ muốn em biết một điều —\nem thật sự rất quan trọng trong cuộc sống của anh.',
    'Cảm ơn em đã luôn ở đây,\nluôn là em. ❤️',
  ];

  @override
  void initState() {
    super.initState();
    _nextTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _step = 1);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _nextTimer?.cancel();
    super.dispose();
  }

  void _onMessageDone(int index) {
    _nextTimer?.cancel();
    if (index < _messages.length - 1) {
      _nextTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _step = index + 2);
      });
    } else {
      _nextTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showHeart = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0510),
      body: Stack(
        children: [
          // Background: ảnh phong cảnh + lớp phủ tối lãng mạn
          Positioned.fill(
            child: Image.asset(
              'assets/images/avatar.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [_overlay1, _overlay2, _overlay3],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Floating hearts (8 trái tim bay lên, mỗi cái loop độc lập)
          for (int i = 0; i < 8; i++)
            _FloatingHeart(
              index: i,
              color: i.isEven ? _pink : _rose,
            ),

          // Nội dung chính
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 56, 32, 80),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ornament trên
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: _pink.withValues(alpha: 0.25),
                              endIndent: 10,
                            ),
                          ),
                          Icon(Icons.favorite, color: _pink, size: 13),
                          Expanded(
                            child: Divider(
                              color: _pink.withValues(alpha: 0.25),
                              indent: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),

                      // Các đoạn lần lượt hiện ra kiểu typewriter
                      for (int i = 0; i < _step; i++) ...[
                        if (i > 0) const SizedBox(height: 22),
                        TypingText(
                          _messages[i],
                          key: ValueKey('msg_$i'),
                          style: TextStyle(
                            color: i == 0
                                ? _pink
                                : Colors.white.withValues(alpha: 0.85),
                            fontSize: i == 0 ? 20 : 15,
                            fontWeight: i == 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                            height: 1.65,
                          ),
                          charDuration: const Duration(milliseconds: 40),
                          onCompleted:
                              i == _step - 1 ? () => _onMessageDone(i) : null,
                        ),
                      ],

                      const SizedBox(height: 56),

                      // Trái tim đập ở cuối
                      if (_showHeart)
                        AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 900),
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _pulse,
                              builder: (_, _) => Transform.scale(
                                scale: 1.0 + _pulse.value * 0.13,
                                child: ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                    colors: [Color(0xFFF48FB1), Color(0xFFE91E63)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds),
                                  blendMode: BlendMode.srcIn,
                                  child: const Icon(
                                    Icons.favorite,
                                    size: 58,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
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
}

/// Trái tim nhỏ bay từ dưới lên, mờ dần khi gần đỉnh, rồi lặp lại.
class _FloatingHeart extends StatefulWidget {
  const _FloatingHeart({required this.index, required this.color});

  final int index;
  final Color color;

  @override
  State<_FloatingHeart> createState() => _FloatingHeartState();
}

class _FloatingHeartState extends State<_FloatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = math.Random();
  late double _x;
  late double _size;

  @override
  void initState() {
    super.initState();
    _randomize();
    final dur = Duration(milliseconds: 4200 + _rng.nextInt(2400));
    _ctrl = AnimationController(vsync: this, duration: dur);
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(_randomize);
        _ctrl
          ..duration = Duration(milliseconds: 4200 + _rng.nextInt(2400))
          ..reset()
          ..forward();
      }
    });
    // Delay lệch nhau để không bung ra cùng lúc
    Future.delayed(Duration(milliseconds: widget.index * 700), () {
      if (mounted) _ctrl.forward();
    });
  }

  void _randomize() {
    _x = _rng.nextDouble();
    _size = 9.0 + _rng.nextDouble() * 14.0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final size = MediaQuery.sizeOf(context);
        final top = size.height * (1.0 - t) - _size;
        final left = _x * (size.width - _size);
        final opacity = (t > 0.72 ? (1.0 - t) / 0.28 : 1.0) * 0.42;
        return Positioned(
          top: top,
          left: left,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Icon(
              Icons.favorite,
              color: widget.color,
              size: _size,
            ),
          ),
        );
      },
    );
  }
}
