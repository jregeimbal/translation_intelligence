import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:translation_intelligence/models/playback_device.dart';
import 'package:translation_intelligence/services/speech_output_provider.dart';
import 'package:translation_intelligence/services/speech_stt_provider.dart';
import 'package:translation_intelligence/services/speech_to_text_service.dart';
import 'package:translation_intelligence/services/speech_translation_provider.dart';
import 'package:translation_intelligence/widgets/provider_settings_dialog.dart';
import 'package:translation_intelligence/widgets/searchable_selection_field.dart';

import 'speech_controller_stub.dart';
import 'test_app.dart';

void main() {
  testWidgets(
    'ProviderSettingsDialog shows essentials-first full-screen settings page',
    (tester) async {
      await pumpTestApp(
        tester,
        const ProviderSettingsDialog(
          initialSttProvider: SpeechSttProvider.deepgram,
          initialTranslationProvider: SpeechTranslationProvider.google,
          initialOutputProvider: SpeechOutputProvider.google,
          initialTargetLanguage: 'en',
          targetLanguages: ['en', 'es'],
          initialDeepgramRecognitionModel: 'nova-3',
          initialDeepgramRecognitionLanguage: 'multi',
          initialSpeechToTextRecognitionLocale:
              SpeechToTextService.defaultRecognitionLanguage,
          initialSpeechToTextRecognitionLocales: {
            'multi': SpeechToTextService.defaultRecognitionLanguage,
            'en-US': 'en-US',
          },
          initialListeningDevices: [],
          initialListeningDeviceId: null,
          initialPlaybackDevices: [],
          initialPlaybackDeviceId: null,
          initialThemeMode: ThemeMode.system,
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Essentials'), findsOneWidget);
      expect(find.text('Voice Recognition'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('Target'), findsOneWidget);
      expect(find.text('Listening Device'), findsOneWidget);
      expect(find.text('Show advanced options'), findsOneWidget);
      expect(find.text('Speech to Text'), findsNothing);
      expect(find.text('Deepgram Model'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Audio Devices'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Audio Devices'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Appearance'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Appearance'), findsOneWidget);
    },
  );

  testWidgets('ProviderSettingsDialog reveals advanced provider choices', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      const ProviderSettingsDialog(
        initialSttProvider: SpeechSttProvider.deepgram,
        initialTranslationProvider: SpeechTranslationProvider.google,
        initialOutputProvider: SpeechOutputProvider.google,
        initialTargetLanguage: 'en',
        targetLanguages: ['en', 'es'],
        initialDeepgramRecognitionModel: 'nova-3',
        initialDeepgramRecognitionLanguage: 'multi',
        initialSpeechToTextRecognitionLocale:
            SpeechToTextService.defaultRecognitionLanguage,
        initialSpeechToTextRecognitionLocales: {
          'multi': SpeechToTextService.defaultRecognitionLanguage,
          'en-US': 'en-US',
        },
        initialListeningDevices: [],
        initialListeningDeviceId: null,
        initialPlaybackDevices: [],
        initialPlaybackDeviceId: null,
        initialThemeMode: ThemeMode.system,
      ),
    );

    await tester.scrollUntilVisible(
      find.byType(Switch),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final advancedToggle = find.widgetWithText(
      SwitchListTile,
      'Show advanced options',
    );
    await tester.ensureVisible(advancedToggle);
    await tester.pumpAndSettle();
    await tester.tap(advancedToggle);
    await tester.pumpAndSettle();

    expect(find.text('Speech to Text'), findsOneWidget);
    expect(find.text('Deepgram Model'), findsOneWidget);
    expect(find.text('Translation'), findsOneWidget);
    expect(find.text('Text to Speech'), findsOneWidget);
  });

  testWidgets(
    'ProviderSettingsDialog filters target language options in the bottom sheet',
    (tester) async {
      await pumpTestApp(
        tester,
        const ProviderSettingsDialog(
          initialSttProvider: SpeechSttProvider.deepgram,
          initialTranslationProvider: SpeechTranslationProvider.google,
          initialOutputProvider: SpeechOutputProvider.google,
          initialTargetLanguage: 'en',
          targetLanguages: ['en', 'es', 'fr'],
          initialDeepgramRecognitionModel: 'nova-3',
          initialDeepgramRecognitionLanguage: 'multi',
          initialSpeechToTextRecognitionLocale:
              SpeechToTextService.defaultRecognitionLanguage,
          initialSpeechToTextRecognitionLocales: {
            'multi': SpeechToTextService.defaultRecognitionLanguage,
            'en-US': 'en-US',
          },
          initialListeningDevices: [],
          initialListeningDeviceId: null,
          initialPlaybackDevices: [],
          initialPlaybackDeviceId: null,
          initialThemeMode: ThemeMode.system,
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('target-language-settings')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(SearchableSelectionField.searchFieldKey),
        'span',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Spanish'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('target-language-settings')),
          matching: find.text('Spanish'),
        ),
        findsWidgets,
      );
    },
  );

  testWidgets('ProviderSettingsDialog shows current listening device details', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      const ProviderSettingsDialog(
        initialSttProvider: SpeechSttProvider.deepgram,
        initialTranslationProvider: SpeechTranslationProvider.google,
        initialOutputProvider: SpeechOutputProvider.google,
        initialTargetLanguage: 'en',
        targetLanguages: ['en', 'es'],
        initialDeepgramRecognitionModel: 'nova-3',
        initialDeepgramRecognitionLanguage: 'multi',
        initialSpeechToTextRecognitionLocale:
            SpeechToTextService.defaultRecognitionLanguage,
        initialSpeechToTextRecognitionLocales: {
          'multi': SpeechToTextService.defaultRecognitionLanguage,
          'en-US': 'en-US',
        },
        initialListeningDevices: [
          InputDevice(id: 'builtin', label: 'Built-in Microphone'),
        ],
        initialListeningDeviceId: null,
        initialPlaybackDevices: [
          PlaybackDevice(
            id: 'speaker',
            name: 'iPhone',
            type: 'Built-in Speaker',
          ),
        ],
        initialPlaybackDeviceId: null,
        initialThemeMode: ThemeMode.system,
      ),
    );

    expect(find.text('Listening Device'), findsOneWidget);
    expect(find.text('Current: Auto (Built-in Microphone)'), findsOneWidget);
    expect(find.text('No input devices detected'), findsNothing);
  });

  testWidgets(
    'ProviderSettingsDialog shows listening device selector when multiple are available',
    (tester) async {
      await pumpTestApp(
        tester,
        const ProviderSettingsDialog(
          initialSttProvider: SpeechSttProvider.deepgram,
          initialTranslationProvider: SpeechTranslationProvider.google,
          initialOutputProvider: SpeechOutputProvider.google,
          initialTargetLanguage: 'en',
          targetLanguages: ['en', 'es'],
          initialDeepgramRecognitionModel: 'nova-3',
          initialDeepgramRecognitionLanguage: 'multi',
          initialSpeechToTextRecognitionLocale:
              SpeechToTextService.defaultRecognitionLanguage,
          initialSpeechToTextRecognitionLocales: {
            'multi': SpeechToTextService.defaultRecognitionLanguage,
            'en-US': 'en-US',
          },
          initialListeningDevices: [
            InputDevice(id: 'builtin', label: 'Built-in Microphone'),
            InputDevice(id: 'usb-1', label: 'USB Microphone'),
          ],
          initialListeningDeviceId: 'usb-1',
          initialPlaybackDevices: [
            PlaybackDevice(
              id: 'speaker',
              name: 'iPhone',
              type: 'Built-in Speaker',
            ),
            PlaybackDevice(
              id: 'bt-1',
              name: 'AirPods Pro',
              type: 'Bluetooth A2DP',
            ),
          ],
          initialPlaybackDeviceId: 'bt-1',
          initialThemeMode: ThemeMode.system,
        ),
      );

      expect(find.text('Current: USB Microphone'), findsOneWidget);

      final deviceDropdown = find.byWidgetPredicate((widget) {
        return widget is DropdownMenuFormField<String?> &&
            widget.initialValue == 'usb-1';
      });
      expect(deviceDropdown, findsOneWidget);

      await tester.ensureVisible(deviceDropdown);
      await tester.pumpAndSettle();
      await tester.tap(deviceDropdown);
      await tester.pumpAndSettle();

      expect(find.text('Auto'), findsOneWidget);
    },
  );

  test('TestSpeechController emits listening device update messages', () async {
    final controller = TestSpeechController();
    final received = <String>[];
    final sub = controller.listeningDeviceUpdates.listen(received.add);

    controller.emitListeningDeviceUpdate('microphoneConnected: USB Mic');
    await Future<void>.delayed(Duration.zero);

    expect(received, contains('microphoneConnected: USB Mic'));

    await sub.cancel();
    controller.dispose();
  });
}
