import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_intelligence/controllers/two_way_chat_controller.dart';
import 'package:translation_intelligence/main.dart';
import 'package:translation_intelligence/models/suggested_response.dart';
import 'package:translation_intelligence/models/two_way_message.dart';
import 'package:translation_intelligence/services/app_preferences.dart';
import 'package:translation_intelligence/services/backend_api_client.dart';

import 'speech_controller_stub.dart';
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

  void emitSuggestedResponse(TestSpeechController controller) {
    controller.emitSuggestedResponse(
      SuggestedResponseEvent(
        messageId: 'msg_1',
        response: const SuggestedResponse(
          originalText: 'claro que si',
          translatedText: 'of course',
          sourceLanguageCode: 'es',
          targetLanguageCode: 'en',
        ),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('group chat suggested response snackbar can be dismissed', (
    tester,
  ) async {
    final controller = TestSpeechController();
    final backendApiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      authTokenProvider: () async => 'token',
    );

    await pumpSuggestedResponseApp(tester, controller, backendApiClient);

    emitSuggestedResponse(controller);

    await tester.pumpAndSettle();

    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Suggested response'), findsNothing);
    expect(find.text('claro que si'), findsNothing);
    expect(find.text('of course'), findsNothing);

    backendApiClient.close();
  });

  testWidgets('group chat shows and auto-hides suggested response snackbar', (
    tester,
  ) async {
    final controller = TestSpeechController();
    final backendApiClient = BackendApiClient(
      baseUrl: 'https://example.com',
      authTokenProvider: () async => 'token',
    );

    await pumpSuggestedResponseApp(tester, controller, backendApiClient);

    emitSuggestedResponse(controller);

    await tester.pumpAndSettle();

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
}
