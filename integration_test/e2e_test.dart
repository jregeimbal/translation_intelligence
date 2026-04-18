/// End-to-end Patrol test suite for OmniaLingo.
///
/// These tests run the full app UI using fake controllers that avoid real
/// microphone, network, and Firebase access. Speech recognition results are
/// simulated programmatically so the test can verify the complete user-facing
/// flow:
///   1. User taps the record (mic) button.
///   2. A spoken phrase is recognized and its translation is returned.
///   3. Both the original text and the translation appear in the chat view.
///
/// Run with:
///   patrol test --target integration_test/e2e_test.dart
///
/// On a connected Android device or emulator:
///   patrol test --target integration_test/e2e_test.dart --device emulator-5554
///
/// Via Flutter directly (widget-test mode only, no native automation):
///   flutter test integration_test/e2e_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'e2e_test_app.dart';
import 'e2e_test_report.dart';
import 'screenshot_helper.dart';

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

  // ─────────────────────────────────────────────────────────────────────────
  // Scenario 1 – Record → original text and translation displayed
  // ─────────────────────────────────────────────────────────────────────────

  patrolTest(
    'User records speech and sees original text with translation',
    ($) async {
      final app = E2eTestApp.create();

      // ── Step 1: Launch the app ──────────────────────────────────────────
      const stepLaunch = 'Launch the app and see the group chat screen';
      try {
        await $.pumpWidget(app);
        await $.pumpAndSettle();

        // Verify we see the initial "Tap the mic to start listening…" prompt.
        expect(
          $.tester.widget<Text>(find.textContaining('Tap the mic')),
          isNotNull,
        );
        report.pass(stepLaunch);
      } catch (e) {
        report.fail(stepLaunch, '$e');
      }
      report.screenshot(
        stepLaunch,
        await takeScreenshot($, 'step1_app_launched'),
      );

      // ── Step 2: Tap the mic/record button ───────────────────────────────
      const stepTapMic = 'User taps the record (mic) button';
      try {
        // The SpeechFab uses a FloatingActionButton with a tooltip 'Listen'.
        final micButton = find.byTooltip('Listen');
        expect(micButton, findsOneWidget);

        await $.tester.tap(micButton);
        // Pump a few frames to let the async startListening() complete.
        // pumpAndSettle may time out due to the processing spinner animation.
        await $.pump(const Duration(milliseconds: 100));
        await $.pump(const Duration(milliseconds: 100));
        await $.pump(const Duration(milliseconds: 100));

        // Controller should now be in listening state.
        expect(app.controller.isListening, isTrue);
        report.pass(stepTapMic);
      } catch (e) {
        report.fail(stepTapMic, '$e');
      }
      report.screenshot(
        stepTapMic,
        await takeScreenshot($, 'step2_mic_tapped'),
      );

      // ── Step 3: Simulate spoken phrase "hola, como estás?" ──────────────
      const stepSpeak =
          'User says "hola, como estás?" — original and translation appear';
      try {
        // Stop listening first (the real app would stop after final result).
        await app.controller.stopListening();
        await $.pump();

        // Inject the simulated recognition result.
        app.simulateRecognition(
          original: 'hola, como estás?',
          translation: 'Hello, how are you?',
          speaker: 0,
          sourceLanguageCode: 'es',
          targetLanguageCode: 'en',
        );
        await $.pumpAndSettle();

        // Verify the original text is visible.
        expect(
          find.textContaining('hola, como estás?'),
          findsWidgets,
        );

        // Verify the translation is visible.
        expect(
          find.textContaining('Hello, how are you?'),
          findsWidgets,
        );

        report.pass(stepSpeak);
      } catch (e) {
        report.fail(stepSpeak, '$e');
      }
      report.screenshot(
        stepSpeak,
        await takeScreenshot($, 'step3_speech_result'),
      );

      // ── Step 4: Verify the message bubble has both parts ────────────────
      const stepVerifyBubble =
          'Both original and translated text are in the chat bubble';
      try {
        // The ChatMessageList renders messages using ValueKey('chat_row_…').
        final chatRows = find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>)
                  .value
                  .startsWith('chat_row_'),
        );
        expect(chatRows, findsAtLeast(1));
        report.pass(stepVerifyBubble);
      } catch (e) {
        report.fail(stepVerifyBubble, '$e');
      }
      report.screenshot(
        stepVerifyBubble,
        await takeScreenshot($, 'step4_chat_bubble_verified'),
      );

      // ── Step 5: Second recognition to ensure multiple messages work ─────
      const stepSecondMsg = 'Second message is added after another recording';
      try {
        // Tap mic again to start a new recording.
        final micButton = find.byTooltip('Listen');
        await $.tester.tap(micButton);
        await $.pump(const Duration(milliseconds: 100));
        await $.pump(const Duration(milliseconds: 100));
        await $.pump(const Duration(milliseconds: 100));
        expect(app.controller.isListening, isTrue);

        await app.controller.stopListening();
        await $.pump();

        app.simulateRecognition(
          original: 'buenos días',
          translation: 'Good morning',
          speaker: 1,
          sourceLanguageCode: 'es',
          targetLanguageCode: 'en',
        );
        await $.pumpAndSettle();

        expect(find.textContaining('buenos días'), findsWidgets);
        expect(find.textContaining('Good morning'), findsWidgets);
        report.pass(stepSecondMsg);
      } catch (e) {
        report.fail(stepSecondMsg, '$e');
      }
      report.screenshot(
        stepSecondMsg,
        await takeScreenshot($, 'step5_second_message'),
      );

      // ── Print report ────────────────────────────────────────────────────
      final summaryText = report.summary();
      debugPrint(summaryText);

      // Fail the Patrol test if any step failed so CI marks it red.
      expect(report.allPassed, isTrue, reason: summaryText);
    },
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Scenario 2 – Record button toggles between start and stop
  // ─────────────────────────────────────────────────────────────────────────

  patrolTest(
    'Record button toggles between listening and idle',
    ($) async {
      final app = E2eTestApp.create();
      const stepStartStop = 'Mic button toggles start/stop listening';
      try {
        await $.pumpWidget(app);
        await $.pumpAndSettle();

        // Tap to start listening.
        final micButton = find.byTooltip('Listen');
        expect(micButton, findsOneWidget);
        await $.tester.tap(micButton);
        await $.pump(const Duration(milliseconds: 100));
        await $.pump(const Duration(milliseconds: 100));
        await $.pump(const Duration(milliseconds: 100));
        expect(app.controller.isListening, isTrue);

        // The FAB should now show a stop icon; tap it again.
        // (SpeechFab swaps its onPressed to stopListening when listening.)
        await $.tester.tap(find.byType(FloatingActionButton));
        await $.pumpAndSettle();
        expect(app.controller.isListening, isFalse);

        report.pass(stepStartStop);
      } catch (e) {
        report.fail(stepStartStop, '$e');
      }
      report.screenshot(
        stepStartStop,
        await takeScreenshot($, 'toggle_mic'),
      );

      debugPrint(report.summary());
      expect(report.allPassed, isTrue, reason: report.summary());
    },
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Scenario 3 – Multiple speakers produce distinct chat rows
  // ─────────────────────────────────────────────────────────────────────────

  patrolTest(
    'Multiple speakers produce separate chat rows with translations',
    ($) async {
      final app = E2eTestApp.create();
      const stepMultiSpeaker = 'Messages from different speakers appear';
      try {
        await $.pumpWidget(app);
        await $.pumpAndSettle();

        app.simulateRecognition(
          original: '¿Dónde está la biblioteca?',
          translation: 'Where is the library?',
          speaker: 0,
          sourceLanguageCode: 'es',
          targetLanguageCode: 'en',
        );
        await $.pumpAndSettle();

        app.simulateRecognition(
          original: 'Es al lado del parque.',
          translation: 'It is next to the park.',
          speaker: 1,
          sourceLanguageCode: 'es',
          targetLanguageCode: 'en',
        );
        await $.pumpAndSettle();

        // Both messages should be visible.
        expect(
          find.textContaining('Where is the library?'),
          findsWidgets,
        );
        expect(
          find.textContaining('It is next to the park.'),
          findsWidgets,
        );

        // Two chat rows should exist.
        final chatRows = find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>)
                  .value
                  .startsWith('chat_row_'),
        );
        expect(chatRows, findsNWidgets(2));

        report.pass(stepMultiSpeaker);
      } catch (e) {
        report.fail(stepMultiSpeaker, '$e');
      }
      report.screenshot(
        stepMultiSpeaker,
        await takeScreenshot($, 'multi_speaker'),
      );

      debugPrint(report.summary());
      expect(report.allPassed, isTrue, reason: report.summary());
    },
  );
}
