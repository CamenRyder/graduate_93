import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ── Màu dùng chung ───────────────────────────────────────────────────────────
const _kBg0 = Color(0xFF24103F);
const _kBg1 = Color(0xFF1A0A2E);
const _kBg2 = Color(0xFF0E0518);
const _kPink = Color(0xFFF48FB1);
const _kRose = Color(0xFFE91E63);

/// Màu nền cho từng cặp thẻ (12 màu, giúp dễ phân biệt khi ghi nhớ vị trí).
const _kPairColors = <Color>[
  Color(0xFFE57373),
  Color(0xFFF06292),
  Color(0xFFBA68C8),
  Color(0xFF9575CD),
  Color(0xFF64B5F6),
  Color(0xFF4DD0E1),
  Color(0xFF4DB6AC),
  Color(0xFF81C784),
  Color(0xFFAED581),
  Color(0xFFFFD54F),
  Color(0xFFFFB74D),
  Color(0xFFA1887F),
];

enum _Phase { playing, burst, reveal }

enum _CardState { down, up, matched }

/// Trang dành riêng cho người yêu — /love.
/// Công khai (không cần đăng nhập). Trò chơi "Thẻ Bài Yêu Thương":
/// 24 thẻ = 12 cặp giống nhau. Lật trúng 2 thẻ giống nhau thì cặp đó biến mất
/// và thông điệp rơi vào "hũ". Ghép hết 12 cặp -> mưa trái tim -> hiện lại toàn
/// bộ thông điệp theo thứ tự 0 → 11. Giao diện ưu tiên cho mobile.
class LovePage extends StatefulWidget {
  const LovePage({super.key});

  @override
  State<LovePage> createState() => _LovePageState();
}

class _LovePageState extends State<LovePage> {
  /// 12 thông điệp — mỗi câu ứng với 1 cặp thẻ. (Sửa thoải mái, vẫn phải 12 câu.)
  static const _messages = <String>[
    'Hello tình iuuuu💕',
    'Beo là điều tuyệt nhất hiện tại mìh biết ',
    'Cảm ơn Beo đã ở đây và xem web này nhé:D',
    'Điều tuyệt vời nhất ơi',
    'Mình mời beo đến dự lễ tốt nghiệp của mình nhé 🎓💛',
    'Hôm đó sẽ là buổi sáng nắng đẹp',
    'Mà có beo, ngày nào cũng là nắng đẹp',
    'Cảm ơn vì đã là Beo đã nhận lời',
    'Cái website này nó đặc biệt bởi vì',
    'Chỉ có beo thấy đc nó và lời mời diễn ra theo cách này',
    'Mình sẽ trở beo đến dự lễ nun moaa',
    'Cùng nhau đi hết cuộc vui hôm đó nhe nhé 💍',
  ];

  /// Biểu tượng dự phòng cho từng cặp — dùng khi link ảnh tương ứng để rỗng.
  static const _emojis = <String>[
    '💖', '🌹', '🌸', '🦋', '⭐', '🌙',
    '🍓', '🎀', '🧸', '🍀', '💌', '🎓',
  ];

  /// Đường dẫn 12 ẢNH trong assets/love_card/ cho 12 cặp thẻ (theo thứ tự cặp
  /// 0→11, khớp với 12 thông điệp ở trên). File lỗi thì hiện emoji dự phòng.
  static const _imageAssets = <String>[
    'assets/love_card/hinhanh_01.jpg', // cặp 0
    'assets/love_card/hinhanh_02.jpg', // cặp 1
    'assets/love_card/hinhanh_03.jpg', // cặp 2
    'assets/love_card/hinhanh_04.jpg', // cặp 3
    'assets/love_card/hinhanh_05.jpg', // cặp 4
    'assets/love_card/hinhanh_06.jpg', // cặp 5
    'assets/love_card/hinhanh_07.jpg', // cặp 6
    'assets/love_card/hinhanh_08.jpg', // cặp 7
    'assets/love_card/hinhanh_09.jpg', // cặp 8
    'assets/love_card/hinhanh_10.jpg', // cặp 9
    'assets/love_card/hinhanh_11.jpg', // cặp 10
    'assets/love_card/hinhanh_12.jpg', // cặp 11
  ];

