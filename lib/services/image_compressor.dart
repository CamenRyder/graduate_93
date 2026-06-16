import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Kết quả nén ảnh: bytes + tên file + content-type sau khi xử lý.
class CompressedImage {
  const CompressedImage({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final Uint8List bytes;
  final String filename;
  final String contentType;
}

/// Nén ảnh phía client (thuần Dart, chạy được trên web):
///  - Thu nhỏ nếu cạnh dài hơn [maxDimension] px.
///  - Mã hóa lại JPEG với [quality] (0–100).
///
/// An toàn: nếu không giải mã được (vd định dạng lạ), hoặc là **GIF** (giữ
/// ảnh động), hoặc kết quả nén KHÔNG nhỏ hơn bản gốc → trả lại ảnh gốc.
Future<CompressedImage> compressImage(
  Uint8List original,
  String filename, {
  int maxDimension = 1920,
  int quality = 80,
}) async {
  final lower = filename.toLowerCase();

  // GIF có thể là ảnh động -> không nén để khỏi mất hiệu ứng.
  if (lower.endsWith('.gif')) {
    return CompressedImage(
      bytes: original,
      filename: filename,
      contentType: 'image/gif',
    );
  }

  final decoded = img.decodeImage(original);
  if (decoded == null) {
    // Không giải mã được -> giữ nguyên, để Supabase tự xử lý content-type.
    return CompressedImage(
      bytes: original,
      filename: filename,
      contentType: _guessContentType(lower),
    );
  }

  // Thu nhỏ theo cạnh dài, giữ tỉ lệ.
  var image = decoded;
  if (image.width > maxDimension || image.height > maxDimension) {
    final landscape = image.width >= image.height;
    image = img.copyResize(
      image,
      width: landscape ? maxDimension : null,
      height: landscape ? null : maxDimension,
    );
  }

  final jpg = img.encodeJpg(image, quality: quality);

  // Nếu nén không lợi (ảnh đã nhỏ/đã nén tốt) -> giữ bản gốc.
  if (jpg.lengthInBytes >= original.lengthInBytes) {
    return CompressedImage(
      bytes: original,
      filename: filename,
      contentType: _guessContentType(lower),
    );
  }

  return CompressedImage(
    bytes: jpg,
    filename: _withJpgExtension(filename),
    contentType: 'image/jpeg',
  );
}

/// Đổi đuôi file thành .jpg (vì đã mã hóa lại sang JPEG).
String _withJpgExtension(String filename) {
  final dot = filename.lastIndexOf('.');
  final base = dot == -1 ? filename : filename.substring(0, dot);
  return '$base.jpg';
}

String _guessContentType(String lower) {
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.bmp')) return 'image/bmp';
  return 'image/jpeg';
}
