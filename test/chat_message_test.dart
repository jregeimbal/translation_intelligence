import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/models/chat_message.dart';

void main() {
  group('ChatMessageGroup', () {
    test('fromJson reads all fields', () {
      final group = ChatMessageGroup.fromJson({
        'id': 'g1',
        'original': 'hola',
        'translation': 'hello',
      });

      expect(group.id, equals('g1'));
      expect(group.original, equals('hola'));
      expect(group.translation, equals('hello'));
    });

    test('toJson writes all fields', () {
      const group = ChatMessageGroup(
        id: 'g2',
        original: 'bonjour',
        translation: 'hello',
      );

      expect(group.toJson(), {
        'id': 'g2',
        'original': 'bonjour',
        'translation': 'hello',
      });
    });
  });

  group('ChatMessage', () {
    test('fromJson reads all fields including groups and timestamp', () {
      final message = ChatMessage.fromJson({
        'original': 'hola mundo',
        'speaker': 1,
        'isFinal': true,
        'translation': 'hello world',
        'id': 'msg_123',
        'timestamp': '2026-03-25T10:15:30.000Z',
        'sourceLanguageCode': 'es',
        'targetLanguageCode': 'en',
        'groups': [
          {'id': 'g1', 'original': 'hola', 'translation': 'hello'},
          {'id': 'g2', 'original': 'mundo', 'translation': 'world'},
        ],
      });

      expect(message.original, equals('hola mundo'));
      expect(message.speaker, equals(1));
      expect(message.isFinal, isTrue);
      expect(message.translation, equals('hello world'));
      expect(message.id, equals('msg_123'));
      expect(message.sourceLanguageCode, equals('es'));
      expect(message.targetLanguageCode, equals('en'));
      expect(
        message.timestamp,
        equals(DateTime.parse('2026-03-25T10:15:30.000Z')),
      );
      expect(message.groups, hasLength(2));
      expect(message.groups[0].id, equals('g1'));
      expect(message.groups[0].original, equals('hola'));
      expect(message.groups[0].translation, equals('hello'));
      expect(message.groups[1].id, equals('g2'));
      expect(message.groups[1].original, equals('mundo'));
      expect(message.groups[1].translation, equals('world'));
    });

    test('toJson writes all fields including groups and timestamp', () {
      final timestamp = DateTime.parse('2026-03-25T10:15:30.000Z');
      final message = ChatMessage(
        'hola mundo',
        speaker: 1,
        isFinal: true,
        id: 'msg_123',
        timestamp: timestamp,
        sourceLanguageCode: 'es',
        targetLanguageCode: 'en',
        groups: const [
          ChatMessageGroup(id: 'g1', original: 'hola', translation: 'hello'),
          ChatMessageGroup(id: 'g2', original: 'mundo', translation: 'world'),
        ],
      )..translation = 'hello world';

      expect(message.toJson(), {
        'original': 'hola mundo',
        'speaker': 1,
        'isFinal': true,
        'translation': 'hello world',
        'id': 'msg_123',
        'timestamp': timestamp.toIso8601String(),
        'sourceLanguageCode': 'es',
        'targetLanguageCode': 'en',
        'groups': [
          {'id': 'g1', 'original': 'hola', 'translation': 'hello'},
          {'id': 'g2', 'original': 'mundo', 'translation': 'world'},
        ],
      });
    });

    test('fromJson falls back for missing optional fields', () {
      final before = DateTime.now();
      final message = ChatMessage.fromJson({'original': 'plain'});
      final after = DateTime.now();

      expect(message.original, equals('plain'));
      expect(message.speaker, isNull);
      expect(message.isFinal, isFalse);
      expect(message.translation, isNull);
      expect(message.groups, isEmpty);
      expect(
        message.timestamp.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        message.timestamp.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });
}
