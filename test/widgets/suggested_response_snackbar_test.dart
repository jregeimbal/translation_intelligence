import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_intelligence/controllers/two_way_chat_controller.dart';
import 'package:translation_intelligence/main.dart';
import 'package:translation_intelligence/models/chat_message.dart';
import 'package:translation_intelligence/models/suggested_response.dart';
import 'package:translation_intelligence/models/two_way_message.dart';
import 'package:translation_intelligence/services/app_preferences.dart';
import 'package:translation_intelligence/services/backend_api_client.dart';
import 'package:translation_intelligence/widgets/chat_message.dart';

import '../stubs/speech_controller_stub.dart';
import 'test_app.dart';

class _FakeTwoWayChatController extends ChangeNotifier
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
      case #activeSessionSampleRate:
      case #activeSessionSttProvider:
      case #activeSessionSourceLanguage:
      case #activeSessionResolvedLanguageCode:
      case #activeSessionListeningDeviceId:
      case #activeSessionStartedAt:
      case #activeSpeaker:
        return null;
      case #primaryLanguage:
        return 'en';
      case #guestLanguage:
        return 'es';
      case #deepgramRecognitionLanguage:
      case #speechToTextRecognitionLocale:
        return 'multi';
    }

    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSuggestedResponseApp(
    WidgetTester tester,
    TestSpeechController controller,
    BackendApiClient backendApiClient,
  ) async {
    await AppPreferences().setHasCompletedFirstLaunchWalkthrough(true);

    await pumpTestApp(
      tester,
      MyHomePage(
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) {},
        initializer: () async => HomePageInitializationBundle(
          backendApiClient: backendApiClient,
          controller: controller,
          twoWayController: _FakeTwoWayChatController(),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  void emitCustomSuggestedResponse(
    TestSpeechController controller, {
    required String originalText,
    required String translatedText,
    required String messageId,
    String sourceLanguageCode = 'es',
    String targetLanguageCode = 'en',
  }) {
    controller.emitSuggestedResponse(
      SuggestedResponseEvent(
        messageId: messageId,
        response: SuggestedResponse(
          originalText: originalText,
          translatedText: translatedText,
          sourceLanguageCode: sourceLanguageCode,
          targetLanguageCode: targetLanguageCode,
        ),
      ),
    );
  }

  void emitSuggestedResponse(TestSpeechController controller) {
    emitCustomSuggestedResponse(
      controller,
      originalText: 'claro que si',
      translatedText: 'of course',
      messageId: 'msg_1',
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('group chat suggested response panel can be dismissed', (
    tester,
  ) async {
    final controller = TestSpeechController();
    final backendApiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      authTokenProvider: () async => 'token',
    );

    await pumpSuggestedResponseApp(tester, controller, backendApiClient);

    emitSuggestedResponse(controller);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('suggested-response-panel')), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Suggested response'), findsNothing);
    expect(find.text('claro que si'), findsNothing);
    expect(find.text('of course'), findsNothing);

    backendApiClient.close();
  });

  testWidgets('group chat shows and auto-hides suggested response panel', (
    tester,
  ) async {
    final controller = TestSpeechController();
    final backendApiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      authTokenProvider: () async => 'token',
    );

    await pumpSuggestedResponseApp(tester, controller, backendApiClient);

    emitSuggestedResponse(controller);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('suggested-response-panel')), findsOneWidget);
    expect(find.text('Suggested response'), findsOneWidget);
    expect(find.text('claro que si'), findsOneWidget);
    expect(find.text('of course'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();

    expect(find.text('Suggested response'), findsNothing);
    expect(find.text('claro que si'), findsNothing);
    expect(find.text('of course'), findsNothing);
  });

  testWidgets('group chat shows timeout progress on dismiss icon', (
    tester,
  ) async {
    final controller = TestSpeechController();
    final backendApiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      authTokenProvider: () async => 'token',
    );

    await pumpSuggestedResponseApp(tester, controller, backendApiClient);

    emitSuggestedResponse(controller);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const Key('suggested-response-timeout-progress')),
      findsOneWidget,
    );

    final initialIndicator = tester.widget<CircularProgressIndicator>(
      find.byKey(const Key('suggested-response-timeout-progress')),
    );
    expect(initialIndicator.value!, greaterThan(0.95));

    await tester.pump(const Duration(seconds: 5));

    final midIndicator = tester.widget<CircularProgressIndicator>(
      find.byKey(const Key('suggested-response-timeout-progress')),
    );
    expect(midIndicator.value, closeTo(0.5, 0.05));

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Suggested response'), findsNothing);
  });

  testWidgets(
    'group chat pushes message list up while suggestion panel is visible',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = TestSpeechController();
      for (var index = 0; index < 20; index += 1) {
        controller.addMessage(
          ChatMessage(
            'message $index',
            speaker: index.isEven ? 0 : 1,
            isFinal: true,
          )..translation = 'translation $index',
        );
      }
      final backendApiClient = BackendApiClient(
        baseUrl: 'https://example.com',
        authTokenProvider: () async => 'token',
      );

      await pumpSuggestedResponseApp(tester, controller, backendApiClient);

      final beforePanelRect = tester.getRect(find.byType(ChatMessageList));

      emitSuggestedResponse(controller);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final afterPanelRect = tester.getRect(find.byType(ChatMessageList));

      expect(find.byKey(const Key('suggested-response-panel')), findsOneWidget);
      expect(afterPanelRect.height, lessThan(beforePanelRect.height));

      backendApiClient.close();
    },
  );

  testWidgets(
    'second suggested response replaces the first and resets timeout',
    (tester) async {
      final controller = TestSpeechController();
      final backendApiClient = BackendApiClient(
        baseUrl: 'https://example.com',
        authTokenProvider: () async => 'token',
      );

      await pumpSuggestedResponseApp(tester, controller, backendApiClient);

      emitCustomSuggestedResponse(
        controller,
        originalText: 'primera respuesta',
        translatedText: 'first reply',
        messageId: 'msg_1',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('primera respuesta'), findsOneWidget);
      expect(find.text('first reply'), findsOneWidget);

      await tester.pump(const Duration(seconds: 9));

      emitCustomSuggestedResponse(
        controller,
        originalText: 'segunda respuesta',
        translatedText: 'second reply',
        messageId: 'msg_2',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('primera respuesta'), findsNothing);
      expect(find.text('first reply'), findsNothing);
      expect(find.text('segunda respuesta'), findsOneWidget);
      expect(find.text('second reply'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('suggested-response-panel')), findsOneWidget);

      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('suggested-response-panel')), findsNothing);

      backendApiClient.close();
    },
  );

  testWidgets('leaving group chat hides the suggested response panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = TestSpeechController();
    final backendApiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      authTokenProvider: () async => 'token',
    );

    await pumpSuggestedResponseApp(tester, controller, backendApiClient);

    emitSuggestedResponse(controller);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('suggested-response-panel')), findsOneWidget);

    await tester.tap(find.text('2-way'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('suggested-response-panel')), findsNothing);

    backendApiClient.close();
  });
}
