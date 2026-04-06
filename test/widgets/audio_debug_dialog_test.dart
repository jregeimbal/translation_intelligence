import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/l10n/app_localizations.dart';
import 'package:translation_intelligence/l10n/app_localizations_ext.dart';
import 'package:translation_intelligence/widgets/audio_debug_dialog.dart';
import 'package:translation_intelligence/services/speech_output_provider.dart';
import 'package:translation_intelligence/services/speech_stt_provider.dart';
import 'package:translation_intelligence/services/speech_translation_provider.dart';
import '../speech_controller_stub.dart';
import '../test_app.dart';
import '../two_way_chat_controller_stub.dart';

Finder _textMatching(RegExp pattern) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && widget.data != null && pattern.hasMatch(widget.data!),
  );
}

Finder _rowLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && widget.data != null && widget.data!.startsWith('$label:'),
  );
}

String _row(String label, String value) => '$label: $value';

void main() {
  group('AudioDebugDialog', () {
    late TestSpeechController groupController;
    late TestTwoWayChatController twoWayController;

    setUp(() {
      groupController = TestSpeechController(
        isListening: true,
        amplitude: 0.523,
        activeSessionSampleRate: 16000,
        activeSessionSttProvider: SpeechSttProvider.deepgram,
        activeSessionSourceLanguage: 'en-US',
        activeSessionResolvedLanguageCode: 'en',
        activeSessionListeningDeviceId: 'device-123',
        activeSessionStartedAt: DateTime.now().subtract(
          const Duration(minutes: 2, seconds: 30),
        ),
       );

      twoWayController = TestTwoWayChatController(
        isListening: true,
        amplitude: 0.750,
        activeSessionSampleRate: 44100,
        activeSessionSttProvider: SpeechSttProvider.google,
        activeSessionSourceLanguage: 'es-ES',
        activeSessionResolvedLanguageCode: 'es',
        activeSessionListeningDeviceId: 'device-456',
        activeSessionStartedAt: DateTime.now().subtract(
          const Duration(minutes: 1, seconds: 30),
        ),
       );
     });

    group('Group Chat Mode', () {
      testWidgets('TC-001: Comprehensive group chat mode test', (tester) async {
        await pumpTestApp(
          tester,
          AudioDebugDialog(
            controller: groupController,
            twoWayController: twoWayController,
            outputProvider: SpeechOutputProvider.google,
            sttProvider: SpeechSttProvider.deepgram,
            translationProvider: SpeechTranslationProvider.google,
            isGroupSection: true,
          ),
        );

        final context = tester.element(find.byType(AudioDebugDialog));
        final l10n = AppLocalizations.of(context)!;

        expect(find.text(l10n.debugAudioStream), findsOneWidget);
        expect(
          find.text(_row(l10n.debugSection, l10n.debugSectionGroup)),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugListeningActive, l10n.yes)),
          findsOneWidget,
        );
        expect(
          find.text(
            _row(
              l10n.debugSttProvider,
              localizedSttProviderLabel(context, SpeechSttProvider.deepgram),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _row(
              l10n.debugSourceLanguage,
              localizedRecognitionLocaleLabel(context, 'en-US'),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugResolvedLanguageCode, 'en')),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugActiveSampleRate, l10n.sampleRateHertz(16000))),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugListeningDeviceId, 'device-123')),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugAmplitude, '0.523')),
          findsOneWidget,
        );
        expect(
          find.textContaining('${l10n.debugSessionElapsed}: 02:3'),
          findsOneWidget,
        );
        expect(
          _textMatching(RegExp('^${RegExp.escape(l10n.debugSessionStartedAt)}: .+')),
          findsOneWidget,
        );
        expect(
          find.text(
            _row(
              l10n.debugConfiguredSttProvider,
              localizedSttProviderLabel(context, groupController.sttProvider),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _row(
              l10n.debugConfiguredDeepgramLanguage,
              localizedDeepgramLanguageLabel(
                context,
                groupController.deepgramRecognitionLanguage,
              ),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _row(
              l10n.debugConfiguredGoogleLocale,
              localizedRecognitionLocaleLabel(
                context,
                groupController.speechToTextRecognitionLocale,
              ),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _row(
              l10n.debugConfiguredSttLocale,
              localizedRecognitionLocaleLabel(
                context,
                groupController.speechToTextRecognitionLocale,
              ),
            ),
          ),
          findsOneWidget,
        );
      });
    });

    group('Two-Way Chat Mode', () {
      testWidgets('TC-017: Comprehensive two-way chat mode test', (tester) async {
        await pumpTestApp(
          tester,
          AudioDebugDialog(
            controller: groupController,
            twoWayController: twoWayController,
            outputProvider: SpeechOutputProvider.google,
            sttProvider: SpeechSttProvider.deepgram,
            translationProvider: SpeechTranslationProvider.google,
            isGroupSection: false,
          ),
        );

        final context = tester.element(find.byType(AudioDebugDialog));
        final l10n = AppLocalizations.of(context)!;

        expect(
          find.text(_row(l10n.debugSection, l10n.debugSectionTwoWay)),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugListeningActive, l10n.yes)),
          findsOneWidget,
        );
        expect(
          find.text(
            _row(
              l10n.debugSttProvider,
              localizedSttProviderLabel(context, SpeechSttProvider.google),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _row(
              l10n.debugSourceLanguage,
              localizedRecognitionLocaleLabel(context, 'es-ES'),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugResolvedLanguageCode, 'es')),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugActiveSampleRate, l10n.sampleRateHertz(44100))),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugListeningDeviceId, 'device-456')),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugAmplitude, '0.750')),
          findsOneWidget,
        );
        expect(
          find.textContaining('${l10n.debugSessionElapsed}: 01:3'),
          findsOneWidget,
        );
        expect(
          find.text(
            _row(
              l10n.debugConfiguredSttProvider,
              localizedSttProviderLabel(context, twoWayController.sttProvider),
            ),
          ),
          findsOneWidget,
        );
      });
    });

    group('Edge Cases', () {
      testWidgets('TC-033: Null values display n/a', (tester) async {
        final nullController = TestSpeechController();
        final nullTwoWayController = TestTwoWayChatController();

        await pumpTestApp(
          tester,
          AudioDebugDialog(
            controller: nullController,
            twoWayController: nullTwoWayController,
            outputProvider: SpeechOutputProvider.google,
            sttProvider: SpeechSttProvider.deepgram,
            translationProvider: SpeechTranslationProvider.google,
            isGroupSection: true,
          ),
        );

        final context = tester.element(find.byType(AudioDebugDialog));
        final l10n = AppLocalizations.of(context)!;

        expect(
          find.text(_row(l10n.debugSttProvider, l10n.notAvailableShort)),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugSourceLanguage, l10n.notAvailableShort)),
          findsOneWidget,
        );
        expect(
          find.text(
            _row(l10n.debugResolvedLanguageCode, l10n.notAvailableShort),
          ),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugActiveSampleRate, l10n.notAvailableShort)),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugListeningDeviceId, l10n.autoDefault)),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugSessionStartedAt, l10n.notAvailableShort)),
          findsOneWidget,
        );
      });

      testWidgets('TC-034: Zero amplitude displays as 0.000', (tester) async {
        final zeroAmplitudeController = TestSpeechController(amplitude: 0.0);

        await pumpTestApp(
          tester,
          AudioDebugDialog(
            controller: zeroAmplitudeController,
            twoWayController: twoWayController,
            outputProvider: SpeechOutputProvider.google,
            sttProvider: SpeechSttProvider.deepgram,
            translationProvider: SpeechTranslationProvider.google,
            isGroupSection: true,
          ),
        );

        final context = tester.element(find.byType(AudioDebugDialog));
        final l10n = AppLocalizations.of(context)!;
        expect(find.text(_row(l10n.debugAmplitude, '0.000')), findsOneWidget);
      });

      testWidgets('TC-035: Very short elapsed time displays correctly', (tester) async {
        final shortSessionController = TestSpeechController(
          activeSessionStartedAt: DateTime.now().subtract(
            const Duration(seconds: 30),
          ),
        );

        await pumpTestApp(
          tester,
          AudioDebugDialog(
            controller: shortSessionController,
            twoWayController: twoWayController,
            outputProvider: SpeechOutputProvider.google,
            sttProvider: SpeechSttProvider.deepgram,
            translationProvider: SpeechTranslationProvider.google,
            isGroupSection: true,
          ),
        );

        final context = tester.element(find.byType(AudioDebugDialog));
        final l10n = AppLocalizations.of(context)!;
        expect(
          find.textContaining('${l10n.debugSessionElapsed}: 00:3'),
          findsOneWidget,
        );
      });

      testWidgets('TC-036: Long elapsed time displays correctly', (tester) async {
        final longSessionController = TestSpeechController(
          activeSessionStartedAt: DateTime.now().subtract(
            const Duration(hours: 2, minutes: 30),
          ),
        );

        await pumpTestApp(
          tester,
          AudioDebugDialog(
            controller: longSessionController,
            twoWayController: twoWayController,
            outputProvider: SpeechOutputProvider.google,
            sttProvider: SpeechSttProvider.deepgram,
            translationProvider: SpeechTranslationProvider.google,
            isGroupSection: true,
          ),
        );

        final context = tester.element(find.byType(AudioDebugDialog));
        final l10n = AppLocalizations.of(context)!;
        expect(
          find.textContaining('${l10n.debugSessionElapsed}: 150:0'),
          findsOneWidget,
        );
      });

      testWidgets('TC-037: Empty device id stays empty', (tester) async {
        final emptyDeviceController = TestSpeechController(
          activeSessionListeningDeviceId: '',
        );

        await pumpTestApp(
          tester,
          AudioDebugDialog(
            controller: emptyDeviceController,
            twoWayController: twoWayController,
            outputProvider: SpeechOutputProvider.google,
            sttProvider: SpeechSttProvider.deepgram,
            translationProvider: SpeechTranslationProvider.google,
            isGroupSection: true,
          ),
        );

        final context = tester.element(find.byType(AudioDebugDialog));
        final l10n = AppLocalizations.of(context)!;
        expect(find.text(_row(l10n.debugListeningDeviceId, '')), findsOneWidget);
      });

      testWidgets('TC-038: Dialog has fixed width of 520px', (tester) async {
        await pumpTestApp(
          tester,
          AudioDebugDialog(
            controller: groupController,
            twoWayController: twoWayController,
            outputProvider: SpeechOutputProvider.google,
            sttProvider: SpeechSttProvider.deepgram,
            translationProvider: SpeechTranslationProvider.google,
            isGroupSection: true,
          ),
        );

        expect(
          find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.width == 520,
          ),
          findsOneWidget,
        );
      });

      testWidgets('TC-039: Content is scrollable when rows exceed viewport', (tester) async {
        await pumpTestApp(
          tester,
          AudioDebugDialog(
            controller: groupController,
            twoWayController: twoWayController,
            outputProvider: SpeechOutputProvider.google,
            sttProvider: SpeechSttProvider.deepgram,
            translationProvider: SpeechTranslationProvider.google,
            isGroupSection: true,
          ),
        );

        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });

      testWidgets('TC-040: Group mode with listening=false shows no', (tester) async {
        final stoppedController = TestSpeechController(isListening: false);

        await pumpTestApp(
          tester,
          AudioDebugDialog(
            controller: stoppedController,
            twoWayController: twoWayController,
            outputProvider: SpeechOutputProvider.google,
            sttProvider: SpeechSttProvider.deepgram,
            translationProvider: SpeechTranslationProvider.google,
            isGroupSection: true,
          ),
        );

        final context = tester.element(find.byType(AudioDebugDialog));
        final l10n = AppLocalizations.of(context)!;
        expect(find.text(_row(l10n.debugListeningActive, l10n.no)), findsOneWidget);
      });

      testWidgets('TC-041: Two-way mode with listening=false shows no', (tester) async {
        final stoppedTwoWayController = TestTwoWayChatController(isListening: false);

        await pumpTestApp(
          tester,
          AudioDebugDialog(
            controller: groupController,
            twoWayController: stoppedTwoWayController,
            outputProvider: SpeechOutputProvider.google,
            sttProvider: SpeechSttProvider.deepgram,
            translationProvider: SpeechTranslationProvider.google,
            isGroupSection: false,
          ),
        );

        final context = tester.element(find.byType(AudioDebugDialog));
        final l10n = AppLocalizations.of(context)!;
        expect(find.text(_row(l10n.debugListeningActive, l10n.no)), findsOneWidget);
      });
    });

    group('StreamBuilder Behavior', () {
      testWidgets('TC-042: StreamBuilder rebuilds widget periodically (250ms interval)', (tester) async {
        await pumpTestApp(
          tester,
          AudioDebugDialog(
            controller: groupController,
            twoWayController: twoWayController,
            outputProvider: SpeechOutputProvider.google,
            sttProvider: SpeechSttProvider.deepgram,
            translationProvider: SpeechTranslationProvider.google,
            isGroupSection: true,
          ),
        );

        final context = tester.element(find.byType(AudioDebugDialog));
        final l10n = AppLocalizations.of(context)!;
        expect(find.text(l10n.debugAudioStream), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text(l10n.debugAudioStream), findsOneWidget);
      });

      testWidgets('TC-043: Widget updates display values on stream events', (tester) async {
        await pumpTestApp(
          tester,
          AudioDebugDialog(
            controller: groupController,
            twoWayController: twoWayController,
            outputProvider: SpeechOutputProvider.google,
            sttProvider: SpeechSttProvider.deepgram,
            translationProvider: SpeechTranslationProvider.google,
            isGroupSection: true,
          ),
        );

        final context = tester.element(find.byType(AudioDebugDialog));
        final l10n = AppLocalizations.of(context)!;
        expect(
          find.text(_row(l10n.debugActiveSampleRate, l10n.sampleRateHertz(16000))),
          findsOneWidget,
        );

        groupController.setActiveSessionData(
          sampleRate: 44100,
          listeningDeviceId: 'new-device',
        );
        await tester.pump(const Duration(milliseconds: 250));

        expect(
          find.text(_row(l10n.debugActiveSampleRate, l10n.sampleRateHertz(44100))),
          findsOneWidget,
        );
        expect(
          find.text(_row(l10n.debugListeningDeviceId, 'new-device')),
          findsOneWidget,
        );
      });
    });

    group('Localization', () {
      testWidgets('TC-044: All 14 debug labels are localized', (tester) async {
        await pumpTestApp(
          tester,
          AudioDebugDialog(
            controller: groupController,
            twoWayController: twoWayController,
            outputProvider: SpeechOutputProvider.google,
            sttProvider: SpeechSttProvider.deepgram,
            translationProvider: SpeechTranslationProvider.google,
            isGroupSection: true,
          ),
        );

        final context = tester.element(find.byType(AudioDebugDialog));
        final l10n = AppLocalizations.of(context)!;

        expect(_rowLabel(l10n.debugSection), findsOneWidget);
        expect(_rowLabel(l10n.debugListeningActive), findsOneWidget);
        expect(_rowLabel(l10n.debugSttProvider), findsOneWidget);
        expect(_rowLabel(l10n.debugSourceLanguage), findsOneWidget);
        expect(_rowLabel(l10n.debugResolvedLanguageCode), findsOneWidget);
        expect(_rowLabel(l10n.debugActiveSampleRate), findsOneWidget);
        expect(_rowLabel(l10n.debugListeningDeviceId), findsOneWidget);
        expect(_rowLabel(l10n.debugAmplitude), findsOneWidget);
        expect(_rowLabel(l10n.debugSessionElapsed), findsOneWidget);
        expect(_rowLabel(l10n.debugSessionStartedAt), findsOneWidget);
        expect(_rowLabel(l10n.debugConfiguredSttProvider), findsOneWidget);
        expect(_rowLabel(l10n.debugConfiguredDeepgramLanguage), findsOneWidget);
        expect(_rowLabel(l10n.debugConfiguredGoogleLocale), findsOneWidget);
        expect(_rowLabel(l10n.debugConfiguredSttLocale), findsOneWidget);
      });
    });

    testWidgets('showInDialog displays and closes the dialog', (tester) async {
      late BuildContext dialogContext;
      await pumpTestApp(
        tester,
        Builder(
          builder: (context) {
            dialogContext = context;
            return const SizedBox.shrink();
          },
        ),
      );

      final dialogFuture = AudioDebugDialog.showInDialog(
        dialogContext,
        groupController,
        twoWayController,
        SpeechOutputProvider.google,
        SpeechSttProvider.deepgram,
        SpeechTranslationProvider.google,
        true,
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await dialogFuture;

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
