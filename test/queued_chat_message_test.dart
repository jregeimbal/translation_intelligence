import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/models/queued_chat_message.dart';

void main() {
  group('QueuedChatMessage', () {
    test('toChatMessage carries original speaker final and translation values', () {
      final queued = QueuedChatMessage(
        original: 'hola',
        speaker: 2,
        translation: 'hello',
      );

      final chat = queued.toChatMessage(isFinal: true);

      expect(chat.original, equals('hola'));
      expect(chat.speaker, equals(2));
      expect(chat.isFinal, isTrue);
      expect(chat.translation, equals('hello'));
    });

    test('processingStarted defaults to false', () {
      final queued = QueuedChatMessage(
        original: 'test',
        speaker: null,
      );

      expect(queued.processingStarted, isFalse);
    });
  });
}
