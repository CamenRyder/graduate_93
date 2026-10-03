import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/models/post.dart';

void main() {
  test('toFirestore luôn ghi tags đã chuẩn hóa, kể cả khi rỗng', () {
    Post post(List<String> tags) => Post(
      id: 'p',
      title: 't',
      published: true,
      tags: tags,
      blocks: const [],
      timeCreated: null,
      timeUpdated: null,
    );
    expect(post(['Flutter', ' flutter ', 'Web']).toFirestore()['tags'], [
      'Flutter',
      'Web',
    ]);
    expect(post(const []).toFirestore()['tags'], isEmpty);
    expect(post(const []).toFirestore().containsKey('tags'), isTrue);
  });
}
