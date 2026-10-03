/// Logic thuần (không I/O) cho tool/prerender.dart: đọc document Firestore
/// REST, sinh khối meta, sitemap và robots. Tách ra đây để unit test được.
///
/// Chỉ dùng Dart thuần — KHÔNG import Flutter/Firebase.
library;

import 'dart:convert';

import 'post_slug.dart';
import 'seo.dart';

const seoStartMarker = '<!-- seo:start';
const seoEndMarker = '<!-- seo:end -->';
const noscriptMarker = '<!-- seo:noscript -->';

/// Các route không nên được index (luồng thiệp mời và quản trị).
const privatePaths = [
  '/admin',
  '/login',
  '/auth',
  '/welcome',
  '/invite',
  '/scheduled',
  '/guide',
  '/photos',
  '/gallery',
  '/countdown',
  '/love',
];

/// Bài viết đã rút gọn đủ cho SEO.
class SeoPost {
  const SeoPost({
    required this.id,
    required this.title,
    required this.published,
    required this.summary,
    this.imageUrl = '',
    this.categoryId = '',
    this.created,
    this.updated,
  });

  final String id;
  final String title;
  final bool published;
  final String summary;
  final String imageUrl;
  final String categoryId;
  final DateTime? created;
  final DateTime? updated;

  String get path => postDetailPath(id: id, title: title);

  SeoMeta get meta => SeoMeta(
    path: path,
    title: title,
    description: summary,
    imageUrl: imageUrl,
    isArticle: true,
  );
}

class SeoCategory {
  const SeoCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.visible = true,
  });

  final String id;
  final String name;
  final String description;
  final bool visible;

  String get path => '/categories/$id';
}

// ---------------------------------------------------------------------------
// Firestore REST -> model
// ---------------------------------------------------------------------------

String _docId(Map<String, dynamic> doc) =>
    (doc['name'] as String? ?? '').split('/').last;

Map<String, dynamic> _fields(Map<String, dynamic> doc) =>
    (doc['fields'] as Map?)?.cast<String, dynamic>() ?? const {};

String _string(Map<String, dynamic> fields, String key) =>
    (fields[key] as Map?)?['stringValue']?.toString() ?? '';

bool? _bool(Map<String, dynamic> fields, String key) =>
    (fields[key] as Map?)?['booleanValue'] as bool?;

DateTime? _time(Map<String, dynamic> fields, String key) {
  final raw = (fields[key] as Map?)?['timestampValue']?.toString();
  return raw == null ? null : DateTime.tryParse(raw);
}

/// Đọc 1 document `posts` theo định dạng Firestore REST v1.
///
/// Tóm tắt dùng cùng quy tắc với `Post.snippet`: ưu tiên đoạn văn/trích dẫn,
/// không có thì lấy các khối văn bản khác trừ code.
SeoPost postFromRest(Map<String, dynamic> doc) {
  final fields = _fields(doc);
  final blocks = [
    for (final value
        in ((fields['blocks'] as Map?)?['arrayValue'] as Map?)?['values']
                as List? ??
            const [])
      ((value as Map)['mapValue'] as Map?)?['fields'] as Map? ?? const {},
  ].map((b) => b.cast<String, dynamic>()).toList();

  String type(Map<String, dynamic> b) => _string(b, 'type');
  String text(Map<String, dynamic> b) => _string(b, 'text').trim();

  var prose = blocks
      .where((b) => {'paragraph', 'quote'}.contains(type(b)))
      .map(text)
      .where((t) => t.isNotEmpty)
      .join(' ');
  if (prose.isEmpty) {
    prose = blocks
        .where((b) => !{'image', 'code'}.contains(type(b)))
        .map(text)
        .where((t) => t.isNotEmpty)
        .join(' ');
  }
  final cover = blocks
      .where((b) => type(b) == 'image')
      .map((b) => _string(b, 'url'))
      .firstWhere((url) => url.isNotEmpty, orElse: () => '');

  return SeoPost(
    id: _docId(doc),
    title: _string(fields, 'title'),
    published: _bool(fields, 'published') ?? false,
    summary: summarize(prose),
    imageUrl: cover,
    categoryId: _string(fields, 'category_id'),
    created: _time(fields, 'time_created'),
    updated: _time(fields, 'time_updated'),
  );
}

SeoCategory categoryFromRest(Map<String, dynamic> doc) {
  final fields = _fields(doc);
  return SeoCategory(
    id: _docId(doc),
    name: _string(fields, 'name').trim(),
    description: _string(fields, 'description').trim(),
    visible: _bool(fields, 'visible') ?? true,
  );
}

// ---------------------------------------------------------------------------
// HTML
// ---------------------------------------------------------------------------

