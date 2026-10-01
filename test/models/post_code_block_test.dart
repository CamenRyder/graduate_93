import 'package:flutter_test/flutter_test.dart';
import 'package:graduation_2026/models/post.dart';

void main() {
  group('Post code blocks', () {
    test('round-trips through the Firestore block map', () {
      const block = PostBlock(
        type: PostBlockType.code,
        text: 'final answer = 42;',
      );

      final restored = PostBlock.fromMap(block.toMap());

      expect(restored.type, PostBlockType.code);
      expect(restored.text, 'final answer = 42;');
      expect(restored.type.isText, isTrue);
    });

    test('does not use code as the article summary', () {
      final post = Post(
        id: 'post',
        title: 'A useful post',
        published: true,
        blocks: const [
          PostBlock(type: PostBlockType.heading, text: 'Setup'),
          PostBlock(type: PostBlockType.code, text: 'flutter run'),
          PostBlock(
            type: PostBlockType.paragraph,
            text: 'A readable introduction.',
          ),
        ],
        timeCreated: DateTime(2026, 10, 1),
        timeUpdated: null,
      );

      expect(post.snippet, 'A readable introduction.');
    });
  });
}
