// Sinh HTML tĩnh có meta riêng cho từng bài + sitemap.xml + robots.txt, chạy
// SAU `flutter build web`:
//
//   dart run tool/prerender.dart [--build-dir build/web] [--project graduation-e59ff]
//
// Đọc `posts` và `categories` qua Firestore REST công khai (rules cho đọc
// công khai, không cần khóa). Chỉ bài `published == true` được sinh trang.
// Firebase Hosting phục vụ file tĩnh trước luật rewrite SPA, nên crawler mạng
// xã hội (không chạy JS) thấy đúng tiêu đề/mô tả/ảnh của bài; trình duyệt vẫn
// tải app Flutter như bình thường.
import 'dart:convert';
import 'dart:io';

import 'package:graduation_2026/utils/seo.dart';
import 'package:graduation_2026/utils/seo_prerender.dart';

Future<void> main(List<String> args) async {
  String option(String name, String fallback) {
    final index = args.indexOf('--$name');
    return index >= 0 && index + 1 < args.length ? args[index + 1] : fallback;
  }

  final buildDir = Directory(option('build-dir', 'build/web'));
  final project = option('project', 'graduation-e59ff');
  final indexFile = File('${buildDir.path}/index.html');
  if (!indexFile.existsSync()) {
    stderr.writeln(
      'Không thấy ${indexFile.path} — chạy `flutter build web` trước.',
    );
    exit(1);
  }
  final indexHtml = indexFile.readAsStringSync();

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final posts = (await _listDocuments(client, project, 'posts'))
        .map(postFromRest)
        .where((post) => post.published && post.title.trim().isNotEmpty)
        .toList();
    final categories = (await _listDocuments(client, project, 'categories'))
        .map(categoryFromRest)
        .where((category) => category.visible && category.name.isNotEmpty)
        .toList();

    for (final post in posts) {
      _write(
        buildDir,
        htmlFileForPath(post.path),
        applySeo(
          indexHtml,
          post.meta,
          jsonLd: articleJsonLd(post),
          noscriptHtml: articleNoscript(post),
        ),
      );
    }
    _write(
      buildDir,
      htmlFileForPath('/posts'),
      applySeo(
        indexHtml,
        const SeoMeta(
          path: '/posts',
          title: 'Tất cả bài viết',
          description: archiveDescription,
        ),
      ),
    );
    for (final category in categories) {
      _write(
        buildDir,
        htmlFileForPath(category.path),
        applySeo(
          indexHtml,
          SeoMeta(
            path: category.path,
            title: category.name,
            description: category.description,
          ),
        ),
      );
    }

    DateTime? latest(Iterable<DateTime?> dates) => dates
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final newest = latest(posts.map((p) => p.updated ?? p.created));
    _write(
      buildDir,
      'sitemap.xml',
      buildSitemap([
        (path: '/', lastModified: newest),
        (path: '/posts', lastModified: newest),
        for (final category in categories)
          (
            path: category.path,
            lastModified: latest(
              posts
                  .where((p) => p.categoryId == category.id)
                  .map((p) => p.updated ?? p.created),
            ),
          ),
        for (final post in posts)
          (path: post.path, lastModified: post.updated ?? post.created),
      ]),
    );
    _write(buildDir, 'robots.txt', buildRobots());

    stdout.writeln(
      'prerender: ${posts.length} bài, ${categories.length} danh mục, '
      'sitemap.xml + robots.txt -> ${buildDir.path}',
    );
  } finally {
    client.close();
  }
}

/// Đọc toàn bộ document của 1 collection (tự lật trang).
Future<List<Map<String, dynamic>>> _listDocuments(
  HttpClient client,
  String project,
  String collection,
) async {
  final documents = <Map<String, dynamic>>[];
  String? pageToken;
  do {
    final uri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$project/databases/(default)/documents/$collection',
      {'pageSize': '300', 'pageToken': ?pageToken},
    );
    final request = await client.getUrl(uri);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw HttpException(
        'Firestore $collection trả HTTP ${response.statusCode}: $body',
        uri: uri,
      );
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    documents.addAll(
      (data['documents'] as List? ?? const []).cast<Map<String, dynamic>>(),
    );
    pageToken = data['nextPageToken'] as String?;
  } while (pageToken != null);
  return documents;
}

void _write(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
