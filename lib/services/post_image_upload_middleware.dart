import 'dart:typed_data';

import 'image_compressor.dart';
import 'storage_service.dart';

/// Kết quả của pipeline xử lý ảnh chọn từ thiết bị trong trình soạn bài.
class PostImageUploadResult {
  const PostImageUploadResult({
    required this.image,
    required this.originalSize,
    required this.storedSize,
  });

  final GalleryImage image;
  final int originalSize;
  final int storedSize;
}

/// Middleware bắt buộc cho ảnh được chọn từ thiết bị khi viết bài.
///
/// Ảnh luôn đi qua bước resize/nén trước khi được upload vào KHO ẢNH CHUNG
/// (gốc bucket, không phải `posts/`). Tên ảnh mới là duy nhất nên mặc định
/// không có metadata màu/thư mục, tương ứng "Không xác định/Chưa phân loại"
/// trong kho ảnh.
class PostImageUploadMiddleware {
  PostImageUploadMiddleware({StorageService? storage})
    : _storage = storage ?? StorageService();

  static const int maxDimension = 1920;
  static const int targetBytes = 1024 * 1024;

  final StorageService _storage;

  Future<PostImageUploadResult> uploadDeviceImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final compressed = await compressImage(
      bytes,
      filename,
      maxDimension: maxDimension,
      targetBytes: targetBytes,
      startQuality: 86,
      minQuality: 62,
      preserveAnimatedGif: false,
    );

    // Dùng uploadImage (gốc bucket) để ảnh xuất hiện trong kho dùng chung.
    // Không ghi GalleryMeta nên ảnh ở trạng thái chưa phân loại/không màu.
    final image = await _storage.uploadImage(
      bytes: compressed.bytes,
      filename: compressed.filename,
      contentType: compressed.contentType,
    );

    return PostImageUploadResult(
      image: image,
      originalSize: compressed.originalSize,
      storedSize: compressed.compressedSize,
    );
  }
}