  final _rng = math.Random();

  late List<_CardModel> _cards;
  int? _firstIndex; // thẻ thứ nhất đang chờ ghép
  bool _busy = false; // đang chờ lật úp lại / xử lý
  _CardModel? _preview; // ảnh đang xem toàn màn hình (null = không xem)
  int? _pendingIndex; // thẻ vừa chạm, xử lý sau khi xem ảnh xong
  List<int>? _wrongPair; // 2 thẻ sai đang mở dở; chạm thẻ khác sẽ đóng ngay
  final List<int> _collected = []; // pairId đã ghép, theo thứ tự ghép (cho hũ)
  _Phase _phase = _Phase.playing;

  Timer? _flipTimer;
  Timer? _finaleTimer;
  bool _precached = false;
  bool _ready = false; // đã tải xong toàn bộ ảnh chưa
  int _loaded = 0; // số ảnh đã tải xong (cho thanh tiến độ)

  @override
  void initState() {
    super.initState();
    _setupGame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    _preloadImages();
  }

  /// Tải xong toàn bộ 12 ảnh rồi mới cho vào game (tránh thẻ trống lúc đầu).
  Future<void> _preloadImages() async {
    await Future.wait([
      for (final path in _imageAssets)
        // onError + catchError: dù 1 ảnh lỗi cũng không kẹt màn chờ.
        precacheImage(AssetImage(path), context, onError: (_, _) {})
            .catchError((_) {})
            .whenComplete(() {
          if (mounted) setState(() => _loaded++);
        }),
    ]);
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _flipTimer?.cancel();
    _finaleTimer?.cancel();
    super.dispose();
  }

  /// Tạo 24 thẻ (2 thẻ / cặp), xáo trộn, đưa về trạng thái ban đầu.
  void _setupGame() {
    final cards = <_CardModel>[];
    for (var p = 0; p < _messages.length; p++) {
      for (var k = 0; k < 2; k++) {
        cards.add(_CardModel(
          pairId: p,
          emoji: _emojis[p],
          image: _imageAssets[p],
          message: _messages[p],
          color: _kPairColors[p % _kPairColors.length],
        ));
      }
    }
    cards.shuffle(_rng);
    _cards = cards;
    _firstIndex = null;
    _busy = false;
    _preview = null;
    _pendingIndex = null;
    _wrongPair = null;
    _collected.clear();
    _phase = _Phase.playing;
  }

  void _restart() {
    _flipTimer?.cancel();
    _finaleTimer?.cancel();
    setState(_setupGame);
  }

  void _onCardTap(int i) {
    if (_phase != _Phase.playing || _busy) return;
    final card = _cards[i];
    if (card.state != _CardState.down) return;

    setState(() {
      // Đang có 2 thẻ sai mở dở -> đóng ngay lập tức, không chờ.
      if (_wrongPair != null) {
        for (final w in _wrongPair!) {
          _cards[w].state = _CardState.down;
        }
        _wrongPair = null;
      }
      // Lật thẻ ngửa (ngầm dưới lớp phủ) + mở ảnh xem toàn màn hình.
      card.state = _CardState.up;
      _preview = card;
      _pendingIndex = i;
      _busy = true;
    });
  }

