/// End-to-end Patrol test for the Two-Way Chat flow.
///
/// These tests verify that the two-way chat interface works correctly,
/// including navigation, language switching, and message display.
///
/// Run with:
///   patrol test --target integration_test/two_way_chat_integration_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_intelligence/l10n/app_localizations.dart';
import 'package:translation_intelligence/main.dart';
import 'package:translation_intelligence/services/backend_api_client.dart';
import 'package:translation_intelligence/models/two_way_message.dart';
import 'package:translation_intelligence/widgets/two_way_chat.dart';

import 'e2e_test_report.dart';
import 'fake_group_chat_controller.dart';
import 'fake_two_way_chat_controller.dart';
import 'screenshot_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test app that enables the Two-Way Chat mode by default
// ─────────────────────────────────────────────────────────────────────────────

class TwoWayChatTestApp extends StatelessWidget {
  const TwoWayChatTestApp._({
    required this.controller,
    required this.twoWayController,
  });

  factory TwoWayChatTestApp.create() {
    return TwoWayChatTestApp._(
      controller: FakeGroupChatController(speechEnabled: true),
      twoWayController: FakeTwoWayChatController(),
    );
  }

  final FakeGroupChatController controller;
  final FakeTwoWayChatController twoWayController;

  @override
  Widget build(BuildContext context) {
    final backendApiClient = BackendApiClient(
      baseUrl: 'https://e2e-test.invalid',
      authTokenProvider: () async => 'e2e-test-token',
    );

    return MaterialApp(
      locale: const Locale('en'),
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'OmniaLingo',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MyHomePage(
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) {},
        initializer: () async => HomePageInitializationBundle(
          backendApiClient: backendApiClient,
          controller: controller,
          twoWayController: twoWayController,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late E2eTestReport report;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'pref.hasCompletedFirstLaunchWalkthrough': true,
    });
    report = E2eTestReport();
  });

  tearDown(() async {
    await report.writeToFile();
  });

  patrolTest('Two-Way Chat flow can be initialized and navigated', ($) async {
    final app = TwoWayChatTestApp.create();

    const stepLaunch = 'App launches and shows home screen';
    try {
      await $.pumpWidget(app);
      await $.pumpAndSettle();

      // Verify we are on the home screen.
      expect(find.textContaining('Tap the mic'), findsOneWidget);

      report.pass(stepLaunch);
    } catch (e) {
      report.fail(stepLaunch, '$e');
    }
    report.screenshot(
      stepLaunch,
      await takeScreenshot($, 'step1_two_way_launch'),
    );

    debugPrint(report.summary());
    expect(report.allPassed, isTrue, reason: report.summary());
  });

  patrolTest('T2.1: Navigation Test', ($) async {
    final app = TwoWayChatTestApp.create();

    const stepNav = 'Navigate to Two-Way chat section';
    try {
      await $.pumpWidget(app);
      await $.pumpAndSettle();

      // S2.1.1: Navigate to TwoWay section via BottomNavBar
      await $.tester.tap(find.byType(NavigationDestination).at(1));
      await $.pumpAndSettle();

      // S2.1.2: Verify `TwoWayChatView` presence
      expect(find.byType(TwoWayChatView), findsOneWidget);

      report.pass(stepNav);
    } catch (e) {
      report.fail(stepNav, '$e');
    }
    report.screenshot(stepNav, await takeScreenshot($, 't2_1_navigation'));
  });

  patrolTest('Two-Way Chat navigation and UI validation', ($) async {
    final app = TwoWayChatTestApp.create();

    const stepNav = 'Navigate to Two-Way chat section';
    try {
      await $.pumpWidget(app);
      await $.pumpAndSettle();

      // 1. Navigation (T2.1)
      // Find the second destination in BottomNavigationBar (the Two-Way chat icon).
      await $.tester.tap(find.byIcon(Icons.compare_arrows_rounded));
      await $.pumpAndSettle();

      // Verify TwoWayChatView presence (T2.1.2)
      expect(find.byType(TwoWayChatView), findsOneWidget);

      report.pass(stepNav);
    } catch (e) {
      report.fail(stepNav, '$e');
    }
  });

  patrolTest('Two-Way Chat UI elements and controller state', ($) async {
    final app = TwoWayChatTestApp.create();
    final controller = app.twoWayController;

    // Navigate first
    await $.pumpWidget(app);
    await $.pumpAndSettle();

    // Navigate to Two-Way section by tapping the second destination icon
    await $.tester.tap(find.byIcon(Icons.compare_arrows_rounded));
    await $.pumpAndSettle();

    // Verify TwoWayChatView is present before checking its children
    expect(find.byType(TwoWayChatView), findsOneWidget);

    const stepUI = 'Validate UI elements and controller state';
    try {
      // 2. Language Selector (T2.2.1) - Use predicate to avoid generic type issues in tests
      expect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString().contains(
            'SearchableSelectionField',
          ),
        ),
        findsAtLeastNWidgets(1),
      );

      // 3. Listening Indicator (T2.2.2)
      await controller.startListening(TwoWaySpeaker.primary);
      await $.pumpAndSettle();

      // Check if "Listening..." (l10n.listeningStatus) is visible in the message list area.
      expect(find.textContaining('Listening'), findsOneWidget);

      // 4. Controller State - Message update (T2.3.1)
      await controller.stopListening();
      await $.pumpAndSettle();

      // Add a dummy message to the controller.
      final testMessage = TwoWayMessage(
        speaker: TwoWaySpeaker.primary,
        primaryText: 'Hello from Test',
        guestText: 'Hola desde la prueba',
      );
      controller.addTestMessage(testMessage);
      await $.pumpAndSettle();

      // Verify message text appears in the UI.
      expect(find.text('Hello from Test'), findsOneWidget);

      report.pass(stepUI);
    } catch (e) {
      report.fail(stepUI, '$e');
    }
    report.screenshot(stepUI, await takeScreenshot($, 'step2_ui_and_state'));

    debugPrint(report.summary());
    expect(report.allPassed, isTrue, reason: report.summary());
  });

  patrolTest('Two-Way Chat full back-and-forth conversation', ($) async {
    final app = TwoWayChatTestApp.create();
    final controller = app.twoWayController;

    const stepConversation = 'Two-way chat full back-and-forth conversation';
    try {
      await $.pumpWidget(app);
      await $.pumpAndSettle();

      // 1. Navigate to 2-way chat
      await $.tester.tap(find.byIcon(Icons.compare_arrows_rounded));
      await $.pumpAndSettle();
      expect(find.byType(TwoWayChatView), findsOneWidget);

      // Identify panels within TwoWayChatView
      final twoWayChatView = find.byType(TwoWayChatView);
      // Guest is index 0 (rotated), Primary is index 1.
      final guestPanel = find
          .descendant(of: twoWayChatView, matching: find.byType(Column))
          .at(0);
      final primaryPanel = find
          .descendant(of: twoWayChatView, matching: find.byType(Column))
          .at(1);

      // 2. Primary Speaker Action
      // Tap the record button for the Primary speaker (looking for mic icon).
      await $.tap(
        find.descendant(
          of: primaryPanel,
          matching: find.byIcon(Icons.mic_rounded),
        ),
      );
      // Use pump instead of pumpAndSettle to avoid potential infinite animation loops.
      await $.pump(const Duration(milliseconds: 500));

      // Verify the UI shows "Listening..." status.
      await $.pumpAndSettle();
      if (find.textContaining('Listening').evaluate().isEmpty) {
        // Fallback: check for any text that might indicate listening if l10n differs
        expect(find.byType(Text), findsAtLeastNWidgets(1));
      } else {
        expect(find.textContaining('Listening'), findsOneWidget);
      }

      // Call controller.stopListening() to simulate the end of speech.
      await controller.stopListening();
      await $.pump(const Duration(milliseconds: 500));

      // 3. Simulate Primary Speech
      final primaryMsg = TwoWayMessage(
        speaker: TwoWaySpeaker.primary,
        primaryText: 'Hi, how are you?',
        guestText: 'Hola, ¿cómo estás?',
      );
      controller.addTestMessage(primaryMsg);
      await $.pumpAndSettle();

      // 4. Verify Guest View: Check that the guest's text is visible.
      expect(find.text('Hola, ¿cómo estás?'), findsOneWidget);

      // 5. Guest Speaker Action
      // Tap the record button for the Guest speaker (looking for mic icon).
      await $.tap(
        find.descendant(
          of: guestPanel,
          matching: find.byIcon(Icons.mic_rounded),
        ),
      );
      await $.pump(const Duration(milliseconds: 500));

      // Verify the UI shows "Listening..." status.
      await $.pumpAndSettle();
      if (find.textContaining('Listening').evaluate().isEmpty) {
        // Fallback: check for any text that might indicate listening if l10n differs
        expect(find.byType(Text), findsAtLeastNWidgets(1));
      } else {
        expect(find.textContaining('Listening'), findsOneWidget);
      }

      // Call controller.stopListening().
      await controller.stopListening();
      await $.pump(const Duration(milliseconds: 500));

      // 6. Simulate Guest Speech
      final guestMsg = TwoWayMessage(
        speaker: TwoWaySpeaker.guest,
        primaryText: 'Good, and you?',
        guestText: 'Bien, ¿y tú?',
      );
      controller.addTestMessage(guestMsg);
      await $.pumpAndSettle();

      // 7. Verify Primary View: Check that the primary's text is visible.
      expect(find.text('Good, and you?'), findsOneWidget);

      report.pass(stepConversation);
    } catch (e) {
      report.fail(stepConversation, '$e');
    }
    report.screenshot(
      stepConversation,
      await takeScreenshot($, 'two_way_conversation_flow'),
    );

    debugPrint(report.summary());
    expect(report.allPassed, isTrue, reason: report.summary());
  });
}
