import 'package:flutter/material.dart';

import '../services/speech_output_provider.dart';
import '../services/speech_stt_provider.dart';
import '../services/speech_translation_provider.dart';

class ProviderSettingsSelection {
  final SpeechSttProvider sttProvider;
  final SpeechTranslationProvider translationProvider;
  final SpeechOutputProvider outputProvider;
  final String targetLanguage;
  final String deepgramRecognitionModel;
  final String deepgramRecognitionLanguage;
  final String speechToTextRecognitionLocale;
  final Map<String, String> speechToTextRecognitionLocales;
  final String? listeningDeviceId;
  final String? playbackDeviceId;
  final ThemeMode themeMode;

  const ProviderSettingsSelection({
    required this.sttProvider,
    required this.translationProvider,
    required this.outputProvider,
    required this.targetLanguage,
    required this.deepgramRecognitionModel,
    required this.deepgramRecognitionLanguage,
    required this.speechToTextRecognitionLocale,
    required this.speechToTextRecognitionLocales,
    required this.listeningDeviceId,
    required this.playbackDeviceId,
    required this.themeMode,
  });
}
