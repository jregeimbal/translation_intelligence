import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_intelligence/services/deepgram_recognition_catalog.dart';
import 'package:translation_intelligence/services/speech_to_text_service.dart';

class AppPreferencesSnapshot {
  final String deepgramRecognitionModel;
  final String deepgramRecognitionLanguage;
  final String speechToTextRecognitionLocale;
  final String targetLanguage;
  final bool hideTranslatedOriginalText;
  final bool audioPlaybackEnabled;
  final bool hasCompletedFirstLaunchWalkthrough;

  const AppPreferencesSnapshot({
    required this.deepgramRecognitionModel,
    required this.deepgramRecognitionLanguage,
    required this.speechToTextRecognitionLocale,
    required this.targetLanguage,
    required this.hideTranslatedOriginalText,
    required this.audioPlaybackEnabled,
    required this.hasCompletedFirstLaunchWalkthrough,
  });
}

class AppPreferences {
  static const _deepgramRecognitionModelKey = 'pref.deepgramRecognitionModel';
  static const _deepgramRecognitionLanguageKey =
      'pref.deepgramRecognitionLanguage';
  static const _speechToTextRecognitionLocaleKey =
      'pref.speechToTextRecognitionLocale';
  static const _targetLanguageKey = 'pref.targetLanguage';
  static const _hideTranslatedOriginalTextKey =
      'pref.hideTranslatedOriginalText';
  static const _audioPlaybackEnabledKey = 'pref.audioPlaybackEnabled';
  static const _hasCompletedFirstLaunchWalkthroughKey =
      'pref.hasCompletedFirstLaunchWalkthrough';

  final Future<SharedPreferences> Function() _getPreferences;

  AppPreferences({Future<SharedPreferences> Function()? getPreferences})
    : _getPreferences = getPreferences ?? SharedPreferences.getInstance;

  Future<AppPreferencesSnapshot> load() async {
    final preferences = await _getPreferences();
    final deepgramRecognitionModel =
        preferences.getString(_deepgramRecognitionModelKey) ??
        DeepgramRecognitionCatalog.defaultRecognitionModel;
    final deepgramRecognitionLanguage =
        preferences.getString(_deepgramRecognitionLanguageKey) ??
        DeepgramRecognitionCatalog.defaultRecognitionLanguageForModel(
          deepgramRecognitionModel,
        );
    final speechToTextRecognitionLocale =
        preferences.getString(_speechToTextRecognitionLocaleKey) ??
        SpeechToTextService.defaultRecognitionLanguage;
    final targetLanguage = preferences.getString(_targetLanguageKey) ?? 'en';
    final hideTranslatedOriginalText =
        preferences.getBool(_hideTranslatedOriginalTextKey) ?? true;
    final audioPlaybackEnabled =
        preferences.getBool(_audioPlaybackEnabledKey) ?? true;
    final hasCompletedFirstLaunchWalkthrough =
        preferences.getBool(_hasCompletedFirstLaunchWalkthroughKey) ?? false;

    return AppPreferencesSnapshot(
      deepgramRecognitionModel: deepgramRecognitionModel,
      deepgramRecognitionLanguage: deepgramRecognitionLanguage,
      speechToTextRecognitionLocale: speechToTextRecognitionLocale,
      targetLanguage: targetLanguage,
      hideTranslatedOriginalText: hideTranslatedOriginalText,
      audioPlaybackEnabled: audioPlaybackEnabled,
      hasCompletedFirstLaunchWalkthrough: hasCompletedFirstLaunchWalkthrough,
    );
  }

  Future<void> setDeepgramRecognitionModel(String value) async {
    final preferences = await _getPreferences();
    await preferences.setString(_deepgramRecognitionModelKey, value);
  }

  Future<void> setDeepgramRecognitionLanguage(String value) async {
    final preferences = await _getPreferences();
    await preferences.setString(_deepgramRecognitionLanguageKey, value);
  }

  Future<void> setSpeechToTextRecognitionLocale(String value) async {
    final preferences = await _getPreferences();
    await preferences.setString(_speechToTextRecognitionLocaleKey, value);
  }

  Future<void> setTargetLanguage(String value) async {
    final preferences = await _getPreferences();
    await preferences.setString(_targetLanguageKey, value);
  }

  Future<void> setHideTranslatedOriginalText(bool value) async {
    final preferences = await _getPreferences();
    await preferences.setBool(_hideTranslatedOriginalTextKey, value);
  }

  Future<void> setAudioPlaybackEnabled(bool value) async {
    final preferences = await _getPreferences();
    await preferences.setBool(_audioPlaybackEnabledKey, value);
  }

  Future<void> setHasCompletedFirstLaunchWalkthrough(bool value) async {
    final preferences = await _getPreferences();
    await preferences.setBool(_hasCompletedFirstLaunchWalkthroughKey, value);
  }
}
