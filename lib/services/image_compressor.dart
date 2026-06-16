import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Kết quả nén ảnh: bytes + tên file + content-type sau khi xử lý.
class CompressedImage {
  const CompressedImage({
    required this.bytes,
    required this.filename,
    required this.contentType,
    required this.originalSize,
  });

  final Uint8List bytes;
  final String filename;
  final String contentType;

  /// Dung lượng ảnh gốc (byte) — để báo cho người dùng mức giảm.
  final int originalSize;

  int get compressedSize => bytes.lengthInBytes;
}

/// Nén ảnh phía client (thuần Dart, chạy được trên web) theo "dung lượng
/// mục tiêu": giữ độ phân giải cao + chất lượng cao, rồi tự HẠ DẦN chất lượng
/// cho tới khi file xuống dưới [targetBytes] (hoặc chạm [minQuality]).
///
///  - Thu nhỏ nếu cạnh dài hơn [maxDimension] px (mặc định 2560 — giữ chi tiết).
///  - Bắt đầu ở [startQuality] cao, giảm theo bước cho tới khi đạt [targetBytes].
///
/// An toàn: bỏ qua **GIF** (giữ ảnh động); nếu không giải mã được, hoặc kết quả
/// KHÔNG nhỏ hơn bản gốc → trả lại ảnh gốc.
Future<CompressedImage> compressImage(
  Uint8List original,
  String filename, {
  int maxDimension = 2560,
  int targetBytes = 2 * 1024 * 1024, // ~2MB
  int startQuality = 90,
  int minQuality = 70,
}) async {
  final lower = filename.toLowerCase();
  final originalSize = original.lengthInBytes;

  CompressedImage keepOriginal() => CompressedImage(
        bytes: original,
        filename: filename,
        contentType: _guessContentType(lower),
        originalSize: originalSize,
      );

  // GIF có thể là ảnh động -> không nén để khỏi mất hiệu ứng.
  if (lower.endsWith('.gif')) return keepOriginal();

  final decoded = img.decodeImage(original);
  if (decoded == null) return keepOriginal();

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

  // Mã hóa lại, hạ chất lượng dần cho tới khi đạt mục tiêu dung lượng.
  Uint8List best = img.encodeJpg(image, quality: startQuality);
  for (var q = startQuality; q >= minQuality; q -= 8) {
    final encoded = img.encodeJpg(image, quality: q);
    best = encoded;
    if (encoded.lengthInBytes <= targetBytes) break;
  }

  // Nếu nén không lợi (ảnh đã nhỏ/đã nén tốt) -> giữ bản gốc.
  if (best.lengthInBytes >= originalSize) return keepOriginal();

  return CompressedImage(
    bytes: best,
    filename: _withJpgExtension(filename),
    contentType: 'image/jpeg',
    originalSize: originalSize,
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
