import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/models/chat_message.dart';
import 'package:translation_intelligence/models/playback_device.dart';
import 'package:translation_intelligence/services/backend_api_client.dart';
import 'package:translation_intelligence/services/mic_activation_sound_player.dart';
import 'package:translation_intelligence/services/speech_output_provider.dart';
import 'package:translation_intelligence/services/speech_pipeline.dart';
import 'package:translation_intelligence/services/speech_stt_provider.dart';
import 'package:translation_intelligence/services/speech_translation_provider.dart';

class _FakeMicActivationSoundPlayer implements MicActivationSoundPlayer {
  @override
  Future<void> play() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeSpeechPipeline extends SpeechPipeline {
  _FakeSpeechPipeline()
    : super(
        backendApiClient: BackendApiClient(
          baseUrl: 'https://api.example.com',
          authTokenProvider: () async => 'token',
        ),
      );

  bool apiKeyValid = true;
  int startRecognitionCalls = 0;
  String? lastSourceLanguage;
  final StreamController<dynamic> routeChanges =
      StreamController<dynamic>.broadcast();
  List<PlaybackDevice> playbackDevices = const [];
  String? currentPlaybackRouteId;
  SpeechRecognitionSession session = SpeechRecognitionSession(
    resultStream: Stream<SpeechRecognitionResult>.empty(),
    amplitudeStream: Stream<double>.empty(),
    stop: _noopStop,
  );

  static Future<void> _noopStop() async {}

  @override
  Future<bool> isSpeechApiKeyValid() async => apiKeyValid;

  @override
  Future<List<PlaybackDevice>> listPlaybackDevices() async => playbackDevices;

  @override
  Future<String?> getCurrentPlaybackDeviceId() async => currentPlaybackRouteId;

  @override
  Stream<dynamic> listeningDeviceRouteChanges() => routeChanges.stream;

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
    return session;
  }

  Future<void> disposeFake() async {
    await routeChanges.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const audioGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const recordChannel = MethodChannel('com.llfbandit.record/messages');
  var hasPermission = true;
  List<Map<String, dynamic>> mockInputDevices = const [];

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
          if (call.method == 'listInputDevices') {
            return mockInputDevices;
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
      mockInputDevices = const [];
      controller = SpeechController(
        backendApiClient: BackendApiClient(
          baseUrl: 'https://api.example.com',
          authTokenProvider: () async => 'token',
        ),
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
      expect(controller.hasSupportedTargetLanguage, isTrue);
    });

    test('supportedLanguages contains expected baseline entries', () {
      expect(SpeechController.supportedLanguages, contains('en'));
      expect(SpeechController.supportedLanguages, contains('es'));
      expect(SpeechController.supportedLanguages, contains('zh-CN'));
    });

    test('setTargetLanguage updates and notifies only on changes', () {
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setTargetLanguage('es');
      expect(controller.targetLanguage, equals('es'));
      expect(controller.hasSupportedTargetLanguage, isTrue);
      expect(notifications, equals(1));

      controller.setTargetLanguage('es');
      expect(notifications, equals(1));
    });

    test('hasSupportedTargetLanguage is false for unknown language', () {
      controller.setTargetLanguage('xx-custom');
      expect(controller.targetLanguage, equals('xx-custom'));
      expect(controller.hasSupportedTargetLanguage, isFalse);
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
      expect(() => messages.add(ChatMessage('Hello')), throwsUnsupportedError);
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
      controller.setTranslationProvider(SpeechTranslationProvider.google);
      controller.setDeepgramRecognitionModel('nova-3-medical');
      controller.setDeepgramRecognitionLanguage('en-US');
      expect(notifications, equals(4));
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
      final fakePipeline = _FakeSpeechPipeline()..apiKeyValid = false;
      final localController = SpeechController(
        backendApiClient: BackendApiClient(
          baseUrl: 'https://api.example.com',
          authTokenProvider: () async => 'token',
        ),
        speechPipeline: fakePipeline,
      );
      addTearDown(localController.dispose);

      await localController.init();

      expect(localController.speechEnabled, isFalse);
      expect(localController.speechError, equals('invalidSpeechApiKey'));
    });

    test(
      'startListening uses deepgram language for deepgram STT provider',
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
          backendApiClient: BackendApiClient(
            baseUrl: 'https://api.example.com',
            authTokenProvider: () async => 'token',
          ),
          speechPipeline: fakePipeline,
          micActivationSoundPlayer: _FakeMicActivationSoundPlayer(),
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
      },
    );

