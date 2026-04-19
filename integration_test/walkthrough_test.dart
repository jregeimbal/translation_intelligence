/// End-to-end Patrol test for the first-launch walkthrough dialog.
///
/// These tests verify that the walkthrough appears on first launch, that page
/// navigation works correctly (Next / Back), and that the user can dismiss it
/// via Skip or Close. The test uses a dedicated test app variant that does NOT
/// set the "has completed walkthrough" preference so the dialog is shown.
///
/// Run with:
///   patrol test --target integration_test/walkthrough_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_intelligence/l10n/app_localizations.dart';
import 'package:translation_intelligence/main.dart';
import 'package:translation_intelligence/services/backend_api_client.dart';

import 'e2e_test_report.dart';
import 'fake_speech_controller.dart';
import 'fake_two_way_chat_controller.dart';
import 'screenshot_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test app that shows the walkthrough (no completion flag set)
// ─────────────────────────────────────────────────────────────────────────────

class WalkthroughTestApp extends StatelessWidget {
  const WalkthroughTestApp._({
    required this.controller,
    required this.twoWayController,
  });

  factory WalkthroughTestApp.create() {
    return WalkthroughTestApp._(
      controller: FakeSpeechController(speechEnabled: true),
      twoWayController: FakeTwoWayChatController(),
    );
  }

  final FakeSpeechController controller;
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
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Find the walkthrough dialog by looking for its welcome title text.
Finder findWalkthroughDialog() {
  return find.ancestor(
    of: find.text('Welcome to OmniaLingo'),
    matching: find.byType(Dialog),
  );
}

/// Find the page indicator dots Row inside the walkthrough dialog.
Finder findPageDots() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Row && widget.children.any((c) => c is AnimatedContainer),
  );
}

/// Find the "Skip" button inside the walkthrough dialog.
Finder findSkipButton() {
  return find.widgetWithText(TextButton, 'Skip');
}

/// Find the "Back" button inside the walkthrough dialog.
Finder findBackButton() {
  return find.widgetWithText(OutlinedButton, 'Back');
}

/// Find the "Next" or "Get Started" button (FilledButton) inside the dialog.
Finder findNextOrGetStartedButton() {
  return find.widgetWithText(FilledButton, 'Next').evaluate().isEmpty
      ? find.widgetWithText(FilledButton, 'Get Started')
      : find.widgetWithText(FilledButton, 'Next');
}

/// Find the close (X) icon button in the dialog header.
Finder findCloseButton() {
  return find.byIcon(Icons.close_rounded);
}

