import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_intelligence/controllers/two_way_chat_controller.dart';
import 'package:translation_intelligence/main.dart';
import 'package:translation_intelligence/models/two_way_message.dart';
import 'package:translation_intelligence/services/app_preferences.dart';
import 'package:translation_intelligence/services/backend_api_client.dart';

import 'group_controller_stub.dart';
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
        return 'multi';
      case #speechToTextRecognitionLocale:
        return 'multi';
    }

    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  HomePageInitializationBundle buildBundle() {
    return HomePageInitializationBundle(
      backendApiClient: BackendApiClient(
        baseUrl: 'https://example.com',
        authTokenProvider: () async => 'token',
      ),
      groupController: TestGroupController(),
      twoWayController: _FakeTwoWayChatController(),
    );
  }

  testWidgets('first launch shows walkthrough and skip dismisses it', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      MyHomePage(
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) {},
        initializer: () async => buildBundle(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome to OmniaLingo'), findsOneWidget);
    expect(find.text('Choose the right mode'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Skip'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to OmniaLingo'), findsNothing);

    final snapshot = await AppPreferences().load();
    expect(snapshot.hasCompletedFirstLaunchWalkthrough, isTrue);
  });

  testWidgets('completed walkthrough does not show again on launch', (
    tester,
  ) async {
    await AppPreferences().setHasCompletedFirstLaunchWalkthrough(true);

    await pumpTestApp(
      tester,
      MyHomePage(
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) {},
        initializer: () async => buildBundle(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome to OmniaLingo'), findsNothing);
    expect(find.text('Tap the mic to start listening...'), findsOneWidget);
  });

  testWidgets('help button reopens walkthrough after first launch', (
    tester,
  ) async {
    await AppPreferences().setHasCompletedFirstLaunchWalkthrough(true);

    await pumpTestApp(
      tester,
      MyHomePage(
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) {},
        initializer: () async => buildBundle(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome to OmniaLingo'), findsNothing);
    expect(find.byTooltip('Help'), findsOneWidget);

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to OmniaLingo'), findsOneWidget);
    expect(find.text('Choose the right mode'), findsOneWidget);
  });
}
