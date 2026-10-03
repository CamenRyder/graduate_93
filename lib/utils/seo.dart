/// Dữ liệu SEO dùng chung cho meta lúc chạy (lib/services/page_meta.dart) và
/// HTML tĩnh lúc build (tool/prerender.dart).
///
/// File này chỉ dùng Dart thuần — KHÔNG import Flutter/Firebase — để script
/// `dart run tool/prerender.dart` import lại được.
library;

const String siteName = 'Minh Hiếu — Notes';

/// Domain chính thức: canonical, og:url và sitemap đều trỏ về đây.
const String siteUrl = 'https://graduation-e59ff.web.app';

const String defaultDescription =
    'Ghi chép của Minh Hiếu về công nghệ, sản phẩm và những điều học được '
    'trong quá trình xây dựng.';

/// Mô tả trang kho bài viết `/posts`.
const String archiveDescription =
    'Những bài viết dài, ghi chú kỹ thuật và điều mình học được trong quá '
    'trình xây dựng sản phẩm.';

/// Mô tả trang thẻ `/tags/<slug>`.
String tagDescription(String tag) => 'Các bài viết gắn thẻ $tag.';

/// Bộ meta của một trang.
class SeoMeta {
  const SeoMeta({
    required this.path,
    this.title = '',
    this.description = '',
    this.imageUrl = '',
    this.isArticle = false,
  });

  /// Đường dẫn tuyệt đối trong site, vd `/posts/abc/tieu-de`.
  final String path;
  final String title;
  final String description;
  final String imageUrl;
  final bool isArticle;

  /// Tiêu đề hiển thị trên tab / kết quả tìm kiếm.
  String get fullTitle =>
      title.trim().isEmpty ? siteName : '${title.trim()} — $siteName';

  String get resolvedDescription =>
      description.trim().isEmpty ? defaultDescription : description.trim();

  String get canonicalUrl => '$siteUrl$path';

  /// Các thẻ `<meta>` theo thuộc tính (`name` hoặc `property`) -> nội dung.
  /// Thứ tự cố định để HTML sinh ra ổn định giữa các lần build.
  List<({String attribute, String key, String content})> get tags => [
    (attribute: 'name', key: 'description', content: resolvedDescription),
    (attribute: 'property', key: 'og:site_name', content: siteName),
    (
      attribute: 'property',
      key: 'og:type',
      content: isArticle ? 'article' : 'website',
    ),
    (attribute: 'property', key: 'og:title', content: fullTitle),
    (
      attribute: 'property',
      key: 'og:description',
      content: resolvedDescription,
    ),
    (attribute: 'property', key: 'og:url', content: canonicalUrl),
    (attribute: 'property', key: 'og:image', content: imageUrl),
    (
      attribute: 'name',
      key: 'twitter:card',
      content: imageUrl.isEmpty ? 'summary' : 'summary_large_image',
    ),
    (attribute: 'name', key: 'twitter:title', content: fullTitle),
    (
      attribute: 'name',
      key: 'twitter:description',
      content: resolvedDescription,
    ),
    (attribute: 'name', key: 'twitter:image', content: imageUrl),
  ];
}

/// Rút gọn [text] còn tối đa [maxLength] ký tự, cắt ở ranh giới từ và thêm "…".
String summarize(String text, {int maxLength = 160}) {
  final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (clean.length <= maxLength) return clean;
  final cut = clean.substring(0, maxLength - 1);
  final lastSpace = cut.lastIndexOf(' ');
  final head = lastSpace > maxLength ~/ 2 ? cut.substring(0, lastSpace) : cut;
  return '${head.trimRight()}…';
}