/// Find the page indicator dot at a given index.
Finder findPageDot(int index) {
  return find
      .byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color != null,
      )
      .at(index);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late E2eTestReport report;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    report = E2eTestReport();
  });

  tearDown(() async {
    await report.writeToFile();
  });

  // ── Test 1: Walkthrough appears on first launch ──────────────────────────

  patrolTest('Walkthrough dialog appears on first launch', ($) async {
    final app = WalkthroughTestApp.create();

    const stepLaunch = 'Walkthrough dialog appears after app launch';
    try {
      await $.pumpWidget(app);
      await $.pumpAndSettle();

      // The dialog should be visible.
      expect(findWalkthroughDialog(), findsOneWidget);

      // Welcome title should be present.
      expect(find.textContaining('Welcome to OmniaLingo'), findsOneWidget);

      // Welcome body text should be present.
      expect(find.textContaining('quick walkthrough'), findsOneWidget);

      // Page indicator dots should show 4 pages.
      final dotWidgets = findPageDots()
          .evaluate()
          .expand((e) => (e.widget as Row).children)
          .whereType<AnimatedContainer>()
          .toList();
      expect(dotWidgets.length, 4);

      // First dot should be highlighted (primary color).
      expect(dotWidgets.first.decoration is BoxDecoration, isTrue);

      // "Skip" button should be visible.
      expect(findSkipButton(), findsOneWidget);

      // "Next" button should be visible (first page, no Back yet).
      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);

      // Back button should NOT be visible on the first page.
      expect(findBackButton(), findsNothing);

      report.pass(stepLaunch);
    } catch (e) {
      report.fail(stepLaunch, '$e');
    }
    report.screenshot(
      stepLaunch,
      await takeScreenshot($, 'step1_walkthrough_appears'),
    );

    debugPrint(report.summary());
    expect(report.allPassed, isTrue, reason: report.summary());
  });

  // ── Test 2: Navigate through all pages with Next, then Get Started ───────

  patrolTest('User can navigate through all walkthrough pages and complete', (
    $,
  ) async {
    final app = WalkthroughTestApp.create();

    const stepNavigate = 'User navigates through all 4 pages';
    try {
      await $.pumpWidget(app);
      await $.pumpAndSettle();

      // Verify we start on page 1.
      expect(findWalkthroughDialog(), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
      expect(findBackButton(), findsNothing);

      // Page 1 -> 2: Tap Next
      await $.tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await $.pumpAndSettle();

      // Page 2: Back should now be visible, Next still visible
      expect(findBackButton(), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);

      // Page 2 -> 3: Tap Next
      await $.tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await $.pumpAndSettle();

      // Page 3: Back and Next both visible
      expect(findBackButton(), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);

      // Page 3 -> 4: Tap Next
      await $.tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await $.pumpAndSettle();

      // Page 4 (last): Back visible, "Get Started" instead of "Next"
      expect(findBackButton(), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Get Started'), findsOneWidget);

      // Tap "Get Started" to dismiss the dialog.
      await $.tester.tap(find.widgetWithText(FilledButton, 'Get Started'));
      await $.pumpAndSettle();

      // Dialog should be gone.
      expect(findWalkthroughDialog(), findsNothing);

      report.pass(stepNavigate);
    } catch (e) {
      report.fail(stepNavigate, '$e');
    }
    report.screenshot(
      stepNavigate,
      await takeScreenshot($, 'step2_navigate_all_pages'),
    );

    debugPrint(report.summary());
    expect(report.allPassed, isTrue, reason: report.summary());
  });

  // ── Test 3: Back button navigates backwards ─────────────────────────────

  patrolTest('Back button correctly navigates to previous pages', ($) async {
    const stepBack = 'Back button navigates to previous pages';
    try {
      await $.pumpWidget(WalkthroughTestApp.create());
      await $.pumpAndSettle();

      // Go forward to page 3.
      await $.tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await $.pumpAndSettle(); // page 2
      await $.tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await $.pumpAndSettle(); // page 3

      expect(findBackButton(), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);

      // Go back to page 2.
      await $.tester.tap(findBackButton());
      await $.pumpAndSettle();

      expect(findBackButton(), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);

      // Go back to page 1.
      await $.tester.tap(findBackButton());
      await $.pumpAndSettle();

      // On page 1: no Back button, Next visible.
      expect(findBackButton(), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);

      report.pass(stepBack);
    } catch (e) {
      report.fail(stepBack, '$e');
    }
    report.screenshot(
      stepBack,
      await takeScreenshot($, 'step3_back_navigation'),
    );

    debugPrint(report.summary());
    expect(report.allPassed, isTrue, reason: report.summary());
  });

  // ── Test 4: Skip button dismisses the dialog ────────────────────────────

  patrolTest('Skip button dismisses the walkthrough dialog', ($) async {
    const stepSkip = 'User skips the walkthrough';
    try {
      await $.pumpWidget(WalkthroughTestApp.create());
      await $.pumpAndSettle();

      expect(findWalkthroughDialog(), findsOneWidget);
      expect(findSkipButton(), findsOneWidget);

      await $.tester.tap(findSkipButton());
      await $.pumpAndSettle();

      // Dialog should be dismissed.
      expect(findWalkthroughDialog(), findsNothing);

      report.pass(stepSkip);
    } catch (e) {
      report.fail(stepSkip, '$e');
    }
    report.screenshot(stepSkip, await takeScreenshot($, 'step4_skip_dialog'));

    debugPrint(report.summary());
    expect(report.allPassed, isTrue, reason: report.summary());
  });

  // ── Test 5: Close (X) button dismisses the dialog ───────────────────────

  patrolTest('Close (X) button dismisses the walkthrough dialog', ($) async {
    const stepClose = 'User closes the walkthrough via X button';
    try {
      await $.pumpWidget(WalkthroughTestApp.create());
      await $.pumpAndSettle();

      expect(findWalkthroughDialog(), findsOneWidget);
      expect(findCloseButton(), findsOneWidget);

      await $.tester.tap(findCloseButton());
      await $.pumpAndSettle();

      // Dialog should be dismissed.
      expect(findWalkthroughDialog(), findsNothing);

      report.pass(stepClose);
    } catch (e) {
      report.fail(stepClose, '$e');
    }
    report.screenshot(stepClose, await takeScreenshot($, 'step5_close_dialog'));

    debugPrint(report.summary());
    expect(report.allPassed, isTrue, reason: report.summary());
  });

  // ── Test 6: Page indicator dots update during navigation ────────────────

  patrolTest('Page indicator dots highlight the current page', ($) async {
    const stepDots = 'Page dots update as user navigates';
    try {
      await $.pumpWidget(WalkthroughTestApp.create());
      await $.pumpAndSettle();

      // Collect all AnimatedContainer dots inside the dialog's Row.
      List<AnimatedContainer> dots() => findPageDots()
          .evaluate()
          .expand((e) => (e.widget as Row).children)
          .whereType<AnimatedContainer>()
          .toList();

      // Page 1: first dot should be wider (24px) vs others (8px).
      var dotList = dots();
      expect(dotList.length, 4);
      expect(
        dotList[0].constraints?.maxWidth ?? dotList[0].constraints?.minWidth,
        24,
      );

      // Tap Next to go to page 2.
      await $.tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await $.pumpAndSettle();

      dotList = dots();
      expect(
        dotList[1].constraints?.maxWidth ?? dotList[1].constraints?.minWidth,
        24,
      );
      expect(
        dotList[0].constraints?.maxWidth ?? dotList[0].constraints?.minWidth,
        8,
      );

      // Tap Next to go to page 3.
      await $.tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await $.pumpAndSettle();

      dotList = dots();
      expect(
        dotList[2].constraints?.maxWidth ?? dotList[2].constraints?.minWidth,
        24,
      );

      // Tap Next to go to page 4.
      await $.tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await $.pumpAndSettle();

      dotList = dots();
      expect(
        dotList[3].constraints?.maxWidth ?? dotList[3].constraints?.minWidth,
        24,
      );

      report.pass(stepDots);
    } catch (e) {
      report.fail(stepDots, '$e');
    }
    report.screenshot(stepDots, await takeScreenshot($, 'step6_page_dots'));

    debugPrint(report.summary());
    expect(report.allPassed, isTrue, reason: report.summary());
  });

  // ── Test 7: Walkthrough does NOT appear when already completed ──────────

  patrolTest('Walkthrough is skipped when user has already completed it', (
    $,
  ) async {
    const stepNoDialog = 'No walkthrough shown when already completed';
    try {
      SharedPreferences.setMockInitialValues({
        'pref.hasCompletedFirstLaunchWalkthrough': true,
      });

      // Create app with a fresh binding context by re-initializing.
      await $.pumpWidget(
        MaterialApp(
          onGenerateTitle: (context) => 'OmniaLingo',
          theme: ThemeData.light(useMaterial3: true),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MyHomePage(
            themeMode: ThemeMode.light,
            onThemeModeChanged: (_) {},
            initializer: () async => HomePageInitializationBundle(
              backendApiClient: BackendApiClient(
                baseUrl: 'https://e2e-test.invalid',
                authTokenProvider: () async => 'e2e-test-token',
              ),
              controller: FakeSpeechController(speechEnabled: true),
              twoWayController: FakeTwoWayChatController(),
            ),
          ),
        ),
      );
      await $.pumpAndSettle();

      // The walkthrough dialog should NOT appear.
      expect(findWalkthroughDialog(), findsNothing);

      // The main app content should be visible instead.
      expect(find.textContaining('Tap the mic'), findsOneWidget);

      report.pass(stepNoDialog);
    } catch (e) {
      report.fail(stepNoDialog, '$e');
    }
    report.screenshot(
      stepNoDialog,
      await takeScreenshot($, 'step7_no_walkthrough'),
    );

    debugPrint(report.summary());
    expect(report.allPassed, isTrue, reason: report.summary());
  });
}
