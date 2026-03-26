import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/services/mic_activation_sound_player.dart';
import 'package:translation_intelligence/services/speech_pipeline.dart';

class _FakeMicActivationSoundPlayer implements MicActivationSoundPlayer {
  @override
  Future<void> play() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeSpeechPipeline extends SpeechPipeline {
  final StreamController<SpeechRecognitionResult> resultController =
      StreamController<SpeechRecognitionResult>.broadcast();
  final StreamController<double> amplitudeController =
      StreamController<double>.broadcast();

  int synthesizeCallCount = 0;
  String? lastTranslateSourceLanguage;

  _FakeSpeechPipeline() : super(deepgramApiKey: 'test-deepgram');

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
      sourceLanguage: sourceLanguage,
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
    lastTranslateSourceLanguage = sourceLanguage;
    return '$text-translated';
  }

  @override
  Future<Uint8List> synthesizeSpeech({
    required String text,
    String languageCode = 'en-US',
    String ssmlGender = 'NEUTRAL',
  }) async {
    synthesizeCallCount += 1;
    return Uint8List(0);
  }

  Future<void> disposeFake() async {
    await resultController.close();
    await amplitudeController.close();
  }
}

SpeechController _buildController(
  _FakeSpeechPipeline pipeline, {
  Duration finalResultGroupingWindow = Duration.zero,
}) {
  return SpeechController(
    deepgramApiKey: 'test-deepgram',
    speechPipeline: pipeline,
    micActivationSoundPlayer: _FakeMicActivationSoundPlayer(),
    finalResultGroupingWindow: finalResultGroupingWindow,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const audioGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');
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
        .setMockMethodCallHandler(recordChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(wakelockChannel, null);
  });

  group('SpeechController STT result behavior', () {
    late _FakeSpeechPipeline pipeline;
    late SpeechController controller;

    setUp(() {
      pipeline = _FakeSpeechPipeline();
      controller = _buildController(pipeline);
    });

    tearDown(() async {
      await controller.stopListening();
      controller.dispose();
      await pipeline.disposeFake();
    });

    test(
      'partial recognition updates transcript without creating message',
      () async {
        await controller.init();
        await controller.startListening();

        pipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'hello partial',
            isFinal: false,
          ),
        );

        await Future<void>.delayed(Duration.zero);

        pipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'hello partial',
            isFinal: false,
          ),
        );

        await Future<void>.delayed(Duration.zero);

        final optimistic = controller.getOptimisticMessages();
        expect(optimistic.length, equals(1));
        expect(optimistic.first.original, equals('hello partial'));
        expect(controller.chatMessages, isEmpty);
        expect(pipeline.synthesizeCallCount, equals(0));
      },
    );

    test(
      'final recognition commits message and clears live transcript',
      () async {
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
        expect(controller.chatMessages.first.original, equals('hello final.'));
        expect(controller.getOptimisticMessages(), isEmpty);
        expect(pipeline.synthesizeCallCount, equals(1));
      },
    );

    test(
      'translation omits source language when active source is multi',
      () async {
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

        expect(pipeline.lastTranslateSourceLanguage, isNull);
      },
    );

    test(
      'translation sends source language when active source is fixed',
      () async {
        await controller.init();
        controller.setDeepgramRecognitionLanguage('es');
        await controller.startListening();

        pipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'hola final',
            isFinal: true,
          ),
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(pipeline.lastTranslateSourceLanguage, equals('es'));
      },
    );

    test('speechFinal advances non-final words to queue and commits', () async {
      await controller.init();
      await controller.startListening();

      pipeline.resultController.add(
        SpeechRecognitionResult.fromTranscript(
          transcript: 'hello speech final',
          isFinal: false,
          speechFinal: true,
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.chatMessages.length, equals(1));
      expect(
        controller.chatMessages.first.original,
        equals('hello speech final.'),
      );
      expect(controller.getOptimisticMessages(), isEmpty);
      expect(pipeline.synthesizeCallCount, equals(1));
    });

    test('speechFinal with no words commits buffered partial words', () async {
      await controller.init();
      await controller.startListening();

      pipeline.resultController.add(
        SpeechRecognitionResult.fromTranscript(
          transcript: 'buffered partial',
          isFinal: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      pipeline.resultController.add(
        const SpeechRecognitionResult(
          isFinal: false,
          speechFinal: true,
          words: <SpeechRecognitionWord>[],
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.chatMessages.length, equals(1));
      expect(
        controller.chatMessages.first.original,
        equals('buffered partial.'),
      );
      expect(controller.getOptimisticMessages(), isEmpty);
      expect(pipeline.synthesizeCallCount, equals(1));
    });

    test('speechFinal result is committed after grouping window', () async {
      final groupedPipeline = _FakeSpeechPipeline();
      final groupedController = _buildController(
        groupedPipeline,
        finalResultGroupingWindow: const Duration(milliseconds: 30),
      );

      await groupedController.init();
      await groupedController.startListening();

      groupedPipeline.resultController.add(
        SpeechRecognitionResult.fromTranscript(
          transcript: 'hello final',
          isFinal: false,
          speechFinal: true,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 40));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(groupedController.chatMessages.length, equals(1));
      expect(
        groupedController.chatMessages.first.original,
        equals('hello final.'),
      );
      expect(groupedController.getOptimisticMessages(), isEmpty);
      expect(groupedPipeline.synthesizeCallCount, equals(1));

      // final optimistic = groupedController.getOptimisticMessages();
      // expect(groupedController.chatMessages, isEmpty);
      // expect(optimistic.length, equals(2));
      // expect(optimistic[0].original, equals('hello there'));
      // expect(optimistic[0].speaker, equals(0));
      // expect(optimistic[1].original, equals('general'));
      // expect(optimistic[1].speaker, equals(1));

      await groupedController.stopListening();
      groupedController.dispose();
      await groupedPipeline.disposeFake();
    });

    test(
      'stopping with partial transcript commits pending STT words',
      () async {
        await controller.init();
        await controller.startListening();

        pipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'pending partial',
            isFinal: false,
          ),
        );

        await Future<void>.delayed(Duration.zero);
        await controller.stopListening();
        await Future<void>.delayed(Duration.zero);

        expect(controller.chatMessages.length, equals(1));
        expect(
          controller.chatMessages.first.original,
          equals('pending partial.'),
        );
        expect(controller.getOptimisticMessages(), isEmpty);
      },
    );

    test(
      'empty final result does not create messages or trigger TTS',
      () async {
        await controller.init();
        await controller.startListening();

        pipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(transcript: '', isFinal: true),
        );

        await Future<void>.delayed(Duration.zero);

        expect(controller.chatMessages, isEmpty);
        expect(controller.getOptimisticMessages(), isEmpty);
        expect(pipeline.synthesizeCallCount, equals(0));
      },
    );

    test('later partial result replaces earlier partial transcript', () async {
      await controller.init();
      await controller.startListening();

      pipeline.resultController.add(
        SpeechRecognitionResult.fromTranscript(
          transcript: 'hello',
          isFinal: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      pipeline.resultController.add(
        SpeechRecognitionResult.fromTranscript(
          transcript: 'hello world',
          isFinal: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final optimistic = controller.getOptimisticMessages();
      expect(optimistic.length, equals(1));
      expect(optimistic.first.original, equals('hello world'));
      expect(controller.chatMessages, isEmpty);
      expect(pipeline.synthesizeCallCount, equals(0));
    });

    test('final diarized words are split into speaker messages', () async {
      await controller.init();
      await controller.startListening();

      pipeline.resultController.add(
        SpeechRecognitionResult(
          isFinal: true,
          words: [
            SpeechRecognitionWord(word: 'Hello', speaker: 0),
            SpeechRecognitionWord(word: 'there', speaker: 0),
            SpeechRecognitionWord(word: 'General', speaker: 1),
            SpeechRecognitionWord(word: 'Kenobi', speaker: 1),
          ],
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.chatMessages.length, equals(2));
      expect(controller.chatMessages[0].original, equals('Hello there.'));
      expect(controller.chatMessages[0].speaker, equals(0));
      expect(controller.chatMessages[1].original, equals('General Kenobi.'));
      expect(controller.chatMessages[1].speaker, equals(1));
      expect(controller.preferredSpeaker, equals(0));
      expect(pipeline.synthesizeCallCount, equals(1));
      expect(controller.getOptimisticMessages(), isEmpty);
    });

    test('partial diarized words set preferred speaker before queueing', () async {
      await controller.init();
      await controller.startListening();

      pipeline.resultController.add(
        SpeechRecognitionResult(
          isFinal: false,
          words: [
            SpeechRecognitionWord(word: 'Hello', speaker: 0),
            SpeechRecognitionWord(word: 'there', speaker: 0),
            SpeechRecognitionWord(word: 'General', speaker: 1),
          ],
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(controller.chatMessages, isEmpty);
      expect(controller.preferredSpeaker, equals(0));

      final optimistic = controller.getOptimisticMessages();
      expect(optimistic.length, equals(2));
      expect(optimistic[0].speaker, equals(0));
      expect(optimistic[1].speaker, equals(1));
    });

    test('final words take precedence over transcript fallback', () async {
      await controller.init();
      await controller.startListening();

      pipeline.resultController.add(
        SpeechRecognitionResult(
          isFinal: true,
          words: [
            SpeechRecognitionWord(word: 'actual', speaker: null),
            SpeechRecognitionWord(word: 'words', speaker: null),
          ],
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.chatMessages.length, equals(1));
      expect(controller.chatMessages.first.original, equals('actual words.'));
    });

    test(
      'optimistic messages expose pending final transcript before commit',
      () async {
        final groupedPipeline = _FakeSpeechPipeline();
        final groupedController = _buildController(
          groupedPipeline,
          finalResultGroupingWindow: const Duration(milliseconds: 120),
        );

        await groupedController.init();
        await groupedController.startListening();

        groupedPipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'buffered final',
            isFinal: true,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final optimistic = groupedController.getOptimisticMessages();
        expect(groupedController.chatMessages, isEmpty);
        expect(optimistic.length, equals(1));
        expect(optimistic.first.original, equals('buffered final'));

        await groupedController.stopListening();
        groupedController.dispose();
        await groupedPipeline.disposeFake();
      },
    );

    test(
      'optimistic messages expose pending diarized finals by speaker',
      () async {
        final groupedPipeline = _FakeSpeechPipeline();
        final groupedController = _buildController(
          groupedPipeline,
          finalResultGroupingWindow: const Duration(milliseconds: 120),
        );

        await groupedController.init();
        await groupedController.startListening();

        groupedPipeline.resultController.add(
          SpeechRecognitionResult(
            isFinal: true,
            words: [
              SpeechRecognitionWord(word: 'hello', speaker: 0),
              SpeechRecognitionWord(word: 'there', speaker: 0),
              SpeechRecognitionWord(word: 'general', speaker: 1),
            ],
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final optimistic = groupedController.getOptimisticMessages();
        expect(groupedController.chatMessages, isEmpty);
        expect(optimistic.length, equals(2));
        expect(optimistic[0].original, equals('hello there'));
        expect(optimistic[0].speaker, equals(0));
        expect(optimistic[1].original, equals('general'));
        expect(optimistic[1].speaker, equals(1));

        await groupedController.stopListening();
        groupedController.dispose();
        await groupedPipeline.disposeFake();
      },
    );

    test('consecutive partials overwrite optimistic messages', () async {
      final groupedPipeline = _FakeSpeechPipeline();
      final groupedController = _buildController(
        groupedPipeline,
        finalResultGroupingWindow: const Duration(milliseconds: 50),
      );

      await groupedController.init();
      await groupedController.startListening();

      groupedPipeline.resultController.add(
        SpeechRecognitionResult.fromTranscript(
          transcript: 'hello',
          isFinal: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      groupedPipeline.resultController.add(
        SpeechRecognitionResult.fromTranscript(
          transcript: 'there',
          isFinal: false,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      groupedPipeline.resultController.add(
        SpeechRecognitionResult.fromTranscript(
          transcript: 'there',
          isFinal: false,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final optimistic = groupedController.getOptimisticMessages();
      expect(groupedController.chatMessages, isEmpty);
      expect(optimistic.length, equals(1));
      expect(optimistic[0].original, equals('hello, there'));
      expect(optimistic[0].speaker, equals(null));

      await groupedController.stopListening();
      groupedController.dispose();
      await groupedPipeline.disposeFake();
    });

    test('consecutive final transcripts are grouped within window', () async {
      final groupedPipeline = _FakeSpeechPipeline();
      final groupedController = _buildController(
        groupedPipeline,
        finalResultGroupingWindow: const Duration(milliseconds: 50),
      );

      await groupedController.init();
      await groupedController.startListening();

      groupedPipeline.resultController.add(
        SpeechRecognitionResult.fromTranscript(
          transcript: 'hello',
          isFinal: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      groupedPipeline.resultController.add(
        SpeechRecognitionResult.fromTranscript(
          transcript: 'there',
          isFinal: true,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(groupedController.chatMessages.length, equals(1));
      expect(
        groupedController.chatMessages.first.original,
        equals('hello, there.'),
      );

      await groupedController.stopListening();
      groupedController.dispose();
      await groupedPipeline.disposeFake();
    });

    test('partial is still displayed with grouped results', () async {
      final groupedPipeline = _FakeSpeechPipeline();
      final groupedController = _buildController(
        groupedPipeline,
        finalResultGroupingWindow: const Duration(milliseconds: 50),
      );

      await groupedController.init();
      await groupedController.startListening();

      groupedPipeline.resultController.add(
        SpeechRecognitionResult(
          words: [
            SpeechRecognitionWord(word: 'hello', speaker: 0),
          ],
          isFinal: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      groupedPipeline.resultController.add(
        SpeechRecognitionResult(
          words: [
            SpeechRecognitionWord(word: 'there', speaker: 0),
          ],
          isFinal: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      groupedPipeline.resultController.add(
        SpeechRecognitionResult(
          words: [
            SpeechRecognitionWord(word: 'how', speaker: 0),
            SpeechRecognitionWord(word: 'are', speaker: 0),
            SpeechRecognitionWord(word: 'you?', speaker: 0),
          ],
          isFinal: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final optimistic = groupedController.getOptimisticMessages();
      expect(groupedController.chatMessages, isEmpty);
      expect(optimistic.length, equals(1));
      expect(optimistic[0].original, equals('hello, there, how are you?'));
      expect(optimistic[0].speaker, equals(0));
      expect(optimistic[0].groups.length, equals(3));
      expect(optimistic[0].groups.last.original, equals('how are you?'));

      await groupedController.stopListening();
      groupedController.dispose();
      await groupedPipeline.disposeFake();
    });

    test(
      'folded partial group keeps its id when it becomes queued',
      () async {
        final groupedPipeline = _FakeSpeechPipeline();
        final groupedController = _buildController(
          groupedPipeline,
          finalResultGroupingWindow: const Duration(milliseconds: 120),
        );

        await groupedController.init();
        await groupedController.startListening();

        groupedPipeline.resultController.add(
          SpeechRecognitionResult(
            words: [SpeechRecognitionWord(word: 'hello', speaker: 0)],
            isFinal: true,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        groupedPipeline.resultController.add(
          SpeechRecognitionResult(
            words: [SpeechRecognitionWord(word: 'there', speaker: 0)],
            isFinal: false,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final optimisticWithPartial = groupedController.getOptimisticMessages();
        expect(optimisticWithPartial, hasLength(1));
        final livePartialGroupId = optimisticWithPartial.single.groups.last.id;
        expect(
          livePartialGroupId,
          equals('${optimisticWithPartial.single.id}_g1'),
        );

        groupedPipeline.resultController.add(
          SpeechRecognitionResult(
            words: [SpeechRecognitionWord(word: 'there', speaker: 0)],
            isFinal: true,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final optimisticQueued = groupedController.getOptimisticMessages();
        expect(optimisticQueued, hasLength(1));
        expect(optimisticQueued.single.groups.last.id, equals(livePartialGroupId));

        await groupedController.stopListening();
        groupedController.dispose();
        await groupedPipeline.disposeFake();
      },
    );

    test(
      'consecutive final transcripts are grouped within window even when it takes awhile for second message to be final',
      () async {
        final groupedPipeline = _FakeSpeechPipeline();
        final groupedController = _buildController(
          groupedPipeline,
          finalResultGroupingWindow: const Duration(milliseconds: 50),
        );

        await groupedController.init();
        await groupedController.startListening();

        groupedPipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'hello',
            isFinal: true,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        groupedPipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'how are',
            isFinal: false,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 30));

        groupedPipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'how are you today?',
            isFinal: true,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(groupedController.chatMessages.length, equals(1));
        expect(
          groupedController.chatMessages.first.original,
          equals('hello, how are you today?'),
        );

        await groupedController.stopListening();
        groupedController.dispose();
        await groupedPipeline.disposeFake();
      },
    );

    test(
      'consecutive final transcripts exceeding finalResultGroupingWindow are not grouped',
      () async {
        final groupedPipeline = _FakeSpeechPipeline();
        final groupedController = _buildController(
          groupedPipeline,
          finalResultGroupingWindow: const Duration(milliseconds: 50),
        );

        await groupedController.init();
        await groupedController.startListening();

        groupedPipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'hello',
            isFinal: true,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));

        groupedPipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'there',
            isFinal: true,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(groupedController.chatMessages.length, equals(2));
        expect(groupedController.chatMessages[0].original, equals('hello.'));
        expect(groupedController.chatMessages[1].original, equals('there.'));

        await groupedController.stopListening();
        groupedController.dispose();
        await groupedPipeline.disposeFake();
      },
    );

    test(
      'consecutive final transcripts with final diarized words are split into speaker messages',
      () async {
        await controller.init();
        await controller.startListening();
        controller.finalResultGroupingWindow = const Duration(milliseconds: 50);

        pipeline.resultController.add(
          SpeechRecognitionResult(
            words: [
              SpeechRecognitionWord(word: 'Hello', speaker: 0),
              SpeechRecognitionWord(word: 'there', speaker: 0),
              SpeechRecognitionWord(word: 'Help', speaker: 1),
              SpeechRecognitionWord(word: 'me', speaker: 1),
              SpeechRecognitionWord(word: 'Obi-Wan', speaker: 1),
              SpeechRecognitionWord(word: 'Kenobi', speaker: 1),
            ],
            isFinal: false,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 30));

        pipeline.resultController.add(
          SpeechRecognitionResult(
            words: [
              SpeechRecognitionWord(word: 'Hello', speaker: 0),
              SpeechRecognitionWord(word: 'there', speaker: 0),
              SpeechRecognitionWord(word: 'Help', speaker: 1),
              SpeechRecognitionWord(word: 'me', speaker: 1),
              SpeechRecognitionWord(word: 'Obi-Wan', speaker: 1),
              SpeechRecognitionWord(word: 'Kenobi', speaker: 1),
              SpeechRecognitionWord(word: 'how', speaker: 0),
              SpeechRecognitionWord(word: 'are', speaker: 0),
              SpeechRecognitionWord(word: 'you', speaker: 0),
              SpeechRecognitionWord(word: 'today?', speaker: 0),
            ],
            isFinal: true,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 30));

        pipeline.resultController.add(
          SpeechRecognitionResult(
            isFinal: true,
            words: [
              SpeechRecognitionWord(word: 'you', speaker: 1),
              SpeechRecognitionWord(word: 'are', speaker: 1),
              SpeechRecognitionWord(word: 'my', speaker: 1),
              SpeechRecognitionWord(word: 'only', speaker: 1),
              SpeechRecognitionWord(word: 'hope', speaker: 1),
            ],
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(controller.chatMessages.length, equals(2));
        expect(
          controller.chatMessages[0].original,
          equals('Hello there how are you today?'),
        );
        expect(controller.chatMessages[0].speaker, equals(0));
        expect(
          controller.chatMessages[1].original,
          equals('Help me Obi-Wan Kenobi, you are my only hope.'),
        );
        expect(controller.chatMessages[1].speaker, equals(1));
        expect(controller.preferredSpeaker, equals(0));
        expect(pipeline.synthesizeCallCount, equals(2));
        expect(controller.getOptimisticMessages(), isEmpty);
      },
    );

    test(
      'consecutive pending transcripts with final diarized words are split into optimistic speaker messages',
      () async {
        await controller.init();
        await controller.startListening();
        controller.finalResultGroupingWindow = const Duration(milliseconds: 50);

        pipeline.resultController.add(
          SpeechRecognitionResult(
            words: [
              SpeechRecognitionWord(word: 'Hello', speaker: 0),
              SpeechRecognitionWord(word: 'there', speaker: 0),
              SpeechRecognitionWord(word: 'Help', speaker: 1),
              SpeechRecognitionWord(word: 'me', speaker: 1),
              SpeechRecognitionWord(word: 'Obi-Wan', speaker: 1),
              SpeechRecognitionWord(word: 'Kenobi', speaker: 1),
            ],
            isFinal: false,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 30));

        pipeline.resultController.add(
          SpeechRecognitionResult(
            words: [
              SpeechRecognitionWord(word: 'Hello', speaker: 0),
              SpeechRecognitionWord(word: 'there', speaker: 0),
              SpeechRecognitionWord(word: 'Help', speaker: 1),
              SpeechRecognitionWord(word: 'me', speaker: 1),
              SpeechRecognitionWord(word: 'Obi-Wan', speaker: 1),
              SpeechRecognitionWord(word: 'Kenobi', speaker: 1),
              SpeechRecognitionWord(word: 'how', speaker: 0),
              SpeechRecognitionWord(word: 'are', speaker: 0),
              SpeechRecognitionWord(word: 'you', speaker: 0),
              SpeechRecognitionWord(word: 'today?', speaker: 0),
            ],
            isFinal: true,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 30));

        pipeline.resultController.add(
          SpeechRecognitionResult(
            isFinal: true,
            words: [
              SpeechRecognitionWord(word: 'you', speaker: 1),
              SpeechRecognitionWord(word: 'are', speaker: 1),
              SpeechRecognitionWord(word: 'my', speaker: 1),
              SpeechRecognitionWord(word: 'only', speaker: 1),
              SpeechRecognitionWord(word: 'hope', speaker: 1),
            ],
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final optimistic = controller.getOptimisticMessages();
        expect(controller.chatMessages.length, equals(0));
        expect(optimistic.length, equals(2));
        expect(
          optimistic[0].original,
          equals('Hello there how are you today?'),
        );
        expect(optimistic[0].speaker, equals(0));
        expect(
          optimistic[1].original,
          equals('Help me Obi-Wan Kenobi, you are my only hope'),
        );
        expect(optimistic[1].speaker, equals(1));
        expect(controller.preferredSpeaker, equals(0));
        expect(pipeline.synthesizeCallCount, equals(2));
      },
    );

    test(
      'consecutive pending transcripts with final diarized words are split into optimistic speaker messages',
      () async {
        await controller.init();
        await controller.startListening();
        controller.finalResultGroupingWindow = const Duration(milliseconds: 50);

        pipeline.resultController.add(
          SpeechRecognitionResult(
            words: [
              SpeechRecognitionWord(word: 'Hello', speaker: 0),
              SpeechRecognitionWord(word: 'there', speaker: 0),
              SpeechRecognitionWord(word: 'Help', speaker: 1),
              SpeechRecognitionWord(word: 'me', speaker: 1),
              SpeechRecognitionWord(word: 'Obi-Wan', speaker: 1),
              SpeechRecognitionWord(word: 'Kenobi', speaker: 1),
            ],
            isFinal: false,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 30));

        pipeline.resultController.add(
          SpeechRecognitionResult(
            words: [
              SpeechRecognitionWord(word: 'Hello', speaker: 0),
              SpeechRecognitionWord(word: 'there', speaker: 0),
              SpeechRecognitionWord(word: 'Help', speaker: 1),
              SpeechRecognitionWord(word: 'me', speaker: 1),
              SpeechRecognitionWord(word: 'Obi-Wan', speaker: 1),
              SpeechRecognitionWord(word: 'Kenobi', speaker: 1),
              SpeechRecognitionWord(word: 'how', speaker: 0),
              SpeechRecognitionWord(word: 'are', speaker: 0),
              SpeechRecognitionWord(word: 'you', speaker: 0),
              SpeechRecognitionWord(word: 'today?', speaker: 0),
            ],
            isFinal: true,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 30));

        pipeline.resultController.add(
          SpeechRecognitionResult(
            isFinal: true,
            words: [
              SpeechRecognitionWord(word: 'you', speaker: 1),
              SpeechRecognitionWord(word: 'are', speaker: 1),
              SpeechRecognitionWord(word: 'my', speaker: 1),
              SpeechRecognitionWord(word: 'only', speaker: 1),
              SpeechRecognitionWord(word: 'hope', speaker: 1),
            ],
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final optimistic = controller.getOptimisticMessages();
        expect(controller.chatMessages.length, equals(0));
        expect(optimistic.length, equals(2));
        expect(
          optimistic[0].original,
          equals('Hello there how are you today?'),
        );
        expect(optimistic[0].speaker, equals(0));
        expect(
          optimistic[1].original,
          equals('Help me Obi-Wan Kenobi, you are my only hope'),
        );
        expect(optimistic[1].speaker, equals(1));
        expect(controller.preferredSpeaker, equals(0));
        expect(pipeline.synthesizeCallCount, equals(2));

        await Future<void>.delayed(const Duration(milliseconds: 60));
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(controller.getOptimisticMessages().length, equals(0));
        expect(controller.chatMessages.length, equals(2));
        expect(
          controller.chatMessages[0].original,
          equals('Hello there how are you today?'),
        );
        expect(controller.chatMessages[0].speaker, equals(0));
        expect(
          controller.chatMessages[1].original,
          equals('Help me Obi-Wan Kenobi, you are my only hope.'),
        );
        expect(controller.chatMessages[1].speaker, equals(1));
        expect(controller.preferredSpeaker, equals(0));
        expect(pipeline.synthesizeCallCount, equals(2));
        expect(controller.getOptimisticMessages(), isEmpty);
      },
    );

    test(
      'interleaved speakers flush independently when one continues speaking',
      () async {
        final groupedPipeline = _FakeSpeechPipeline();
        final groupedController = _buildController(
          groupedPipeline,
          finalResultGroupingWindow: const Duration(milliseconds: 100),
        );

        await groupedController.init();
        await groupedController.startListening();

        groupedPipeline.resultController.add(
          SpeechRecognitionResult(
            isFinal: true,
            words: [SpeechRecognitionWord(word: 'alpha', speaker: 0)],
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 60));

        groupedPipeline.resultController.add(
          SpeechRecognitionResult(
            isFinal: true,
            words: [SpeechRecognitionWord(word: 'bravo', speaker: 1)],
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(groupedController.chatMessages.length, equals(1));
        expect(groupedController.chatMessages.first.speaker, equals(0));
        expect(groupedController.chatMessages.first.original, equals('alpha.'));

        final optimisticMid = groupedController.getOptimisticMessages();
        expect(optimisticMid.length, equals(1));
        expect(optimisticMid.first.speaker, equals(1));
        expect(optimisticMid.first.original, equals('bravo'));

        await Future<void>.delayed(const Duration(milliseconds: 70));

        expect(groupedController.chatMessages.length, equals(2));
        expect(groupedController.chatMessages[1].speaker, equals(1));
        expect(groupedController.chatMessages[1].original, equals('bravo.'));

        await groupedController.stopListening();
        groupedController.dispose();
        await groupedPipeline.disposeFake();
      },
    );

    test(
      'partial from another speaker does not delay pending final flush',
      () async {
        final groupedPipeline = _FakeSpeechPipeline();
        final groupedController = _buildController(
          groupedPipeline,
          finalResultGroupingWindow: const Duration(milliseconds: 100),
        );

        await groupedController.init();
        await groupedController.startListening();

        groupedPipeline.resultController.add(
          SpeechRecognitionResult(
            isFinal: true,
            words: [SpeechRecognitionWord(word: 'first', speaker: 0)],
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        groupedPipeline.resultController.add(
          SpeechRecognitionResult(
            isFinal: false,
            words: [SpeechRecognitionWord(word: 'second', speaker: 1)],
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 70));

        expect(groupedController.chatMessages.length, equals(1));
        expect(groupedController.chatMessages.first.speaker, equals(0));
        expect(groupedController.chatMessages.first.original, equals('first.'));

        await groupedController.stopListening();
        groupedController.dispose();
        await groupedPipeline.disposeFake();
      },
    );
  });
}
