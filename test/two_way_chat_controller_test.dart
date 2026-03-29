import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:translation_intelligence/controllers/two_way_chat_controller.dart';
import 'package:translation_intelligence/models/two_way_message.dart';
import 'package:translation_intelligence/services/mic_activation_sound_player.dart';
import 'package:translation_intelligence/services/speech_pipeline.dart';

class _FakeMicActivationSoundPlayer implements MicActivationSoundPlayer {
  int playCallCount = 0;

  @override
  Future<void> play() async {
    playCallCount += 1;
  }

  @override
  Future<void> dispose() async {}
}

class _FakeTwoWaySpeechPipeline extends SpeechPipeline {
  _FakeTwoWaySpeechPipeline() : super(deepgramApiKey: 'test-deepgram');

  final StreamController<SpeechRecognitionResult> resultController =
      StreamController<SpeechRecognitionResult>.broadcast();
  final StreamController<double> amplitudeController =
      StreamController<double>.broadcast();

  bool apiKeyValid = true;
  int startRecognitionCalls = 0;
  int stopCalls = 0;
  String? lastSourceLanguage;
  String? lastTranslateText;
  String? lastTranslateSourceLanguage;
  String? lastTranslateTargetLanguage;
  String? lastSynthText;
  String? lastSynthLanguageCode;
  String translatedText = 'translated';
  Uint8List synthBytes = Uint8List(0);

  @override
  Future<bool> isSpeechApiKeyValid() async => apiKeyValid;

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
    startRecognitionCalls += 1;
    lastSourceLanguage = sourceLanguage;
    return SpeechRecognitionSession(
      resultStream: resultController.stream,
      amplitudeStream: amplitudeController.stream,
      stop: () async {
        stopCalls += 1;
      },
      sourceLanguage: sourceLanguage,
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
    lastTranslateText = text;
    lastTranslateSourceLanguage = sourceLanguage;
    lastTranslateTargetLanguage = targetLanguage;
    return translatedText;
  }

  @override
  Future<Uint8List> synthesizeSpeech({
    required String text,
    String languageCode = 'en-US',
    String ssmlGender = 'NEUTRAL',
  }) async {
    lastSynthText = text;
    lastSynthLanguageCode = languageCode;
    return synthBytes;
  }