  /// Gọi khi xem ảnh toàn màn hình xong -> xử lý thẻ vừa lật.
  void _onPreviewDone() {
    if (!mounted) return;
    final i = _pendingIndex;
    setState(() {
      _preview = null;
      _pendingIndex = null;
    });
    if (i == null) return;
    final card = _cards[i];

    // Thẻ thứ nhất -> để ngửa, chờ thẻ thứ hai.
    if (_firstIndex == null) {
      setState(() {
        _firstIndex = i;
        _busy = false;
      });
      return;
    }

    final first = _cards[_firstIndex!];
    if (first.pairId == card.pairId) {
      // Trúng cặp: thấy cả hai một nhịp rồi biến mất + bỏ vào hũ.
      _flipTimer = Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() {
          first.state = _CardState.matched;
          card.state = _CardState.matched;
          _collected.add(first.pairId);
          _firstIndex = null;
          _busy = false;
        });
        if (_collected.length == _messages.length) _startFinale();
      });
    } else {
      // Sai: để cả hai ngửa; chạm thẻ khác sẽ đóng ngay (không bắt chờ).
      setState(() {
        _wrongPair = [_firstIndex!, i];
        _firstIndex = null;
        _busy = false;
      });
    }
  }

  /// Ghép hết 24 thẻ -> mưa trái tim, rồi hiện lại toàn bộ thông điệp.
  void _startFinale() {
    _finaleTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _phase = _Phase.burst);
    });
  }

  void _onHeartsDone() {
    if (mounted) setState(() => _phase = _Phase.reveal);
  }

  /// Màn chờ trong khi tải 12 ảnh (thanh tiến độ n/12).
  Widget _loadingScreen() {
    final total = _imageAssets.length;
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) =>
                  const LinearGradient(colors: [_kPink, _kRose]).createShader(b),
              child: const Icon(Icons.favorite, color: Colors.white, size: 64),
            ),
            const SizedBox(height: 22),
            const Text(
              'Đang chuẩn bị kỷ niệm…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 200,
                height: 8,
                child: LinearProgressIndicator(
                  value: total == 0 ? null : _loaded / total,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(_kPink),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$_loaded/$total ảnh',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg2,
      body: Stack(
        children: [
          // Nền gradient tím lãng mạn
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kBg0, _kBg1, _kBg2],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Vài trái tim bay nền cho ấm áp
          for (var i = 0; i < 6; i++)
            _FloatingHeart(index: i, color: i.isEven ? _kPink : _kRose),

          // Chưa tải xong ảnh -> màn chờ; xong rồi mới vào game.
          if (!_ready)
            _loadingScreen()
          else ...[
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child:
                    _phase == _Phase.reveal ? _revealContent() : _playContent(),
              ),
            ),
            // Mưa trái tim khi ghép xong
            if (_phase == _Phase.burst)
              Positioned.fill(child: _HeartFinale(onComplete: _onHeartsDone)),
            // Ảnh xem toàn màn hình: fade in -> giữ 0.5s -> fade out
            if (_preview != null)
              _FullScreenPreview(image: _preview!.image, onDone: _onPreviewDone),
          ],
        ],
      ),
    );
  }

  // ── Giai đoạn chơi ─────────────────────────────────────────────────────────

  Widget _playContent() {
    final jarMessages = [for (final id in _collected) _messages[id]];
    return Column(
      children: [
        _header(
          context,
          title: 'Thẻ Bài Yêu Thương 💞',
          subtitle: 'Lật 2 thẻ giống nhau để mở lời nhắn 💌',
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              // Màn rộng (tablet/desktop): hũ đứng bên phải.
              if (c.maxWidth >= 720) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _grid()),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 240,
                      child: _Jar(
                        messages: jarMessages,
                        total: _messages.length,
                        compact: false,
                      ),
                    ),
                  ],
                );
              }
              // Mobile: hũ gọn nằm ngang ở trên, lưới vừa khít phần còn lại.
              return Column(
                children: [
                  _Jar(
                    messages: jarMessages,
                    total: _messages.length,
                    compact: true,
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: _grid()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Lưới 24 thẻ — tự tính số cột + tỉ lệ ô để vừa khít khung, hạn chế cuộn.
  Widget _grid() {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 8.0;
        final cols = (c.maxWidth / 90).floor().clamp(3, 6);
        final rows = (_cards.length / cols).ceil();
        final cellW = (c.maxWidth - (cols - 1) * gap) / cols;
        final cellH = (c.maxHeight - (rows - 1) * gap) / rows;
        final aspect =
            (cellH.isFinite && cellH > 0 ? cellW / cellH : 0.8).clamp(0.55, 1.4);
        return GridView.builder(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: aspect,
          ),
          itemBuilder: (context, i) => _cardCell(i),
        );
      },
    );
  }

  Widget _cardCell(int i) {
    final card = _cards[i];
    final faceUp = card.state != _CardState.down;
    final matched = card.state == _CardState.matched;
    return AnimatedOpacity(
      opacity: matched ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      child: IgnorePointer(
        ignoring: matched,
        child: GestureDetector(
          onTap: () => _onCardTap(i),
          child: MouseRegion(
            cursor:
                matched ? SystemMouseCursors.basic : SystemMouseCursors.click,
            child: _FlipCard(
              faceUp: faceUp,
              back: const _CardBack(),
              front: _CardFront(
                emoji: card.emoji,
                image: card.image,
                color: card.color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Giai đoạn hiện lại toàn bộ thông điệp ───────────────────────────────────

  Widget _revealContent() {
    return Column(
      children: [
        _header(
          context,
          title: 'Tất cả lời gửi Beo 💌',
          subtitle: 'Cảm ơn Beo đã mở hết những lời này 💕',
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _RevealList(messages: _messages),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.replay, color: _kPink),
          label: const Text('Chơi lại', style: TextStyle(color: _kPink)),
        ),
      ],
    );
  }

  // ── Phần dùng chung ─────────────────────────────────────────────────────────

  Widget _header(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        if (context.canPop())
          _circleIcon(Icons.arrow_back, () => context.pop())
        else
          const SizedBox(width: 38),
        Expanded(
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    const LinearGradient(colors: [_kPink, _kRose])
                        .createShader(b),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        // Nút chơi lại (lúc đang chơi); giai đoạn khác để trống cho cân.
        if (_phase == _Phase.playing)
          _circleIcon(Icons.refresh, _restart)
        else
          const SizedBox(width: 38),
      ],
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 19),
        ),
      ),
    );
  }
}

// ── Model thẻ ────────────────────────────────────────────────────────────────

class _CardModel {
  _CardModel({
    required this.pairId,
    required this.emoji,
    required this.image,
    required this.message,
    required this.color,
  });

  final int pairId;
  final String emoji;
  final String image; // đường dẫn asset, vd assets/images/card1.jpg
  final String message;
  final Color color;
  _CardState state = _CardState.down;
}

// ── Thẻ lật 3D ───────────────────────────────────────────────────────────────

/// Lật thẻ quanh trục Y: [faceUp] = true thì xoay để lộ [front], ngược lại [back].
class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.faceUp,
    required this.front,
    required this.back,
  });

  final bool faceUp;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: faceUp ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      builder: (context, t, _) {
        final angle = t * math.pi;
        final showFront = t >= 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(angle),
          child: showFront
              ? Transform(
                  alignment: Alignment.center,
                  // Lật ngược lại để mặt trước không bị soi gương.
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: front,
                )
              : back,
        );
      },
    );
  }
}