    test(
      'startListening uses multi source for non-deepgram STT provider',
      () async {
        final fakePipeline = _FakeSpeechPipeline();
        final localController = SpeechController(
          backendApiClient: BackendApiClient(
            baseUrl: 'https://api.example.com',
            authTokenProvider: () async => 'token',
          ),
          speechPipeline: fakePipeline,
          micActivationSoundPlayer: _FakeMicActivationSoundPlayer(),
        );
        addTearDown(localController.dispose);

        await localController.init();
        localController.setSttProvider(SpeechSttProvider.google);
        await localController.startListening();

        expect(localController.isListening, isTrue);
        expect(fakePipeline.lastSourceLanguage, equals('multi'));
        expect(fakePipeline.startRecognitionCalls, equals(1));
      },
    );

    test('session errors stop listening and expose a retry message', () async {
      final results = StreamController<SpeechRecognitionResult>.broadcast();
      final amplitudes = StreamController<double>.broadcast();
      final fakePipeline = _FakeSpeechPipeline()
        ..session = SpeechRecognitionSession(
          resultStream: results.stream,
          amplitudeStream: amplitudes.stream,
          stop: () async {},
        );
      final localController = SpeechController(
        backendApiClient: BackendApiClient(
          baseUrl: 'https://api.example.com',
          authTokenProvider: () async => 'token',
        ),
        speechPipeline: fakePipeline,
        micActivationSoundPlayer: _FakeMicActivationSoundPlayer(),
      );
      addTearDown(() async {
        await results.close();
        await amplitudes.close();
        localController.dispose();
      });

      await localController.init();
      await localController.startListening();

      results.addError(StateError('listeningConnectionLost'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(localController.isListening, isFalse);
      expect(
        localController.speechError,
        contains('connection could not be resumed'),
      );
    });

    test(
      'route changes refresh devices and emit listening device update',
      () async {
        final fakePipeline = _FakeSpeechPipeline()
          ..playbackDevices = const [
            PlaybackDevice(id: 'speaker', name: 'Phone', type: 'Built-in'),
          ]
          ..currentPlaybackRouteId = 'speaker';
        final localController = SpeechController(
          backendApiClient: BackendApiClient(
            baseUrl: 'https://api.example.com',
            authTokenProvider: () async => 'token',
          ),
          speechPipeline: fakePipeline,
        );
        addTearDown(() async {
          await fakePipeline.disposeFake();
          localController.dispose();
        });

        mockInputDevices = const [
          {'id': 'built-in', 'label': 'Built-in Mic'},
        ];

        await localController.init();
        localController.setListeningDeviceId('built-in');

        final received = <String>[];
        final sub = localController.listeningDeviceUpdates.listen(received.add);
        addTearDown(sub.cancel);

        mockInputDevices = const [
          {'id': 'usb', 'label': 'USB Mic'},
        ];
        fakePipeline.playbackDevices = const [
          PlaybackDevice(id: 'bt', name: 'AirPods', type: 'Bluetooth'),
        ];
        fakePipeline.currentPlaybackRouteId = 'bt';

        fakePipeline.routeChanges.add({'event': 'devices_added'});
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(localController.listeningDevices.map((d) => d.id), ['usb']);
        expect(localController.listeningDeviceId, isNull);
        expect(localController.playbackDevices.map((d) => d.id), ['bt']);
        expect(localController.playbackDeviceId, equals('bt'));
        expect(received, contains('microphoneConnected'));
      },
    );

    test(
      'route changes with no effective device change do not emit update',
      () async {
        final fakePipeline = _FakeSpeechPipeline()
          ..playbackDevices = const [
            PlaybackDevice(id: 'speaker', name: 'Phone', type: 'Built-in'),
          ]
          ..currentPlaybackRouteId = 'speaker';
        final localController = SpeechController(
          backendApiClient: BackendApiClient(
            baseUrl: 'https://api.example.com',
            authTokenProvider: () async => 'token',
          ),
          speechPipeline: fakePipeline,
        );
        addTearDown(() async {
          await fakePipeline.disposeFake();
          localController.dispose();
        });

        mockInputDevices = const [
          {'id': 'built-in', 'label': 'Built-in Mic'},
        ];

        await localController.init();

        final received = <String>[];
        final sub = localController.listeningDeviceUpdates.listen(received.add);
        addTearDown(sub.cancel);

        fakePipeline.routeChanges.add({'event': 'route_changed'});
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(received, isEmpty);
      },
    );
  });
}
