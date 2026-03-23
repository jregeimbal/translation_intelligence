import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:translation_intelligence/controllers/two_way_chat_controller.dart';
import 'package:translation_intelligence/models/two_way_message.dart';
import 'package:translation_intelligence/widgets/recording_toggle_button.dart';
import 'package:translation_intelligence/widgets/two_way_chat.dart';

import 'speech_controller_stub.dart';
import 'test_app.dart';

class _TestTwoWayChatController extends ChangeNotifier
    implements TwoWayChatController {
  _TestTwoWayChatController({
    this.listening = false,
    this.listeningSpeaker,
    this.speechEnabledValue = true,
  });

  bool listening;
  TwoWaySpeaker? listeningSpeaker;
  bool speechEnabledValue;
  int toggleListeningCallCount = 0;
  TwoWaySpeaker? lastToggleSpeaker;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #messages:
        return const <TwoWayMessage>[];
      case #canChangeLanguages:
        return true;
      case #speechEnabled:
        return speechEnabledValue;
      case #isListening:
        return listening;
      case #speechError:
      case #lastWords:
        return '';
      case #amplitude:
        return 0.0;
      case #activeSessionSampleRate:
      case #activeSessionSttProvider:
      case #activeSessionSourceLanguage:
      case #activeSessionResolvedLanguageCode:
      case #activeSessionListeningDeviceId:
      case #activeSessionStartedAt:
        return null;
      case #primaryLanguage:
        return 'en';
      case #guestLanguage:
        return 'es';
      case #activeSpeaker:
        return listeningSpeaker;
    }

    return super.noSuchMethod(invocation);
  }

  @override
  Future<void> toggleListening(TwoWaySpeaker speaker) async {
    toggleListeningCallCount += 1;
    lastToggleSpeaker = speaker;
    listening = !listening;
    listeningSpeaker = listening ? speaker : null;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platformCalls = <MethodCall>[];

  setUp(() {
    platformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('group chat mic plays click sound before starting listening', (
    tester,
  ) async {
    final controller = TestSpeechController();

    await pumpTestApp(
      tester,
      ChangeNotifierProvider.value(value: controller, child: const SpeechFab()),
    );

    platformCalls.clear();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(controller.startListeningCallCount, equals(1));
    expect(
      platformCalls
          .where((call) => call.method == 'SystemSound.play')
          .map((call) => call.arguments)
          .toList(),
      equals(['SystemSoundType.click']),
    );
  });

  testWidgets('two-way chat mic plays click sound before starting listening', (
    tester,
  ) async {
    final controller = _TestTwoWayChatController();

    await pumpTestApp(
      tester,
      ChangeNotifierProvider<TwoWayChatController>.value(
        value: controller,
        child: const TwoWayChatView(),
      ),
    );

    platformCalls.clear();

    await tester.tap(find.widgetWithText(FilledButton, 'Listen').first);
    await tester.pump();

    expect(controller.toggleListeningCallCount, equals(1));
    expect(controller.lastToggleSpeaker, equals(TwoWaySpeaker.guest));
    expect(
      platformCalls
          .where((call) => call.method == 'SystemSound.play')
          .map((call) => call.arguments)
          .toList(),
      equals(['SystemSoundType.click']),
    );
  });

  testWidgets('two-way chat stop action does not request click sound', (
    tester,
  ) async {
    final controller = _TestTwoWayChatController(
      listening: true,
      listeningSpeaker: TwoWaySpeaker.guest,
    );

    await pumpTestApp(
      tester,
      ChangeNotifierProvider<TwoWayChatController>.value(
        value: controller,
        child: const TwoWayChatView(),
      ),
    );

    platformCalls.clear();

    await tester.tap(
      find.widgetWithIcon(FilledButton, Icons.stop_rounded).first,
    );
    await tester.pump();

    expect(controller.toggleListeningCallCount, equals(1));
    expect(
      platformCalls.where((call) => call.method == 'SystemSound.play'),
      isEmpty,
    );
  });
}
