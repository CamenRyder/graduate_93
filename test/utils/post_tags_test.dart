import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/utils/post_tags.dart';

void main() {
  test('chuẩn hóa: gộp khoảng trắng, bỏ rỗng, loại trùng theo slug', () {
    expect(
      normalizeTags([
        '  Flutter   Web ',
        'flutter web',
        '',
        '  ',
        '!!!',
        'Đà Lạt',
      ]),
      ['Flutter Web', 'Đà Lạt'],
    );
  });

  test('cắt độ dài và giới hạn số thẻ', () {
    final long = 'a' * (maxTagLength + 10);
    expect(normalizeTags([long]).single.length, maxTagLength);
    final many = [for (var i = 0; i < 20; i++) 'tag $i'];
    expect(normalizeTags(many), hasLength(maxTagsPerPost));
    expect(normalizeTags(many).first, 'tag 0');
  });

  test('tách chuỗi dán vào theo dấu phẩy, chấm phẩy, xuống dòng', () {
    expect(parseTagInput('a, b;c\nd,,  '), ['a', ' b', 'c', 'd']);
    expect(normalizeTags(parseTagInput('a, b;c')), ['a', 'b', 'c']);
  });

  test('đường dẫn thẻ dùng slug không dấu', () {
    expect(tagSlug('Flutter Web'), 'flutter-web');
    expect(tagPath('Đời sống'), '/tags/doi-song');
  });
}
