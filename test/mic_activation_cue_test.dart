import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:translation_intelligence/controllers/group_chat_controller.dart';
import 'package:translation_intelligence/controllers/two_way_chat_controller.dart';
import 'package:translation_intelligence/models/playback_device.dart';
import 'package:translation_intelligence/models/two_way_message.dart';
import 'package:translation_intelligence/services/mic_activation_sound_player.dart';
import 'package:translation_intelligence/services/speech_pipeline.dart';

class _FakeMicActivationSoundPlayer implements MicActivationSoundPlayer {
  int playCallCount = 0;
  int disposeCallCount = 0;

  @override
  Future<void> play() async {
    playCallCount += 1;
  }

  @override
  Future<void> dispose() async {
    disposeCallCount += 1;
  }
}

class _FakeRecognitionSpeechPipeline extends SpeechPipeline {
  _FakeRecognitionSpeechPipeline() : super(deepgramApiKey: 'test-deepgram');

  final StreamController<SpeechRecognitionResult> resultController =
      StreamController<SpeechRecognitionResult>.broadcast();
  final StreamController<double> amplitudeController =
      StreamController<double>.broadcast();

  int startRecognitionCalls = 0;
  bool apiKeyValid = true;
  String? lastSourceLanguage;

  @override
  Future<bool> isSpeechApiKeyValid() async => apiKeyValid;

  @override
  Future<List<PlaybackDevice>> listPlaybackDevices() async => const [];

  @override
  Future<String?> getCurrentPlaybackDeviceId() async => null;

  @override
  Stream<dynamic> listeningDeviceRouteChanges() => const Stream<dynamic>.empty();

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
      stop: () async {},
      sourceLanguage: sourceLanguage,
    );
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

  setUpAll(() {
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
        .setMockMethodCallHandler(recordChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(wakelockChannel, null);
  });

  test('GroupChatController plays activation cue after listening starts', () async {
    final pipeline = _FakeRecognitionSpeechPipeline();
    final soundPlayer = _FakeMicActivationSoundPlayer();
    final controller = GroupChatController(
      speechPipeline: pipeline,
      micActivationSoundPlayer: soundPlayer,
    );

    addTearDown(() async {
      await controller.stopListening();
      controller.dispose();
      await pipeline.disposeFake();
    });

    await controller.init();
    await controller.startListening();

    expect(controller.isListening, isTrue);
    expect(pipeline.startRecognitionCalls, equals(1));
    expect(soundPlayer.playCallCount, equals(1));
  });

  test('TwoWayChatController plays activation cue after listening starts', () async {
    final pipeline = _FakeRecognitionSpeechPipeline();
    final soundPlayer = _FakeMicActivationSoundPlayer();
    final controller = TwoWayChatController(
      speechPipeline: pipeline,
      micActivationSoundPlayer: soundPlayer,
    );

    addTearDown(() async {
      await controller.stopListening();
      controller.dispose();
      await pipeline.disposeFake();
    });

    await controller.init();
    await controller.startListening(TwoWaySpeaker.primary);

    expect(controller.isListening, isTrue);
    expect(controller.activeSpeaker, equals(TwoWaySpeaker.primary));
    expect(pipeline.startRecognitionCalls, equals(1));
    expect(pipeline.lastSourceLanguage, equals('en'));
    expect(soundPlayer.playCallCount, equals(1));
  });
}