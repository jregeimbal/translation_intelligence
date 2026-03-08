import 'dart:developer' as developer;

import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class MlKitTranslationService {
  final OnDeviceTranslatorModelManager _modelManager;

  MlKitTranslationService({OnDeviceTranslatorModelManager? modelManager})
    : _modelManager = modelManager ?? OnDeviceTranslatorModelManager();

  Future<String?> translateText({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
    bool returnOriginalOnFailure = true,
    bool nullWhenUnchanged = false,
  }) async {
    developer.log('Translating "$text" from "$sourceLanguage" to "$targetLanguage" using ML Kit', name: 'MlKitTranslationService');
    final resolvedSource = _toTranslateLanguage(sourceLanguage ?? 'en');
    final resolvedTarget = _toTranslateLanguage(targetLanguage);

    if (resolvedSource == null || resolvedTarget == null) {
      return returnOriginalOnFailure ? text : null;
    }

    if (resolvedSource == resolvedTarget) {
      return nullWhenUnchanged ? null : text;
    }

    try {
      final sourceDownloaded = await _modelManager.isModelDownloaded(
        resolvedSource.bcpCode,
      );
      if (!sourceDownloaded) {
        developer.log('Downloading model for "$resolvedSource"', name: 'MlKitTranslationService');
        await _modelManager.downloadModel(resolvedSource.bcpCode);
      }

      final targetDownloaded = await _modelManager.isModelDownloaded(
        resolvedTarget.bcpCode,
      );
      if (!targetDownloaded) {
        developer.log('Downloading model for "$resolvedTarget"', name: 'MlKitTranslationService');
        await _modelManager.downloadModel(resolvedTarget.bcpCode);
      }

      final translator = OnDeviceTranslator(
        sourceLanguage: resolvedSource,
        targetLanguage: resolvedTarget,
      );

      try {
        final translated = await translator.translateText(text);
        developer.log('Translation result: "$translated"', name: 'MlKitTranslationService');
        if (nullWhenUnchanged && translated == text) {
          return null;
        }
        return translated;
      } finally {
        translator.close();
      }
    } catch (e) {
      developer.log('Translation failed: $e', name: 'MlKitTranslationService');
      if (returnOriginalOnFailure) {
        return text;
      }
      rethrow;
    }
  }

  TranslateLanguage? _toTranslateLanguage(String appLanguageCode) {
    final normalized = appLanguageCode.trim();
    switch (normalized) {
      case 'ar':
        return TranslateLanguage.arabic;
      case 'de':
        return TranslateLanguage.german;
      case 'en':
        return TranslateLanguage.english;
      case 'es':
        return TranslateLanguage.spanish;
      case 'fr':
        return TranslateLanguage.french;
      case 'hi':
        return TranslateLanguage.hindi;
      case 'ja':
        return TranslateLanguage.japanese;
      case 'ko':
        return TranslateLanguage.korean;
      case 'pt':
      case 'pt-BR':
      case 'pt-PT':
        return TranslateLanguage.portuguese;
      case 'ru':
        return TranslateLanguage.russian;
      case 'zh':
      case 'zh-CN':
      case 'zh-TW':
        return TranslateLanguage.chinese;
      default:
        return null;
    }
  }
}