/// Lớp phủ ảnh toàn màn hình: fade in (~0.3s) -> giữ 0.5s -> fade out (~0.3s),
/// xong thì gọi [onDone]. Dùng BoxFit.contain để thấy trọn bức ảnh.
class _FullScreenPreview extends StatefulWidget {
  const _FullScreenPreview({required this.image, required this.onDone});

  final String image;
  final VoidCallback onDone;

  @override
  State<_FullScreenPreview> createState() => _FullScreenPreviewState();
}

class _FullScreenPreviewState extends State<_FullScreenPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100), // 0.3 + 0.5 + 0.3
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Độ mờ theo timeline: lên trong 0–0.27, giữ 0.27–0.73, xuống 0.73–1.
  double _fade(double t) {
    const inEnd = 0.27;
    const outStart = 0.73;
    if (t < inEnd) return t / inEnd;
    if (t > outStart) return (1 - t) / (1 - outStart);
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                widget.image,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            ),
          ),
          builder: (context, child) {
            final t = _c.value;
            final op = _fade(t).clamp(0.0, 1.0);
            final scale =
                0.94 + 0.06 * Curves.easeOut.transform((t / 0.4).clamp(0.0, 1.0));
            return Opacity(
              opacity: op,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.92),
                child: Transform.scale(scale: scale, child: child),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPink, _kRose],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: _kRose.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: FittedBox(
            child: Icon(
              Icons.favorite,
              color: Colors.white.withValues(alpha: 0.85),
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({
    required this.emoji,
    required this.image,
    required this.color,
  });

  final String emoji;
  final String image; // đường dẫn asset
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hasImage = image.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: hasImage
            ? Image.asset(
                image,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                // Chưa có file ảnh -> rớt về emoji, không vỡ giao diện.
                errorBuilder: (context, error, stack) => _emojiFace(),
                // Hiện ảnh với hiệu ứng mờ dần cho mượt.
                frameBuilder: (context, child, frame, wasSync) {
                  if (wasSync) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 250),
                    child: child,
                  );
                },
              )
            : _emojiFace(),
      ),
    );
  }

  Widget _emojiFace() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: 0.3), color),
            color,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: FittedBox(
            child: Text(emoji, style: const TextStyle(fontSize: 40)),
          ),
        ),
      ),
    );
  }
}