/// Escape cho cả nội dung text lẫn giá trị thuộc tính.
String escapeHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// Khối thẻ thay vào giữa `seo:start` … `seo:end` của index.html.
String renderSeoBlock(SeoMeta meta, {String jsonLd = ''}) {
  final lines = <String>[
    '<!-- seo:start (prerender) -->',
    '<title>${escapeHtml(meta.fullTitle)}</title>',
    '<link rel="canonical" href="${escapeHtml(meta.canonicalUrl)}">',
    for (final tag in meta.tags)
      if (tag.content.isNotEmpty)
        '<meta ${tag.attribute}="${tag.key}" content="${escapeHtml(tag.content)}">',
    if (jsonLd.isNotEmpty)
      // Chặn "</script" trong dữ liệu để không đóng thẻ sớm.
      '<script type="application/ld+json">${jsonLd.replaceAll('</', '<\\/')}</script>',
    seoEndMarker,
  ];
  return lines.join('\n  ');
}

/// JSON-LD `BlogPosting` cho trang bài viết.
String articleJsonLd(SeoPost post) {
  final meta = post.meta;
  return jsonEncode({
    '@context': 'https://schema.org',
    '@type': 'BlogPosting',
    'headline': post.title,
    if (post.summary.isNotEmpty) 'description': post.summary,
    'url': meta.canonicalUrl,
    'mainEntityOfPage': meta.canonicalUrl,
    if (post.imageUrl.isNotEmpty) 'image': post.imageUrl,
    if (post.created != null)
      'datePublished': post.created!.toUtc().toIso8601String(),
    if ((post.updated ?? post.created) != null)
      'dateModified': (post.updated ?? post.created)!.toUtc().toIso8601String(),
    'author': {'@type': 'Person', 'name': 'Minh Hiếu'},
    'publisher': {'@type': 'Person', 'name': 'Minh Hiếu'},
  });
}

/// Thay khối meta mặc định trong [indexHtml] và chèn nội dung `<noscript>`.
///
/// Ném [FormatException] nếu thiếu marker — nghĩa là web/index.html đã bị đổi
/// và script cần cập nhật, tốt hơn là âm thầm sinh HTML sai.
String applySeo(
  String indexHtml,
  SeoMeta meta, {
  String jsonLd = '',
  String noscriptHtml = '',
}) {
  final start = indexHtml.indexOf(seoStartMarker);
  final end = indexHtml.indexOf(seoEndMarker);
  if (start < 0 || end < start) {
    throw const FormatException('index.html thiếu marker seo:start / seo:end');
  }
  var html =
      indexHtml.substring(0, start) +
      renderSeoBlock(meta, jsonLd: jsonLd) +
      indexHtml.substring(end + seoEndMarker.length);
  if (noscriptHtml.isNotEmpty) {
    if (!html.contains(noscriptMarker)) {
      throw const FormatException('index.html thiếu marker seo:noscript');
    }
    html = html.replaceFirst(
      noscriptMarker,
      '<noscript>$noscriptHtml</noscript>',
    );
  }
  return html;
}

/// Nội dung tối thiểu cho crawler không chạy JS.
String articleNoscript(SeoPost post) =>
    '<article><h1>${escapeHtml(post.title)}</h1>'
    '${post.summary.isEmpty ? '' : '<p>${escapeHtml(post.summary)}</p>'}'
    '</article>';

/// Đường dẫn file (tương đối với thư mục build) cho một route. Dùng đuôi
/// `.html` + `cleanUrls` của Firebase Hosting để URL không bị thêm dấu `/`.
String htmlFileForPath(String path) => '${path.substring(1)}.html';

// ---------------------------------------------------------------------------
// sitemap / robots
// ---------------------------------------------------------------------------

String buildSitemap(List<({String path, DateTime? lastModified})> entries) {
  String date(DateTime d) => d.toUtc().toIso8601String().substring(0, 10);
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
  for (final entry in entries) {
    buffer
      ..writeln('  <url>')
      ..writeln('    <loc>${escapeHtml('$siteUrl${entry.path}')}</loc>');
    if (entry.lastModified != null) {
      buffer.writeln('    <lastmod>${date(entry.lastModified!)}</lastmod>');
    }
    buffer.writeln('  </url>');
  }
  buffer.writeln('</urlset>');
  return buffer.toString();
}

String buildRobots() {
  final buffer = StringBuffer()..writeln('User-agent: *');
  for (final path in privatePaths) {
    buffer.writeln('Disallow: $path');
  }
  buffer
    ..writeln()
    ..writeln('Sitemap: $siteUrl/sitemap.xml');
  return buffer.toString();
}
