import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:translation_intelligence/main.dart';
import 'package:translation_intelligence/models/playback_device.dart';
import 'package:translation_intelligence/services/speech_output_provider.dart';
import 'package:translation_intelligence/services/speech_stt_provider.dart';
import 'package:translation_intelligence/services/speech_to_text_service.dart';
import 'package:translation_intelligence/services/speech_translation_provider.dart';

import 'speech_controller_stub.dart';
import 'test_app.dart';

void main() {
  testWidgets(
    'ProviderSettingsDialog shows Settings title, Providers sub-header, and ordered labels',
    (tester) async {
      await pumpTestApp(
        tester,
        const ProviderSettingsDialog(
          initialSttProvider: SpeechSttProvider.deepgram,
          initialTranslationProvider: SpeechTranslationProvider.google,
          initialOutputProvider: SpeechOutputProvider.google,
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
      expect(find.text('Providers'), findsWidgets);

      final textWidgets = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Text),
        ),
      );

      final labels = textWidgets
          .map((widget) => widget.data)
          .whereType<String>()
          .toList(growable: false);

      final speechToTextIndex = labels.indexOf('Speech to Text');
      final deepgramModelIndex = labels.indexOf('Deepgram Model');
      final deepgramLanguageIndex = labels.indexOf('Deepgram Language');
      final translationIndex = labels.indexOf('Translation');
      final textToSpeechIndex = labels.indexOf('Text to Speech');

      expect(speechToTextIndex, isNonNegative);
      expect(deepgramModelIndex, isNonNegative);
      expect(deepgramLanguageIndex, isNonNegative);
      expect(translationIndex, isNonNegative);
      expect(textToSpeechIndex, isNonNegative);
      expect(speechToTextIndex, lessThan(translationIndex));
      expect(speechToTextIndex, lessThan(deepgramModelIndex));
      expect(deepgramModelIndex, lessThan(deepgramLanguageIndex));
      expect(deepgramLanguageIndex, lessThan(translationIndex));
      expect(translationIndex, lessThan(textToSpeechIndex));
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

    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();

    expect(find.text('Audio'), findsWidgets);
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

      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();

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