// ── Hũ kỷ niệm ───────────────────────────────────────────────────────────────

/// Hũ thuỷ tinh: "nước tình yêu" dâng theo số cặp đã ghép, kèm các thông điệp
/// đã thu thập dạng chip. [compact] = true (mobile) thì nằm ngang, gọn ở trên.
class _Jar extends StatelessWidget {
  const _Jar({
    required this.messages,
    required this.total,
    required this.compact,
  });

  final List<String> messages;
  final int total;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fill = total == 0 ? 0.0 : messages.length / total;

    final body = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: _kPink.withValues(alpha: 0.4), width: 1.5),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(12),
          bottom: Radius.circular(24),
        ),
      ),
      child: Stack(
        children: [
          // Nước tình yêu dâng lên theo tiến độ
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 1,
              heightFactor: fill.clamp(0.05, 1.0),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x40F48FB1), Color(0x66E91E63)],
                  ),
                ),
              ),
            ),
          ),
          // Các thông điệp đã thu thập
          if (messages.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  compact ? 'Lật thẻ để thu thập 💌' : 'Lật thẻ để\nthu thập 💌',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(7),
              child: compact
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final m in messages) _chip(m, narrow: true),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [for (final m in messages) _chip(m)],
                      ),
                    ),
            ),
        ],
      ),
    );

    // Mobile: nhãn + nắp + thân thấp (nằm ngang). Desktop: hũ cao bên phải.
    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 9,
                decoration: BoxDecoration(
                  color: _kPink.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '🏺 Hũ kỷ niệm  ${messages.length}/$total',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(height: 64, child: body),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '🏺 Hũ kỷ niệm  ${messages.length}/$total',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 64,
          height: 12,
          decoration: BoxDecoration(
            color: _kPink.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: body),
      ],
    );
  }

  Widget _chip(String message, {bool narrow = false}) {
    final chip = Container(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      constraints: narrow ? const BoxConstraints(maxWidth: 150) : null,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPink.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite, color: _kPink, size: 13),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              maxLines: narrow ? 1 : 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.25),
            ),
          ),
        ],
      ),
    );
    // Hiệu ứng xuất hiện cho chip mới.
    return TweenAnimationBuilder<double>(
      key: ValueKey(message),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.7 + t * 0.3, child: child),
      ),
      child: chip,
    );
  }
}

// ── Hiện lại toàn bộ thông điệp (0 → 11) ─────────────────────────────────────

/// Hiện lần lượt các thông điệp theo đúng thứ tự, mỗi câu trượt + mờ dần vào.
class _RevealList extends StatefulWidget {
  const _RevealList({required this.messages});

  final List<String> messages;

  @override
  State<_RevealList> createState() => _RevealListState();
}

class _RevealListState extends State<_RevealList> {
  int _shown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 240), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_shown >= widget.messages.length) {
        t.cancel();
        return;
      }
      setState(() => _shown++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _shown,
      itemBuilder: (context, i) => _RevealLine(text: widget.messages[i]),
    );
  }
}

