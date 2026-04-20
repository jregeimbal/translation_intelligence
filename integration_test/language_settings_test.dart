/// End-to-end Patrol test for changing source and target languages.
///
/// These tests verify that users can change the target language via the
/// settings dialog and that the change is reflected in the UI.
///
/// Run with:
///   patrol test --target integration_test/language_settings_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_intelligence/widgets/searchable_selection_field.dart';

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
  // Scenario 1 – Change target language to French
  // ─────────────────────────────────────────────────────────────────────────

  patrolTest('User can change target language to French', ($) async {
    final app = E2eTestApp.create();

    const stepLaunch = 'Launch the app';
    try {
      await $.pumpWidget(app);
      await $.pumpAndSettle();

      // Verify initial target language is English
      expect(app.controller.targetLanguage, 'en');

      report.pass(stepLaunch);
    } catch (e) {
      report.fail(stepLaunch, '$e');
    }
    report.screenshot(
      stepLaunch,
      await takeScreenshot($, 'step1_initial_state'),
    );

    // ── Step 2: Open settings dialog ─────────────────────────────────────
    const stepOpenSettings = 'User opens settings dialog';
    try {
      // Tap the settings icon in the app bar
      final settingsButton = find.byIcon(Icons.settings_outlined);
      expect(settingsButton, findsOneWidget);

      await $.tester.tap(settingsButton);
      await $.pumpAndSettle();

      // Verify settings dialog is open
      expect(find.text('Settings'), findsOneWidget);

      report.pass(stepOpenSettings);
    } catch (e) {
      report.fail(stepOpenSettings, '$e');
    }
    report.screenshot(
      stepOpenSettings,
      await takeScreenshot($, 'step2_settings_opened'),
    );

    // ── Step 3: Change target language to French ─────────────────────────
    const stepChangeLanguage = 'User changes target language to French';
    try {
      // Find the target language selection field
      final targetLanguageField = find.widgetWithText(
        SearchableSelectionField<String>,
        'English',
      );

      await $.tester.tap(targetLanguageField);
      await $.pumpAndSettle();

      // Type "French" to filter and select it
      await $.tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'French',
      );
      await $.pumpAndSettle();

      // Tap on the matching option (ListTile)
      await $.tester.tap(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('French'),
        ),
      );
      await $.pumpAndSettle();

      // Click Save to apply the changes
      await $.tester.tap(find.widgetWithText(TextButton, 'Save'));
      await $.pumpAndSettle();

      // Verify controller was updated
      expect(app.controller.targetLanguage, 'fr');

      report.pass(stepChangeLanguage);
    } catch (e) {
      report.fail(stepChangeLanguage, '$e');
    }
    report.screenshot(
      stepChangeLanguage,
      await takeScreenshot($, 'step3_language_changed_to_french'),
    );

    // ── Step 4: Verify dialog is closed and language persists ────────────
    const stepVerifyClosed = 'Settings dialog is closed';
    try {
      // Dialog should be closed
      expect(find.text('Settings'), findsNothing);

      report.pass(stepVerifyClosed);
    } catch (e) {
      report.fail(stepVerifyClosed, '$e');
    }

    debugPrint(report.summary());
    expect(report.allPassed, isTrue, reason: report.summary());
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Scenario 2 – Change target language to Hindi
  // ─────────────────────────────────────────────────────────────────────────

  patrolTest('User can change target language to Hindi', ($) async {
    final app = E2eTestApp.create();

    const stepLaunch = 'Launch the app';
    try {
      await $.pumpWidget(app);
      await $.pumpAndSettle();

      // Verify initial target language is English
      expect(app.controller.targetLanguage, 'en');

      report.pass(stepLaunch);
    } catch (e) {
      report.fail(stepLaunch, '$e');
    }

    // ── Step 3: Change target language to Hindi ─────────────────────────
    const stepChangeToHindi = 'User changes target language to Hindi';
    try {
      // Open settings
      await $.tester.tap(find.byIcon(Icons.settings_outlined));
      await $.pumpAndSettle();

      // Find and tap target language field
      final targetLanguageField = find.widgetWithText(
        SearchableSelectionField<String>,
        'English',
      );
      await $.tester.tap(targetLanguageField);
      await $.pumpAndSettle();

      // Type "Hindi" to filter and select it
      await $.tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'Hindi',
      );
      await $.pumpAndSettle();

      // Tap on the matching option (ListTile)
      await $.tester.tap(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Hindi'),
        ),
      );
      await $.pumpAndSettle();

      // Click Save to apply the changes
      await $.tester.tap(find.widgetWithText(TextButton, 'Save'));
      await $.pumpAndSettle();

      // Verify controller was updated
      expect(app.controller.targetLanguage, 'hi');

      report.pass(stepChangeToHindi);
    } catch (e) {
      report.fail(stepChangeToHindi, '$e');
    }

    debugPrint(report.summary());
    expect(report.allPassed, isTrue, reason: report.summary());
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Scenario 3 – Verify language options are available in settings
  // ─────────────────────────────────────────────────────────────────────────

  patrolTest('All supported languages are available in settings', ($) async {
    final app = E2eTestApp.create();

    const stepVerifyOptions = 'All supported languages appear in settings';
    try {
      await $.pumpWidget(app);
      await $.pumpAndSettle();

      // Open settings
      await $.tester.tap(find.byIcon(Icons.settings_outlined));
      await $.pumpAndSettle();

      // Open target language selector by tapping the field
      final targetLanguageField = find.widgetWithText(
        SearchableSelectionField<String>,
        'English',
      );
      await $.tester.tap(targetLanguageField);
      await $.pumpAndSettle();

      // Search for and verify French is available
      await $.tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'French',
      );
      await $.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('French'),
        ),
        findsOneWidget,
      );

      // Search for and verify Hindi is available
      await $.tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'Hindi',
      );
      await $.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Hindi'),
        ),
        findsOneWidget,
      );

      // Verify other supported languages by searching
      await $.tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'Spanish',
      );
      await $.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Spanish'),
        ),
        findsOneWidget,
      );

      await $.tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'German',
      );
      await $.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('German'),
        ),
        findsOneWidget,
      );

      await $.tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'Chinese',
      );
      await $.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Chinese (Simplified)'),
        ),
        findsOneWidget,
      );

      await $.tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'Japanese',
      );
      await $.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Japanese'),
        ),
        findsOneWidget,
      );

      await $.tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'Korean',
      );
      await $.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Korean'),
        ),
        findsOneWidget,
      );

      await $.tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'Portuguese',
      );
      await $.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Portuguese'),
        ),
        findsOneWidget,
      );

      await $.tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'Russian',
      );
      await $.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Russian'),
        ),
        findsOneWidget,
      );

      await $.tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'Arabic',
      );
      await $.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Arabic'),
        ),
        findsOneWidget,
      );

      // Click Save to close dialog
      await $.tester.tap(find.widgetWithText(TextButton, 'Save'));
      await $.pumpAndSettle();

      report.pass(stepVerifyOptions);
    } catch (e) {
      report.fail(stepVerifyOptions, '$e');
    }

    debugPrint(report.summary());
    expect(report.allPassed, isTrue, reason: report.summary());
  });
}
