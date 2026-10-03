import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/utils/share_links.dart';

void main() {
  test('encode URL và tiêu đề tiếng Việt cho Facebook và X', () {
    const url = 'https://graduation-e59ff.web.app/posts/a/tieu-de?x=1&y=2';
    final links = shareLinks(url: url, title: ' Tiêu đề & ý ');
    final fb = Uri.parse(links.facebook);
    expect(fb.host, 'www.facebook.com');
    expect(fb.queryParameters['u'], url);
    final x = Uri.parse(links.x);
    expect(x.path, '/intent/tweet');
    expect(x.queryParameters['url'], url);
    expect(x.queryParameters['text'], 'Tiêu đề & ý');
  });

  test('tiêu đề rỗng thì không gửi text', () {
    final links = shareLinks(url: 'https://a.b/c', title: '  ');
    expect(Uri.parse(links.x).queryParameters.containsKey('text'), isFalse);
  });
}
