import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/services/post_image_upload_middleware.dart';
import 'package:graduation_2026/services/storage_service.dart';
import 'package:image/image.dart' as img;

void main() {
  group('PostImageUploadMiddleware', () {
    test('resize/nén rồi upload ảnh vào gốc kho dùng chung', () async {
      final storage = _FakeStorageService();
      final middleware = PostImageUploadMiddleware(storage: storage);
      final original = _largeBmp();

      final result = await middleware.uploadDeviceImage(
        bytes: original,
        filename: 'ảnh từ máy.bmp',
      );

      expect(storage.uploadImageCalled, isTrue);
      expect(storage.uploadPostImageCalled, isFalse);
      expect(storage.uploadedContentType, 'image/jpeg');
      expect(storage.uploadedFilename, endsWith('.jpg'));
      expect(result.image.fullPath, storage.uploadedFilename);
      expect(result.originalSize, original.lengthInBytes);
      expect(result.storedSize, storage.uploadedBytes!.lengthInBytes);

      final decoded = img.decodeImage(storage.uploadedBytes!);
      expect(decoded, isNotNull);
      expect(
        decoded!.width,
        lessThanOrEqualTo(PostImageUploadMiddleware.maxDimension),
      );
      expect(
        decoded.height,
        lessThanOrEqualTo(PostImageUploadMiddleware.maxDimension),
      );
      expect(result.storedSize, lessThan(result.originalSize));
    });
  });

  group('bảo vệ ảnh kho dùng chung', () {
    test('chỉ nhận đường dẫn posts/ là ảnh bài viết sở hữu riêng', () {
      expect(StorageService.isPostOwnedImagePath('posts/123_a.jpg'), isTrue);
      expect(StorageService.isPostOwnedImagePath('123_a.jpg'), isFalse);
      expect(StorageService.isPostOwnedImagePath('posts-old/a.jpg'), isFalse);
    });

    test('deletePostImages lọc bỏ ảnh dùng chung trước khi xóa', () async {
      final storage = _FakeStorageService();

      await storage.deletePostImages([
        'posts/old-a.jpg',
        'shared-a.jpg',
        'posts/old-b.jpg',
      ]);

      expect(storage.deletedPaths, ['posts/old-a.jpg', 'posts/old-b.jpg']);
    });
  });
}

Uint8List _largeBmp() {
  final image = img.Image(width: 2200, height: 300);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgb(
        x,
        y,
        (x * 31 + y * 17) % 256,
        (x * 13 + y * 29) % 256,
        (x * 7 + y * 37) % 256,
      );
    }
  }
  return img.encodeBmp(image);
}

class _FakeStorageService extends StorageService {
  bool uploadImageCalled = false;
  bool uploadPostImageCalled = false;
  Uint8List? uploadedBytes;
  String? uploadedFilename;
  String? uploadedContentType;
  List<String>? deletedPaths;

  @override
  Future<GalleryImage> uploadImage({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    uploadImageCalled = true;
    uploadedBytes = bytes;
    uploadedFilename = filename;
    uploadedContentType = contentType;
    return GalleryImage(
      name: filename,
      fullPath: filename,
      url: 'url/$filename',
    );
  }

  @override
  Future<GalleryImage> uploadPostImage({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    uploadPostImageCalled = true;
    throw StateError('Không được upload vào posts/');
  }

  @override
  Future<void> deleteImages(List<String> fullPaths) async {
    deletedPaths = fullPaths;
  }
}
