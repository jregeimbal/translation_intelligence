import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:record/record.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/services/speech_pipeline.dart';

class _FakeTtsSpeechPipeline extends SpeechPipeline {
  final StreamController<SpeechRecognitionResult> resultController =
      StreamController<SpeechRecognitionResult>.broadcast();
  final StreamController<double> amplitudeController =
      StreamController<double>.broadcast();

  int synthesizeCallCount = 0;
  String? lastSynthText;
  String? lastSynthLanguageCode;
  String? lastTtsLanguageRequest;
  int translateCallCount = 0;
  Uint8List synthesizeBytes = Uint8List(0);

  _FakeTtsSpeechPipeline() : super(deepgramApiKey: 'test-deepgram');

  @override
  Future<bool> isSpeechApiKeyValid() async => true;

  @override
  Future<SpeechRecognitionSession> startRecognitionSession(
    AudioRecorder recorder, {
    required String sourceLanguage,
    bool diarize = false,
    bool utterances = false,
    bool punctuate = false,
    bool smartFormat = false,
    bool detectLanguage = false,
  }) async {
    return SpeechRecognitionSession(
      resultStream: resultController.stream,
      amplitudeStream: amplitudeController.stream,
      stop: () async {},
    );
  }

  @override
  Future<String?> translateText({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
    bool returnOriginalOnFailure = true,
    bool throwOnMissingApiKey = false,
    bool nullWhenUnchanged = false,
  }) async {
    translateCallCount += 1;
    return '$text-translated';
  }

  @override
  String ttsLanguageCodeForAppLanguage(String appLang) {
    lastTtsLanguageRequest = appLang;
    return 'mapped-$appLang';
  }

  @override
  Future<Uint8List> synthesizeSpeech({
    required String text,
    String languageCode = 'en-US',
    String ssmlGender = 'NEUTRAL',
  }) async {
    synthesizeCallCount += 1;
    lastSynthText = text;
    lastSynthLanguageCode = languageCode;
    return synthesizeBytes;
  }

  Future<void> disposeFake() async {
    await resultController.close();
    await amplitudeController.close();
  }
}

