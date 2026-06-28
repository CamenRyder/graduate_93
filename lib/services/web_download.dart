import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Kích hoạt trình duyệt tải [bytes] xuống máy người dùng dưới tên [filename].
///
/// Dự án chạy Flutter web nên việc "lưu file về máy" được làm bằng cách tạo một
/// Blob trong bộ nhớ rồi "bấm" vào một thẻ `<a download>` ẩn. Cách này hoạt
/// động với mọi loại dữ liệu (ảnh, file ZIP...) và không phụ thuộc CORS như khi
/// trỏ thẳng `href` tới URL chéo miền.
void downloadBytesToDevice(
  Uint8List bytes,
  String filename, {
  String mimeType = 'application/octet-stream',
}) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  // Một số trình duyệt (Firefox) yêu cầu thẻ phải nằm trong DOM mới tải được.
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // Giải phóng URL tạm sau một nhịp để trình duyệt kịp bắt đầu tải xong.
  Future<void>.delayed(
    const Duration(seconds: 30),
    () => web.URL.revokeObjectURL(url),
  );
}