class _RevealLine extends StatelessWidget {
  const _RevealLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kPink.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.favorite, color: _kPink, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Màn kết: mưa trái tim ────────────────────────────────────────────────────

/// Mưa trái tim bay tứ tung khắp màn hình rồi fade dần. Xong thì gọi
/// [onComplete] để parent hiện lời nhắn cuối.
class _HeartFinale extends StatefulWidget {
  const _HeartFinale({required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<_HeartFinale> createState() => _HeartFinaleState();
}

class _HeartFinaleState extends State<_HeartFinale>
    with SingleTickerProviderStateMixin {
  static const _count = 56;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  final _rng = math.Random();
  late final List<_HeartParticle> _parts =
      List.generate(_count, (_) => _HeartParticle.random(_rng));

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onComplete();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          children: [for (final p in _parts) p.build(_c.value, size)],
        ),
      ),
    );
  }
}

/// Một trái tim trong màn mưa: bung ra, trôi + lắc nhẹ, rồi mờ dần.
class _HeartParticle {
  _HeartParticle({
    required this.sx,
    required this.sy,
    required this.angle,
    required this.dist,
    required this.upBias,
    required this.size,
    required this.color,
    required this.rot,
    required this.delay,
    required this.sway,
    required this.swayFreq,
    required this.swayPhase,
    required this.baseOpacity,
  });

  final double sx, sy; // điểm xuất phát (tỉ lệ 0..1 theo màn hình)
  final double angle; // hướng bay
  final double dist; // quãng trôi (tỉ lệ màn hình)
  final double upBias; // độ bay lên thêm
  final double size;
  final Color color;
  final double rot; // độ nghiêng
  final double delay; // trễ xuất hiện (0..~0.3 của timeline)
  final double sway, swayFreq, swayPhase; // lắc ngang
  final double baseOpacity;

  static const _palette = [
    Color(0xFFF48FB1),
    Color(0xFFE91E63),
    Color(0xFFFF80AB),
    Color(0xFFFFFFFF),
    Color(0xFFFFC1D6),
    Color(0xFFD81B60),
    Color(0xFFFF4081),
  ];

  factory _HeartParticle.random(math.Random r) {
    return _HeartParticle(
      sx: r.nextDouble(),
      sy: 0.12 + r.nextDouble() * 0.76,
      angle: r.nextDouble() * 2 * math.pi,
      dist: 0.04 + r.nextDouble() * 0.16,
      upBias: 0.08 + r.nextDouble() * 0.16,
      size: 16 + r.nextDouble() * 30,
      color: _palette[r.nextInt(_palette.length)],
      rot: (r.nextDouble() - 0.5) * 0.9,
      delay: r.nextDouble() * 0.3,
      sway: 8 + r.nextDouble() * 26,
      swayFreq: 1 + r.nextDouble() * 2,
      swayPhase: r.nextDouble() * 2 * math.pi,
      baseOpacity: 0.85 + r.nextDouble() * 0.15,
    );
  }

  Widget build(double tAll, Size screen) {
    final p = ((tAll - delay) / (1 - delay)).clamp(0.0, 1.0);
    if (p <= 0) return const SizedBox.shrink();
    final ease = Curves.easeOut.transform(p);

    final dx = math.cos(angle) * dist * screen.width * ease +
        math.sin(p * 2 * math.pi * swayFreq + swayPhase) * sway;
    final dy = (math.sin(angle) * dist - upBias) * screen.height * ease;

    final fadeIn = (p / 0.1).clamp(0.0, 1.0);
    final fadeOut = (1 - (p - 0.55) / 0.45).clamp(0.0, 1.0);
    final opacity = (fadeIn * fadeOut * baseOpacity).clamp(0.0, 1.0);
    final scale = Curves.easeOutBack.transform((p / 0.22).clamp(0.0, 1.0));

    return Positioned(
      left: sx * screen.width + dx - size / 2,
      top: sy * screen.height + dy - size / 2,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: rot,
          child: Transform.scale(
            scale: scale,
            child: Icon(Icons.favorite, color: color, size: size),
          ),
        ),
      ),
    );
  }
}

// ── Trái tim bay nền ─────────────────────────────────────────────────────────

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
        final opacity = (t > 0.72 ? (1.0 - t) / 0.28 : 1.0) * 0.32;
        return Positioned(
          top: top,
          left: left,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Icon(Icons.favorite, color: widget.color, size: _size),
          ),
        );
      },
    );
  }
}