void main() {
  Logger.root.level = Level.WARNING;

  TestWidgetsFlutterBinding.ensureInitialized();

  const audioGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const audioPlayerChannel = MethodChannel('xyz.luan/audioplayers');
  const recordChannel = MethodChannel('com.llfbandit.record/messages');
  const wakelockChannel = MethodChannel(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
  );

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, (call) async {
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioPlayerChannel, (call) async {
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (call) async {
          if (call.method == 'hasPermission') {
            return true;
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(wakelockChannel, (call) async {
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioPlayerChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(wakelockChannel, null);
  });

  group('SpeechController TTS result behavior', () {
    late _FakeTtsSpeechPipeline pipeline;
    late SpeechController controller;

    setUp(() {
      pipeline = _FakeTtsSpeechPipeline();
      controller = SpeechController(
        deepgramApiKey: 'test-deepgram',
        speechPipeline: pipeline,
        finalResultGroupingWindow: Duration.zero,
      );
    });

    tearDown(() async {
      await controller.stopListening();
      controller.dispose();
      await pipeline.disposeFake();
    });

    test('final recognition triggers translation and TTS synthesis', () async {
      await controller.init();
      await controller.startListening();

      pipeline.resultController.add(
        SpeechRecognitionResult.fromTranscript(
          transcript: 'hello final',
          isFinal: true,
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.chatMessages.length, equals(1));
      expect(
        controller.chatMessages.first.translation,
        equals('hello final-translated'),
      );
      expect(pipeline.translateCallCount, equals(1));
      expect(pipeline.synthesizeCallCount, equals(1));
      expect(pipeline.lastSynthText, equals('hello final-translated'));
    });

    test('preferred speaker messages skip TTS synthesis', () async {
      await controller.init();
      controller.setPreferredSpeaker(1);
      await controller.startListening();

      pipeline.resultController.add(
        SpeechRecognitionResult(
          isFinal: true,
          words: [
            SpeechRecognitionWord(word: 'speaker', speaker: 1),
            SpeechRecognitionWord(word: 'one', speaker: 1),
          ],
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.chatMessages.length, equals(1));
      expect(controller.chatMessages.first.speaker, equals(1));
      expect(
        controller.chatMessages.first.translation,
        equals('speaker one-translated'),
      );
      expect(pipeline.translateCallCount, equals(1));
      expect(pipeline.synthesizeCallCount, equals(0));
    });

    test(
      'TTS synthesis uses mapped language code for selected target language',
      () async {
        await controller.init();
        controller.setTargetLanguage('es');
        await controller.startListening();

        pipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'hola',
            isFinal: true,
          ),
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(pipeline.lastTtsLanguageRequest, equals('es'));
        expect(pipeline.lastSynthLanguageCode, equals('mapped-es'));
      },
    );

    test(
      'queued final result translates and speaks before flush, then does not duplicate on commit',
      () async {
        final groupedPipeline = _FakeTtsSpeechPipeline();
        final groupedController = SpeechController(
          deepgramApiKey: 'test-deepgram',
          speechPipeline: groupedPipeline,
          finalResultGroupingWindow: const Duration(milliseconds: 120),
        );

        await groupedController.init();
        await groupedController.startListening();

        groupedPipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'queued final',
            isFinal: true,
          ),
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(groupedController.chatMessages, isEmpty);
        expect(
          groupedController.getOptimisticMessages().single.translation,
          equals('queued final-translated'),
        );
        expect(groupedPipeline.translateCallCount, equals(1));
        expect(groupedPipeline.synthesizeCallCount, equals(1));

        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(groupedController.chatMessages.length, equals(1));
        expect(
          groupedController.chatMessages.first.original,
          equals('queued final.'),
        );
        expect(
          groupedController.chatMessages.first.translation,
          equals('queued final-translated'),
        );
        expect(groupedPipeline.translateCallCount, equals(1));
        expect(groupedPipeline.synthesizeCallCount, equals(1));

        await groupedController.stopListening();
        groupedController.dispose();
        await groupedPipeline.disposeFake();
      },
    );

    test(
      'queued translation stays visible until replacement translation arrives',
      () async {
        final groupedPipeline = _FakeTtsSpeechPipeline();
        final groupedController = SpeechController(
          deepgramApiKey: 'test-deepgram',
          speechPipeline: groupedPipeline,
          finalResultGroupingWindow: const Duration(milliseconds: 250),
        );

        await groupedController.init();
        await groupedController.startListening();

        groupedPipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'hello',
            isFinal: true,
          ),
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(groupedController.chatMessages, isEmpty);
        expect(
          groupedController.getOptimisticMessages().single.translation,
          equals('hello-translated'),
        );

        groupedPipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'hello there',
            isFinal: true,
          ),
        );

        await Future<void>.delayed(Duration.zero);

        expect(
          groupedController.getOptimisticMessages().single.translation,
          equals('hello there-translated'),
        );

        await Future<void>.delayed(const Duration(milliseconds: 80));
        await Future<void>.delayed(Duration.zero);

        expect(
          groupedController.getOptimisticMessages().single.translation,
          equals('hello there-translated'),
        );

        await groupedController.stopListening();
        groupedController.dispose();
        await groupedPipeline.disposeFake();
      },
    );

    test(
      'preferred speaker is chosen at queue time and skips queued TTS before flush',
      () async {
        final groupedPipeline = _FakeTtsSpeechPipeline();
        final groupedController = SpeechController(
          deepgramApiKey: 'test-deepgram',
          speechPipeline: groupedPipeline,
          finalResultGroupingWindow: const Duration(milliseconds: 120),
        );

        await groupedController.init();
        await groupedController.startListening();

        groupedPipeline.resultController.add(
          SpeechRecognitionResult(
            isFinal: true,
            words: [
              SpeechRecognitionWord(word: 'speaker', speaker: 0),
              SpeechRecognitionWord(word: 'zero', speaker: 0),
            ],
          ),
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(groupedController.chatMessages, isEmpty);
        expect(groupedController.preferredSpeaker, equals(0));
        expect(groupedPipeline.translateCallCount, equals(1));
        expect(groupedPipeline.synthesizeCallCount, equals(0));

        await groupedController.stopListening();
        groupedController.dispose();
        await groupedPipeline.disposeFake();
      },
    );

    test(
      'playback completion timeout path does not log audio playback type error',
      () async {
        final groupedPipeline = _FakeTtsSpeechPipeline();
        groupedPipeline.synthesizeBytes = Uint8List.fromList([1, 2, 3]);

        final groupedController = SpeechController(
          deepgramApiKey: 'test-deepgram',
          speechPipeline: groupedPipeline,
          finalResultGroupingWindow: Duration.zero,
          audioPlaybackCompletionTimeout: const Duration(milliseconds: 1),
        );

        final captured = <LogRecord>[];
        final sub = Logger.root.onRecord.listen(captured.add);

        await groupedController.init();
        await groupedController.startListening();

        groupedPipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'timeout probe',
            isFinal: true,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(groupedController.chatMessages.length, equals(1));
        final hasAudioPlaybackError = captured.any(
          (record) =>
              record.level >= Level.SEVERE &&
              record.message.contains('audio playback error'),
        );
        expect(hasAudioPlaybackError, isFalse);

        await sub.cancel();
        await groupedController.stopListening();
        groupedController.dispose();
        await groupedPipeline.disposeFake();
      },
    );

    test(
      'playback queue continues with next clip after timeout wait path',
      () async {
        final groupedPipeline = _FakeTtsSpeechPipeline();
        groupedPipeline.synthesizeBytes = Uint8List.fromList([1, 2, 3]);

        final groupedController = SpeechController(
          deepgramApiKey: 'test-deepgram',
          speechPipeline: groupedPipeline,
          finalResultGroupingWindow: Duration.zero,
          audioPlaybackCompletionTimeout: const Duration(milliseconds: 1),
        );

        final captured = <LogRecord>[];
        final sub = Logger.root.onRecord.listen(captured.add);

        await groupedController.init();
        await groupedController.startListening();

        groupedPipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'first clip',
            isFinal: true,
          ),
        );
        groupedPipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'second clip',
            isFinal: true,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(groupedController.chatMessages.length, equals(2));
        expect(groupedPipeline.translateCallCount, equals(2));
        expect(groupedPipeline.synthesizeCallCount, equals(2));

        await sub.cancel();
        await groupedController.stopListening();
        groupedController.dispose();
        await groupedPipeline.disposeFake();
      },
    );
  });
}
