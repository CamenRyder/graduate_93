import 'share_service_stub.dart'
    if (dart.library.js_interop) 'share_service_web.dart'
    as impl;

/// Chia sẻ qua trình duyệt: Web Share API (menu chia sẻ của hệ điều hành,
/// chủ yếu trên điện thoại) và mở cửa sổ chia sẻ của mạng xã hội. Ngoài web
/// (test VM) không hỗ trợ gì.
class ShareService {
  const ShareService();

  /// Trình duyệt có `navigator.share` hay không.
  bool get canShareNatively => impl.canShareNatively();

  /// Mở menu chia sẻ của hệ điều hành. Trả `false` nếu không hỗ trợ hoặc
  /// người dùng hủy.
  Future<bool> shareNatively({required String title, required String url}) =>
      impl.shareNatively(title: title, url: url);

  /// Mở [url] ở tab/cửa sổ mới.
  void openWindow(String url) => impl.openWindow(url);
}
