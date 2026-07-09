import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_config.dart';

/// 1 ảnh trong gallery (đọc từ Supabase Storage).
class GalleryImage {
  const GalleryImage({
    required this.name,
    required this.fullPath,
    required this.url,
  });

  /// Tên file hiển thị (vd "1718500000000_so-do.png").
  final String name;

  /// Đường dẫn trong bucket (dùng để xóa). Ở đây trùng với [name] vì lưu phẳng.
  final String fullPath;

  /// Link công khai để hiển thị ảnh.
  final String url;
}

/// Lớp truy cập Supabase Storage cho bucket `gallery`.
///
/// Dùng cho tính năng "kho ảnh": admin upload ảnh, app hiển thị lại để
/// sau này tái sử dụng (vd cho blog).
///
/// LƯU Ý: cần tạo bucket [SupabaseConfig.galleryBucket] (đặt Public để đọc
/// công khai) + cấu hình Storage policies cho phép upload/list/xóa.
class StorageService {
  /// Tiền tố "thư mục" chứa ảnh của BÀI VIẾT trong bucket (tách khỏi kho
  /// ảnh gallery vốn lưu phẳng ở gốc bucket).
  static const String postsPrefix = 'posts';

  SupabaseStorageClient get _storage => Supabase.instance.client.storage;

  String get _bucket => SupabaseConfig.galleryBucket;

  /// Upload 1 ảnh từ bytes lên bucket với tên `<timestamp>_<filename>`.
  /// Trả về [GalleryImage] vừa tạo (đã có link công khai).
  Future<GalleryImage> uploadImage({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) {
    return _uploadTo(
      path: _stampedName(filename),
      bytes: bytes,
      contentType: contentType,
    );
  }

  /// Upload 1 ảnh cho BÀI VIẾT: lưu dưới `posts/<timestamp>_<filename>`
  /// (cùng cách làm sạch tên + đoán content-type với [uploadImage]).
  Future<GalleryImage> uploadPostImage({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) {
    return _uploadTo(
      path: '$postsPrefix/${_stampedName(filename)}',
      bytes: bytes,
      contentType: contentType,
    );
  }

  /// Tên file an toàn kèm tiền tố timestamp để không trùng và giữ thứ tự upload.
  String _stampedName(String filename) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = filename.replaceAll(RegExp(r'[^\w.\-]'), '_');
    return '${stamp}_$safeName';
  }

  /// Upload bytes lên [path] trong bucket rồi trả về [GalleryImage] tương ứng.
  Future<GalleryImage> _uploadTo({
    required String path,
    required Uint8List bytes,
    String? contentType,
  }) async {
    await _storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType ?? _guessContentType(path),
            upsert: false,
          ),
        );

    return GalleryImage(
      name: path.split('/').last,
      fullPath: path,
      url: _storage.from(_bucket).getPublicUrl(path),
    );
  }

  /// Liệt kê toàn bộ ảnh Ở GỐC bucket (kho ảnh gallery), mới nhất lên đầu.
  /// Ảnh bài viết nằm trong "thư mục" `posts/` nên không lẫn vào đây.
  Future<List<GalleryImage>> listImages() async {
    final objects = await _storage.from(_bucket).list(
          searchOptions: const SearchOptions(
            // Supabase trả tối đa 100 mặc định; nâng lên cho kho lớn hơn.
            limit: 1000,
            sortBy: SortBy(column: 'name', order: 'desc'),
          ),
        );

    return objects
        // Bỏ qua:
        //  - "thư mục" con (vd `posts/` chứa ảnh bài viết) — Supabase trả
        //    folder như 1 entry có `id` null;
        //  - "thư mục giữ chỗ" rỗng nếu có (.emptyFolderPlaceholder).
        .where((o) => o.id != null && o.name != '.emptyFolderPlaceholder')
        .map(
          (o) => GalleryImage(
            name: o.name,
            fullPath: o.name,
            url: _storage.from(_bucket).getPublicUrl(o.name),
          ),
        )
        .toList();
  }

  /// Xóa 1 ảnh theo đường dẫn trong bucket.
  Future<void> deleteImage(String fullPath) {
    return _storage.from(_bucket).remove([fullPath]);
  }

  /// Xóa NHIỀU ảnh cùng lúc (1 request).
  Future<void> deleteImages(List<String> fullPaths) {
    if (fullPaths.isEmpty) return Future.value();
    return _storage.from(_bucket).remove(fullPaths);
  }

  /// Xóa ảnh của BÀI VIẾT (đường dẫn dạng `posts/...` lưu trong field `path`
  /// của khối ảnh) — gọi khi gỡ 1 khối ảnh hoặc xóa cả bài viết.
  Future<void> deletePostImages(List<String> fullPaths) =>
      deleteImages(fullPaths);

  /// Tải bytes của 1 ảnh từ bucket (dùng để lưu ảnh về máy / đóng gói ZIP).
  Future<Uint8List> downloadBytes(String fullPath) {
    return _storage.from(_bucket).download(fullPath);
  }

  /// Đoán Content-Type theo đuôi file để ảnh mở đúng trên trình duyệt.
  String _guessContentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }
}
