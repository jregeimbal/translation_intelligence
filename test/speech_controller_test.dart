import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/widgets/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const audioGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const recordChannel = MethodChannel('com.llfbandit.record/messages');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, (call) async {
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (call) async {
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
  });

  group('SpeechController', () {
    late SpeechController controller;

    setUp(() {
      controller = SpeechController(
        googleApiKey: '',
        deepgramApiKey: 'test-key',
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('has expected default state', () {
      expect(controller.speechEnabled, isFalse);
      expect(controller.isListening, isFalse);
      expect(controller.speechError, isEmpty);
      expect(controller.getOptimisticMessages(), isEmpty);
      expect(controller.amplitude, equals(0.0));
      expect(controller.chatMessages, isEmpty);
      expect(controller.speakers, isEmpty);
      expect(controller.preferredSpeaker, isNull);
      expect(controller.targetLanguage, equals('en'));
      expect(controller.targetLanguageName, equals('English'));
    });

    test('supportedLanguages contains expected baseline entries', () {
      expect(SpeechController.supportedLanguages['English'], equals('en'));
      expect(SpeechController.supportedLanguages['Spanish'], equals('es'));
      expect(SpeechController.supportedLanguages['Chinese (Simplified)'], equals('zh-CN'));
    });

    test('setTargetLanguage updates and notifies only on changes', () {
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setTargetLanguage('es');
      expect(controller.targetLanguage, equals('es'));
      expect(controller.targetLanguageName, equals('Spanish'));
      expect(notifications, equals(1));

      controller.setTargetLanguage('es');
      expect(notifications, equals(1));
    });

    test('targetLanguageName falls back to raw code for unknown language', () {
      controller.setTargetLanguage('xx-custom');
      expect(controller.targetLanguage, equals('xx-custom'));
      expect(controller.targetLanguageName, equals('xx-custom'));
    });

    test('setPreferredSpeaker updates and notifies listeners', () {
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setPreferredSpeaker(3);
      expect(controller.preferredSpeaker, equals(3));
      expect(notifications, equals(1));

      controller.setPreferredSpeaker(null);
      expect(controller.preferredSpeaker, isNull);
      expect(notifications, equals(2));
    });

    test('clearMessages notifies listeners', () {
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.clearMessages();
      expect(controller.chatMessages, isEmpty);
      expect(notifications, equals(1));
    });

    test('chatMessages getter is immutable', () {
      final messages = controller.chatMessages;
      expect(
        () => messages.add(ChatMessage('Hello')),
        throwsUnsupportedError,
      );
    });
  });
}
