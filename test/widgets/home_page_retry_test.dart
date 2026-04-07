import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/controllers/two_way_chat_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_intelligence/main.dart';
import 'package:translation_intelligence/models/two_way_message.dart';
import 'package:translation_intelligence/services/backend_api_client.dart';
import 'package:translation_intelligence/services/app_preferences.dart';

import '../stubs/speech_controller_stub.dart';
import 'test_app.dart';

class FakeTwoWayChatController extends ChangeNotifier
    implements TwoWayChatController {
  bool listening = false;
  TwoWaySpeaker? listeningSpeaker;
  @override
  String deepgramRecognitionLanguage = 'multi';
  @override
  String speechToTextRecognitionLocale = 'multi';
  int startListeningCallCount = 0;
  int stopListeningCallCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #messages:
        return const <TwoWayMessage>[];
      case #canChangeLanguages:
        return true;
      case #speechEnabled:
        return true;
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
      case #deepgramRecognitionLanguage:
        return deepgramRecognitionLanguage;
      case #speechToTextRecognitionLocale:
        return speechToTextRecognitionLocale;
      case #activeSpeaker:
        return listeningSpeaker;
    }

    return super.noSuchMethod(invocation);
  }

  @override
  Future<void> startListening(TwoWaySpeaker speaker) async {
    startListeningCallCount += 1;
    listening = true;
    listeningSpeaker = speaker;
    notifyListeners();
  }

  @override
  Future<void> stopListening() async {
    stopListeningCallCount += 1;
    listening = false;
    notifyListeners();
  }

  @override
  void setDeepgramRecognitionLanguage(String language) {
    deepgramRecognitionLanguage = language;
    notifyListeners();
  }

  @override
  void setSpeechToTextRecognitionLocale(String locale) {
    speechToTextRecognitionLocale = locale;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> markWalkthroughSeen() {
    return AppPreferences().setHasCompletedFirstLaunchWalkthrough(true);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MyHomePage retries initialization after failure', (
    tester,
  ) async {
    await markWalkthroughSeen();
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = TestSpeechController();
    final twoWayController = FakeTwoWayChatController();
    final secondAttempt = Completer<HomePageInitializationBundle>();
    var initializerCalls = 0;

    Future<HomePageInitializationBundle> initializer() {
      initializerCalls += 1;
      if (initializerCalls == 1) {
        throw StateError('network unavailable');
      }

      return secondAttempt.future;
    }

    final backendApiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      authTokenProvider: () async => 'token',
    );

    await pumpTestApp(
      tester,
      MyHomePage(
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) {},
        initializer: initializer,
      ),
    );

    await tester.pump();

    expect(find.textContaining('Initialization failed'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();

    expect(initializerCalls, 2);
    expect(find.textContaining('Initialization failed'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    secondAttempt.complete(
      HomePageInitializationBundle(
        backendApiClient: backendApiClient,
        controller: controller,
        twoWayController: twoWayController,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.text('Tap the mic to start listening...'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsNothing);
  });

  testWidgets('saving settings restarts active group listening', (
    tester,
  ) async {
    await markWalkthroughSeen();
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = TestSpeechController();
    await controller.startListening();
    final twoWayController = FakeTwoWayChatController();
    final backendApiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      authTokenProvider: () async => 'token',
    );

    await pumpTestApp(
      tester,
      MyHomePage(
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) {},
        initializer: () async => HomePageInitializationBundle(
          backendApiClient: backendApiClient,
          controller: controller,
          twoWayController: twoWayController,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(controller.stopListeningCallCount, 1);
    expect(controller.startListeningCallCount, 2);
    expect(controller.isListening, isTrue);
  });

  testWidgets('changing source language restarts active group listening', (
    tester,
  ) async {
    await markWalkthroughSeen();
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = TestSpeechController();
    controller.setDeepgramRecognitionLanguage('multi');
    await controller.startListening();
    final twoWayController = FakeTwoWayChatController();
    final backendApiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      authTokenProvider: () async => 'token',
    );

    await pumpTestApp(
      tester,
      MyHomePage(
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) {},
        initializer: () async => HomePageInitializationBundle(
          backendApiClient: backendApiClient,
          controller: controller,
          twoWayController: twoWayController,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final sourceDropdown = tester.widget<DropdownMenuFormField<String>>(
      find.byType(DropdownMenuFormField<String>).first,
    );
    sourceDropdown.onSelected?.call('es');
    await tester.pumpAndSettle();

    expect(controller.stopListeningCallCount, 1);
    expect(controller.startListeningCallCount, 2);
    expect(controller.deepgramRecognitionLanguage, 'es');
    expect(controller.isListening, isTrue);
  });
}
