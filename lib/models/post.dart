import 'package:cloud_firestore/cloud_firestore.dart';

/// Loại khối nội dung trong 1 bài viết.
enum PostBlockType {
  /// Đề mục lớn (chữ to, in đậm).
  heading,

  /// Đề mục phụ (chữ vừa, in đậm).
  subheading,

  /// Đoạn văn thường.
  paragraph,

  /// Trích dẫn (viền trái + in nghiêng).
  quote,

  /// Ảnh (file nằm ở Supabase Storage, Firestore chỉ lưu link + đường dẫn).
  image;

  /// Nhãn tiếng Việt hiển thị trong menu chọn loại khối.
  String get label => switch (this) {
        PostBlockType.heading => 'Đề mục',
        PostBlockType.subheading => 'Đề mục phụ',
        PostBlockType.paragraph => 'Đoạn văn',
        PostBlockType.quote => 'Trích dẫn',
        PostBlockType.image => 'Ảnh',
      };

  /// Khối văn bản (mọi loại trừ ảnh) — có `text` + có thể tô màu nền.
  bool get isText => this != PostBlockType.image;

  /// Các loại khối VĂN BẢN — dùng cho menu đổi loại trong trình soạn.
  static const List<PostBlockType> textTypes = [
    heading,
    subheading,
    paragraph,
    quote,
  ];

  /// Đọc lại loại khối từ chuỗi lưu trên Firestore; loại lạ/thiếu thì coi
  /// như đoạn văn để bài viết cũ không làm crash app.
  static PostBlockType fromName(String? name) {
    for (final t in PostBlockType.values) {
      if (t.name == name) return t;
    }
    return PostBlockType.paragraph;
  }
}

/// 1 khối nội dung của bài viết (phần tử trong mảng `blocks` của document).
///
/// - Khối văn bản: dùng [text] + [highlight] (khóa màu nền của RowPalette,
///   rỗng = không tô — lưu khóa ngữ nghĩa để tự hợp cả theme Sáng lẫn Tối).
/// - Khối ảnh: dùng [url] (link công khai để hiển thị) + [path] (đường dẫn
///   trong bucket Supabase, giữ lại để xóa file khi gỡ ảnh / xóa bài).
class PostBlock {
  const PostBlock({
    required this.type,
    this.text = '',
    this.url = '',
    this.path = '',
    this.highlight = '',
  });

  final PostBlockType type;
  final String text;
  final String url;
  final String path;
  final String highlight;

  /// Tạo [PostBlock] từ 1 map trong mảng `blocks` (đọc an toàn, field thiếu
  /// hoặc sai kiểu thì dùng giá trị mặc định).
  factory PostBlock.fromMap(Map<String, dynamic> map) {
    return PostBlock(
      type: PostBlockType.fromName(map['type']?.toString()),
      text: map['text']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
      path: map['path']?.toString() ?? '',
      highlight: map['highlight']?.toString() ?? '',
    );
  }

  /// Chuyển ngược lại thành map để ghi lên Firestore — chỉ ghi các field
  /// đúng với loại khối để document gọn gàng.
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      if (type.isText) 'text': text,
      if (type.isText && highlight.isNotEmpty) 'highlight': highlight,
      if (!type.isText) 'url': url,
      if (!type.isText) 'path': path,
    };
  }
}

/// Model ứng với 1 document trong collection `posts` trên Firestore.
class Post {
  const Post({
    required this.id,
    required this.title,
    required this.published,
    required this.blocks,
    required this.timeCreated,
    required this.timeUpdated,
  });

  /// ID của document (Firestore tự sinh).
  final String id;

  /// Tiêu đề bài viết.
  final String title;

  /// `true` = đã đăng (khách xem được); `false` = bản nháp (chỉ admin thấy).
  final bool published;

  /// Danh sách khối nội dung theo đúng thứ tự hiển thị.
  final List<PostBlock> blocks;

  final DateTime? timeCreated;
  final DateTime? timeUpdated;

  /// Tạo [Post] từ 1 document Firestore (đọc an toàn như [AppUser]).
  factory Post.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawBlocks = data['blocks'] as List? ?? const [];
    return Post(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      published: data['published'] as bool? ?? false,
      blocks: [
        for (final b in rawBlocks)
          if (b is Map) PostBlock.fromMap(Map<String, dynamic>.from(b)),
      ],
      timeCreated: (data['time_created'] as Timestamp?)?.toDate(),
      timeUpdated: (data['time_updated'] as Timestamp?)?.toDate(),
    );
  }

  /// Chuyển thành Map để ghi lên Firestore. KHÔNG kèm timestamps —
  /// PostService tự chèn `FieldValue.serverTimestamp()` lúc tạo/cập nhật.
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'published': published,
      'blocks': [for (final b in blocks) b.toMap()],
    };
  }

  /// Link ảnh đầu tiên trong bài — dùng làm ảnh bìa cho thẻ danh sách.
  /// Rỗng nếu bài không có ảnh.
  String get coverUrl {
    for (final b in blocks) {
      if (b.type == PostBlockType.image && b.url.isNotEmpty) return b.url;
    }
    return '';
  }

  /// Đoạn văn bản (không rỗng) đầu tiên — dùng làm trích đoạn cho thẻ
  /// danh sách. Rỗng nếu bài chưa có chữ nào.
  String get snippet {
    for (final b in blocks) {
      if (b.type.isText && b.text.trim().isNotEmpty) return b.text.trim();
    }
    return '';
  }

  /// Đường dẫn Storage của toàn bộ khối ảnh — để xóa file khi xóa bài viết.
  List<String> get imagePaths => [
        for (final b in blocks)
          if (b.type == PostBlockType.image && b.path.isNotEmpty) b.path,
      ];
}
