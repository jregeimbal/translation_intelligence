import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_intelligence/main.dart';
import 'package:translation_intelligence/services/app_preferences.dart';

import 'speech_controller_stub.dart';
import 'test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('first launch shows walkthrough and skip dismisses it', (
    tester,
  ) async {
    final controller = TestSpeechController();

    await pumpTestApp(
      tester,
      MyHomePage(themeMode: ThemeMode.light, onThemeModeChanged: (_) {}),
      speechController: controller,
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

    final controller = TestSpeechController();

    await pumpTestApp(
      tester,
      MyHomePage(themeMode: ThemeMode.light, onThemeModeChanged: (_) {}),
      speechController: controller,
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome to OmniaLingo'), findsNothing);
    expect(find.text('Tap the mic to start listening...'), findsOneWidget);
  });

  testWidgets('help button reopens walkthrough after first launch', (
    tester,
  ) async {
    await AppPreferences().setHasCompletedFirstLaunchWalkthrough(true);

    final controller = TestSpeechController();

    await pumpTestApp(
      tester,
      MyHomePage(themeMode: ThemeMode.light, onThemeModeChanged: (_) {}),
      speechController: controller,
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