  Future<void> disposeFake() async {
    await resultController.close();
    await amplitudeController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const recordChannel = MethodChannel('com.llfbandit.record/messages');
  const wakelockChannel = MethodChannel(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
  );
  var hasPermission = true;

  setUpAll(() {
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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(wakelockChannel, (call) async {
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(wakelockChannel, null);
  });

  group('TwoWayChatController', () {
    late _FakeTwoWaySpeechPipeline pipeline;
    late _FakeMicActivationSoundPlayer soundPlayer;
    late TwoWayChatController controller;

    setUp(() {
      hasPermission = true;
      pipeline = _FakeTwoWaySpeechPipeline();
      soundPlayer = _FakeMicActivationSoundPlayer();
      controller = TwoWayChatController(
        speechPipeline: pipeline,
        micActivationSoundPlayer: soundPlayer,
      );
    });

    tearDown(() async {
      await controller.stopListening();
      controller.dispose();
      await pipeline.disposeFake();
    });

    test(
      'init sets speechError when microphone permission is denied',
      () async {
        hasPermission = false;

        await controller.init();

        expect(controller.speechEnabled, isFalse);
        expect(controller.speechError, equals('microphonePermissionDenied'));
      },
    );

    test('init sets speechError when API key validation fails', () async {
      pipeline.apiKeyValid = false;

      await controller.init();

      expect(controller.speechEnabled, isFalse);
      expect(controller.speechError, equals('invalidSpeechApiKey'));
    });

    test(
      'language changes are disabled while listening or after messages exist',
      () async {
        await controller.init();

        controller.setPrimaryLanguage('fr');
        controller.setGuestLanguage('de');
        expect(controller.primaryLanguage, equals('fr'));
        expect(controller.guestLanguage, equals('de'));

        await controller.startListening(TwoWaySpeaker.primary);
        controller.setPrimaryLanguage('ja');
        controller.setGuestLanguage('ko');
        expect(controller.primaryLanguage, equals('fr'));
        expect(controller.guestLanguage, equals('de'));

        pipeline.translatedText = 'guten tag';
        pipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'bonjour',
            isFinal: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(controller.messages, hasLength(1));
        controller.setPrimaryLanguage('en');
        controller.setGuestLanguage('es');
        expect(controller.primaryLanguage, equals('fr'));
        expect(controller.guestLanguage, equals('de'));
      },
    );

    test(
      'toggleListening starts and stops the active speaker session',
      () async {
        await controller.init();

        await controller.toggleListening(TwoWaySpeaker.primary);

        expect(controller.isListening, isTrue);
        expect(controller.activeSpeaker, equals(TwoWaySpeaker.primary));
        expect(pipeline.startRecognitionCalls, equals(1));
        expect(pipeline.lastSourceLanguage, equals('en'));
        expect(soundPlayer.playCallCount, equals(1));

        await controller.toggleListening(TwoWaySpeaker.guest);
        expect(controller.isListening, isTrue);
        expect(controller.activeSpeaker, equals(TwoWaySpeaker.primary));
        expect(pipeline.startRecognitionCalls, equals(1));

        await controller.toggleListening(TwoWaySpeaker.primary);
        expect(controller.isListening, isFalse);
        expect(controller.activeSpeaker, isNull);
        expect(pipeline.stopCalls, equals(1));
      },
    );

    test('session errors stop listening and expose a retry message', () async {
      await controller.init();
      await controller.startListening(TwoWaySpeaker.primary);

      pipeline.resultController.addError(StateError('listeningConnectionLost'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isListening, isFalse);
      expect(controller.activeSpeaker, isNull);
      expect(
        controller.speechError,
        contains('connection could not be resumed'),
      );
    });

    test(
      'partial result updates lastWords and amplitude without creating messages',
      () async {
        await controller.init();
        await controller.startListening(TwoWaySpeaker.primary);

        pipeline.amplitudeController.add(0.42);
        pipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'hello there',
            isFinal: false,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(controller.amplitude, closeTo(0.42, 0.0001));
        expect(controller.lastWords, equals('hello there'));
        expect(controller.messages, isEmpty);
        expect(controller.isListening, isTrue);
      },
    );

    test(
      'final primary result translates, stores message, and stops listening',
      () async {
        await controller.init();
        await controller.startListening(TwoWaySpeaker.primary);
        pipeline.translatedText = 'hola mundo';

        pipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'hello world',
            isFinal: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(pipeline.lastTranslateText, equals('hello world'));
        expect(pipeline.lastTranslateSourceLanguage, equals('en'));
        expect(pipeline.lastTranslateTargetLanguage, equals('es'));

        expect(controller.messages, hasLength(1));
        final message = controller.messages.single;
        expect(message.speaker, equals(TwoWaySpeaker.primary));
        expect(message.primaryText, equals('hello world'));
        expect(message.guestText, equals('hola mundo'));

        expect(controller.lastWords, isEmpty);
        expect(controller.isListening, isFalse);
        expect(controller.activeSpeaker, isNull);
        expect(pipeline.stopCalls, equals(1));
        expect(pipeline.lastSynthText, equals('hola mundo'));
        expect(pipeline.lastSynthLanguageCode, equals('es-ES'));
      },
    );

    test(
      'final guest result swaps source and translated message fields',
      () async {
        await controller.init();
        await controller.startListening(TwoWaySpeaker.guest);
        pipeline.translatedText = 'good morning';

        pipeline.resultController.add(
          SpeechRecognitionResult.fromTranscript(
            transcript: 'buenos dias',
            isFinal: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(pipeline.lastTranslateSourceLanguage, equals('es'));
        expect(pipeline.lastTranslateTargetLanguage, equals('en'));
        expect(controller.messages, hasLength(1));
        final message = controller.messages.single;
        expect(message.speaker, equals(TwoWaySpeaker.guest));
        expect(message.primaryText, equals('good morning'));
        expect(message.guestText, equals('buenos dias'));
      },
    );
  });
}
