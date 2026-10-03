import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/utils/seo.dart';
import 'package:graduation_2026/utils/seo_prerender.dart';

Map<String, dynamic> _restPost({
  String id = 'abc123',
  String title = 'Lễ tốt nghiệp <2026> & "bạn bè"',
  bool published = true,
  List<Map<String, dynamic>> blocks = const [],
}) => {
  'name': 'projects/p/databases/(default)/documents/posts/$id',
  'fields': {
    'title': {'stringValue': title},
    'published': {'booleanValue': published},
    'category_id': {'stringValue': 'ky-thuat'},
    'time_created': {'timestampValue': '2026-10-01T03:00:00Z'},
    'blocks': {
      'arrayValue': {
        'values': [
          for (final b in blocks)
            {
              'mapValue': {
                'fields': {
                  for (final e in b.entries) e.key: {'stringValue': e.value},
                },
              },
            },
        ],
      },
    },
  },
};

const _index = '''<head>
  <!-- seo:start ghi chú -->
  <title>Mặc định</title>
  <!-- seo:end -->
  <link rel="manifest" href="manifest.json">
</head>
<body>
  <!-- seo:noscript -->
</body>''';

void main() {
  group('postFromRest', () {
    test('đọc id, tóm tắt từ đoạn văn, ảnh bìa và bỏ qua code', () {
      final post = postFromRest(
        _restPost(
          blocks: [
            {'type': 'heading', 'text': 'Mở đầu'},
            {'type': 'code', 'text': 'secret()'},
            {'type': 'image', 'url': 'https://cdn.example/a.jpg'},
            {'type': 'paragraph', 'text': 'Đoạn một.'},
            {'type': 'quote', 'text': 'Trích dẫn.'},
          ],
        ),
      );
      expect(post.id, 'abc123');
      expect(post.published, isTrue);
      expect(post.summary, 'Đoạn một. Trích dẫn.');
      expect(post.imageUrl, 'https://cdn.example/a.jpg');
      expect(post.created, DateTime.utc(2026, 10, 1, 3));
      expect(post.path, '/posts/abc123/le-tot-nghiep-2026-ban-be');
    });

    test('không có đoạn văn thì dùng khối văn bản khác (trừ code)', () {
      final post = postFromRest(
        _restPost(
          blocks: [
            {'type': 'code', 'text': 'x'},
            {'type': 'heading', 'text': 'Chỉ có đề mục'},
          ],
        ),
      );
      expect(post.summary, 'Chỉ có đề mục');
    });

    test('thiếu field published thì coi là nháp', () {
      final doc = _restPost();
      (doc['fields'] as Map).remove('published');
      expect(postFromRest(doc).published, isFalse);
    });
  });

  group('tags', () {
    Map<String, dynamic> withTags(String id, List<String> tags, String time) {
      final doc = _restPost(id: id, title: id);
      final fields = doc['fields'] as Map<String, dynamic>;
      fields['tags'] = {
        'arrayValue': {
          'values': [
            for (final t in tags) {'stringValue': t},
          ],
        },
      };
      fields['time_created'] = {'timestampValue': time};
      return doc;
    }

    test('đọc tags từ REST, chuẩn hóa và đưa vào JSON-LD keywords', () {
      final post = postFromRest(
        withTags('a', ['Flutter', ' flutter', 'Web'], '2026-10-01T00:00:00Z'),
      );
      expect(post.tags, ['Flutter', 'Web']);
      final data = jsonDecode(articleJsonLd(post)) as Map;
      expect(data['keywords'], 'Flutter, Web');
      expect(
        (jsonDecode(articleJsonLd(postFromRest(_restPost()))) as Map)
            .containsKey('keywords'),
        isFalse,
      );
    });

    test('collectTags gộp theo slug, giữ nhãn đầu và ngày mới nhất', () {
      final tags = collectTags([
        postFromRest(withTags('a', ['Flutter Web'], '2026-09-01T00:00:00Z')),
        postFromRest(
          withTags('b', ['flutter web', 'Đà Lạt'], '2026-09-20T00:00:00Z'),
        ),
      ]);
      expect(tags.keys, ['flutter-web', 'da-lat']);
      expect(tags['flutter-web']!.label, 'Flutter Web');
      expect(tags['flutter-web']!.lastModified, DateTime.utc(2026, 9, 20));
    });
  });

  group('applySeo', () {
    final post = postFromRest(
      _restPost(
        blocks: [
          {'type': 'paragraph', 'text': 'Mô tả </script> <b>đậm</b>'},
        ],
      ),
    );

    test('thay khối meta, escape HTML và giữ phần còn lại', () {
      final html = applySeo(
        _index,
        post.meta,
        jsonLd: articleJsonLd(post),
        noscriptHtml: articleNoscript(post),
      );
      expect(html, isNot(contains('Mặc định')));
      expect(
        html,
        contains(
          '<title>Lễ tốt nghiệp &lt;2026&gt; &amp; &quot;bạn bè&quot; — $siteName</title>',
        ),
      );
      expect(
        html,
        contains(
          '<meta property="og:url" content="$siteUrl/posts/abc123/le-tot-nghiep-2026-ban-be">',
        ),
      );
      expect(html, contains('<meta property="og:type" content="article">'));
      // Ảnh rỗng -> không sinh og:image rỗng.
      expect(html, isNot(contains('og:image')));
      expect(html, contains('<link rel="manifest" href="manifest.json">'));
      expect(html, contains('<noscript><article><h1>'));
      expect(html, isNot(contains('<!-- seo:noscript -->')));
      // JSON-LD không được đóng thẻ script sớm.
      final script = RegExp(
        r'<script type="application/ld\+json">(.*?)</script>',
      ).firstMatch(html)!;
      expect(script.group(1), isNot(contains('</')));
      final data = jsonDecode(script.group(1)!.replaceAll(r'<\/', '</')) as Map;
      expect(data['@type'], 'BlogPosting');
      expect(data['datePublished'], '2026-10-01T03:00:00.000Z');
    });

    test('thiếu marker thì báo lỗi thay vì sinh HTML sai', () {
      expect(() => applySeo('<head></head>', post.meta), throwsFormatException);
    });
  });

  test('htmlFileForPath dùng đuôi .html cho cleanUrls', () {
    expect(htmlFileForPath('/posts/a/b'), 'posts/a/b.html');
    expect(htmlFileForPath('/categories/x'), 'categories/x.html');
  });

  test('summarize cắt ở ranh giới từ', () {
    expect(summarize('một hai   ba'), 'một hai ba');
    final long = List.filled(60, 'chữ').join(' ');
    final result = summarize(long, maxLength: 50);
    expect(result.length, lessThanOrEqualTo(50));
    expect(result.endsWith('…'), isTrue);
    expect(result, isNot(contains('ch…')));
  });

  test('sitemap và robots', () {
    final xml = buildSitemap([
      (path: '/', lastModified: null),
      (path: '/posts/a/b', lastModified: DateTime.utc(2026, 10, 2, 23)),
    ]);
    expect(xml, contains('<loc>$siteUrl/</loc>'));
    expect(xml, contains('<loc>$siteUrl/posts/a/b</loc>'));
    expect(xml, contains('<lastmod>2026-10-02</lastmod>'));
    final robots = buildRobots();
    expect(robots, contains('Disallow: /admin'));
    expect(robots, contains('Sitemap: $siteUrl/sitemap.xml'));
  });
}
