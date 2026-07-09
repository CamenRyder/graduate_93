import 'dart:async';

import 'package:flutter/widgets.dart';

/// Tải trước (precache) ảnh mạng vào [ImageCache] dùng chung của app.
///
/// Mục đích: khi admin mở kho ảnh, tải ngầm sẵn ảnh của từng thư mục để lúc
/// bấm vào thư mục thì thumbnail hiện tức thì thay vì quay spinner.
///
/// Đặc điểm:
/// - Singleton dùng chung cả phiên ([ImagePrecacheService.instance]).
/// - Chạy nền với số request đồng thời nhỏ ([_maxConcurrent]) để không
///   chiếm hết băng thông của ảnh đang hiển thị trên màn hình.
/// - Nhớ các URL đã tải xong trong 1 [Set] — không bao giờ tải lại lần 2.
/// - Có thể hủy phần chưa chạy ([cancelPending]) hoặc chen hàng ưu tiên
///   (`priority: true`) khi người dùng mở 1 thư mục cụ thể.
class ImagePrecacheService {
  ImagePrecacheService._();

  /// Instance dùng chung cho cả phiên làm việc.
  static final ImagePrecacheService instance = ImagePrecacheService._();

  /// Số ảnh tải đồng thời tối đa — giữ nhỏ (3) cho "lịch sự" với mạng.
  static const int _maxConcurrent = 3;

  /// URL đã tải xong (hoặc đã thử và lỗi) trong phiên này -> không tải lại.
  final Set<String> _done = <String>{};

  /// Hàng đợi URL chờ tải (không trùng với [_done] và không trùng nhau).
  final List<String> _queue = <String>[];

  /// Số request đang chạy.
  int _inFlight = 0;

  /// Cấu hình ảnh (devicePixelRatio...) chụp từ context lần schedule gần nhất
  /// — nhờ vậy tác vụ trong hàng đợi không phụ thuộc context còn sống hay không.
  ImageConfiguration _config = ImageConfiguration.empty;

  /// Xếp [urls] vào hàng đợi tải trước. URL đã cache / đang chờ sẽ bị bỏ qua.
  /// [priority] = true -> chen lên ĐẦU hàng đợi (dùng khi mở 1 thư mục:
  /// ảnh của thư mục đó cần sớm hơn các thư mục khác đang chờ).
  void schedule(
    BuildContext context,
    Iterable<String> urls, {
    bool priority = false,
  }) {
    _config = createLocalImageConfiguration(context);
    final fresh = urls
        .where((u) => u.isNotEmpty && !_done.contains(u) && !_queue.contains(u))
        .toList();
    if (fresh.isEmpty) return;
    if (priority) {
      _queue.insertAll(0, fresh);
    } else {
      _queue.addAll(fresh);
    }
    _pump();
  }

  /// Hủy toàn bộ URL CHƯA chạy (request đang chạy dở vẫn chạy nốt).
  /// URL bị hủy có thể được schedule lại sau vì chưa nằm trong [_done].
  void cancelPending() => _queue.clear();

  /// Rút URL từ hàng đợi ra chạy, tối đa [_maxConcurrent] request song song.
  void _pump() {
    while (_inFlight < _maxConcurrent && _queue.isNotEmpty) {
      final url = _queue.removeAt(0);
      _inFlight++;
      _fetch(url).whenComplete(() {
        _inFlight--;
        _pump();
      });
    }
  }

  /// Tải 1 ảnh vào [ImageCache] rồi đánh dấu đã xong. Lỗi cũng đánh dấu xong
  /// để không lặp lại request hỏng suốt phiên (F5 trang là thử lại được).
  Future<void> _fetch(String url) {
    final completer = Completer<void>();
    final stream = NetworkImage(url).resolve(_config);
    late final ImageStreamListener listener;

    void finish() {
      _done.add(url);
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    }

    listener = ImageStreamListener(
      (info, _) {
        // Cache toàn cục đã giữ ảnh; nhả handle của listener này ra.
        info.dispose();
        finish();
      },
      onError: (_, _) => finish(),
    );
    stream.addListener(listener);
    return completer.future;
  }
}
