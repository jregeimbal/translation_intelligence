import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/main.dart';
import 'package:translation_intelligence/services/speech_output_provider.dart';
import 'package:translation_intelligence/services/speech_stt_provider.dart';
import 'package:translation_intelligence/services/speech_translation_provider.dart';

void main() {
  testWidgets('ProviderSettingsDialog shows Settings title, Providers sub-header, and ordered labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProviderSettingsDialog(
            initialSttProvider: SpeechSttProvider.deepgram,
            initialTranslationProvider: SpeechTranslationProvider.google,
            initialOutputProvider: SpeechOutputProvider.google,
            initialDeepgramRecognitionModel: 'nova-3',
            initialDeepgramRecognitionLanguage: 'multi',
          ),
        ),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Providers'), findsOneWidget);

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
  });
}
