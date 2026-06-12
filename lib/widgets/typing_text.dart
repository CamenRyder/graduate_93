import 'dart:async';

import 'package:flutter/material.dart';

/// Text hiện dần từng ký tự như đang gõ (kiểu typewriter).
///
/// Phần chưa gõ tới vẫn được vẽ nhưng trong suốt, nên kích thước widget
/// luôn bằng đúng text đầy đủ -> layout không bị nhảy trong lúc gõ.
/// Khi [text] đổi (vd: lời nhắn -> thông báo lỗi) sẽ tự gõ lại từ đầu.
class TypingText extends StatefulWidget {
  const TypingText(
    this.text, {
    super.key,
    this.style,
    this.charDuration = const Duration(milliseconds: 30),
  });

  final String text;
  final TextStyle? style;

  /// Khoảng cách giữa 2 ký tự.
  final Duration charDuration;

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  // Tách theo grapheme (ký tự hiển thị) để không cắt đôi dấu tiếng Việt.
  late List<String> _chars;
  int _shown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(TypingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _chars = widget.text.characters.toList();
    _shown = 0;
    _timer = Timer.periodic(widget.charDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _shown++);
      if (_shown >= _chars.length) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final typed = _chars.take(_shown).join();
    final rest = _chars.skip(_shown).join();

    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: typed),
          TextSpan(
            text: rest,
            style: const TextStyle(color: Colors.transparent),
          ),
        ],
      ),
    );
  }
}
