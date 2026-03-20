import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/controllers/two_way_chat_controller.dart';
import 'package:translation_intelligence/main.dart';
import 'package:translation_intelligence/models/two_way_message.dart';
import 'package:translation_intelligence/services/backend_api_client.dart';

import 'speech_controller_stub.dart';

class FakeTwoWayChatController extends ChangeNotifier
    implements TwoWayChatController {
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
        return false;
      case #speechError:
      case #lastWords:
        return '';
      case #amplitude:
        return 0.0;
      case #activeSpeaker:
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
    }

    return super.noSuchMethod(invocation);
  }
}

void main() {
  testWidgets('MyHomePage retries initialization after failure', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) {},
          initializer: initializer,
        ),
      ),
    );

    await tester.pump();

    expect(find.textContaining('Initialization failed:'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();

    expect(initializerCalls, 2);
    expect(find.textContaining('Initialization failed:'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    secondAttempt.complete(
      HomePageInitializationBundle(
        backendApiClient: backendApiClient,
        controller: controller,
        twoWayController: twoWayController,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Translation Studio'), findsOneWidget);
    expect(find.text('Tap the mic to start listening...'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsNothing);
  });
}
