import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/services/speech_output_provider.dart';
import 'package:translation_intelligence/services/speech_pipeline.dart';
import 'package:translation_intelligence/services/speech_stt_provider.dart';
import 'package:translation_intelligence/services/speech_translation_provider.dart';
import 'package:translation_intelligence/widgets/chat_message.dart';

class _FakeSpeechPipeline extends SpeechPipeline {
  _FakeSpeechPipeline()
      : super(
          googleApiKey: '',
          deepgramApiKey: '',
        );

  bool apiKeyValid = true;
  int startRecognitionCalls = 0;
  String? lastSourceLanguage;
  SpeechRecognitionSession session = const SpeechRecognitionSession(
    resultStream: Stream<SpeechRecognitionResult>.empty(),
    amplitudeStream: Stream<double>.empty(),
    stop: _noopStop,
  );

  static Future<void> _noopStop() async {}

  @override
  Future<bool> isSpeechApiKeyValid() async => apiKeyValid;

  @override
  Future<SpeechRecognitionSession> startRecognitionSession(
    AudioRecorder recorder, {
    required String sourceLanguage,
    bool diarize = false,
    bool utterances = false,
  }) async {
    startRecognitionCalls += 1;
    lastSourceLanguage = sourceLanguage;
    return session;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const audioGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const recordChannel = MethodChannel('com.llfbandit.record/messages');
  var hasPermission = true;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, (call) async {
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (call) async {
      if (call.method == 'create') {
        return 1;
      }
      if (call.method == 'hasPermission') {
        return hasPermission;
      }
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
      hasPermission = true;
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

    test('provider and deepgram getters expose pipeline state', () {
      expect(controller.outputProvider, equals(SpeechOutputProvider.google));
      expect(controller.sttProvider, equals(SpeechSttProvider.deepgram));
      expect(
        controller.translationProvider,
        equals(SpeechTranslationProvider.google),
      );
      expect(controller.deepgramRecognitionModel, equals('nova-3'));
      expect(controller.deepgramRecognitionLanguage, equals('multi'));
      expect(controller.deepgramRecognitionModels, contains('nova-3-medical'));
      expect(controller.deepgramRecognitionLanguages.values, contains('multi'));
    });

    test('provider/model/language setters notify only when changed', () {
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setOutputProvider(SpeechOutputProvider.google);
      controller.setSttProvider(SpeechSttProvider.deepgram);
      controller.setTranslationProvider(SpeechTranslationProvider.google);
      controller.setDeepgramRecognitionModel('nova-3');
      controller.setDeepgramRecognitionLanguage('multi');
      expect(notifications, equals(0));

      controller.setOutputProvider(SpeechOutputProvider.deepgram);
      controller.setSttProvider(SpeechSttProvider.google);
      controller.setTranslationProvider(SpeechTranslationProvider.googleMlKit);
      controller.setDeepgramRecognitionModel('nova-3-medical');
      controller.setDeepgramRecognitionLanguage('en-US');
      expect(notifications, equals(5));
    });

    test('init sets speechError when microphone permission is denied', () async {
      hasPermission = false;
      await controller.init();

      expect(controller.speechEnabled, isFalse);
      expect(controller.speechError, equals('Microphone permission denied'));
    });

    test('init sets speechError when API key validation fails', () async {
      final fakePipeline = _FakeSpeechPipeline()..apiKeyValid = false;
      final localController = SpeechController(
        googleApiKey: '',
        deepgramApiKey: 'test-key',
        speechPipeline: fakePipeline,
      );
      addTearDown(localController.dispose);

      await localController.init();

      expect(localController.speechEnabled, isFalse);
      expect(localController.speechError, equals('Invalid speech API key'));
    });

    test('startListening uses deepgram language for deepgram STT provider',
        () async {
      final results = StreamController<SpeechRecognitionResult>.broadcast();
      final amplitudes = StreamController<double>.broadcast();
      final fakePipeline = _FakeSpeechPipeline()
        ..session = SpeechRecognitionSession(
          resultStream: results.stream,
          amplitudeStream: amplitudes.stream,
          stop: () async {},
        );
      final localController = SpeechController(
        googleApiKey: '',
        deepgramApiKey: 'test-key',
        speechPipeline: fakePipeline,
      );
      addTearDown(() async {
        await results.close();
        await amplitudes.close();
        localController.dispose();
      });

      await localController.init();
      localController.setDeepgramRecognitionLanguage('en-US');
      await localController.startListening();
      amplitudes.add(0.73);
      await Future<void>.delayed(Duration.zero);

      expect(localController.isListening, isTrue);
      expect(localController.amplitude, closeTo(0.73, 0.0001));
      expect(fakePipeline.lastSourceLanguage, equals('en-US'));
      expect(fakePipeline.startRecognitionCalls, equals(1));
    });

    test('startListening uses multi source for non-deepgram STT provider',
        () async {
      final fakePipeline = _FakeSpeechPipeline();
      final localController = SpeechController(
        googleApiKey: '',
        deepgramApiKey: 'test-key',
        speechPipeline: fakePipeline,
      );
      addTearDown(localController.dispose);

      await localController.init();
      localController.setSttProvider(SpeechSttProvider.google);
      await localController.startListening();

      expect(localController.isListening, isTrue);
      expect(fakePipeline.lastSourceLanguage, equals('multi'));
      expect(fakePipeline.startRecognitionCalls, equals(1));
    });
  });
}
