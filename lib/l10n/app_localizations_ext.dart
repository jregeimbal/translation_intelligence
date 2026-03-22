import 'package:flutter/material.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'app_localizations.dart';

import '../services/speech_output_provider.dart';
import '../services/speech_stt_provider.dart';
import '../services/speech_translation_provider.dart';

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

String localizedSpeechError(BuildContext context, String error) {
  switch (error) {
    case 'microphonePermissionDenied':
      return context.l10n.microphonePermissionDenied;
    case 'invalidSpeechApiKey':
      return context.l10n.invalidSpeechApiKey;
    default:
      return error;
  }
}

String localizedListeningDeviceUpdate(BuildContext context, String message) {
  final separatorIndex = message.indexOf(': ');
  if (separatorIndex == -1) {
    return _localizedDeviceUpdatePrefix(context, message);
  }

  final prefix = message.substring(0, separatorIndex);
  final details = message.substring(separatorIndex + 2);
  return context.l10n.messageWithDetails(
    _localizedDeviceUpdatePrefix(context, prefix),
    details,
  );
}

String localizedAppLanguageName(BuildContext context, String languageCode) {
  final l10n = context.l10n;
  switch (languageCode) {
    case 'en':
      return l10n.languageEnglish;
    case 'es':
      return l10n.languageSpanish;
    case 'fr':
      return l10n.languageFrench;
    case 'de':
      return l10n.languageGerman;
    case 'zh-CN':
    case 'zh':
      return l10n.languageChineseSimplified;
    case 'ja':
      return l10n.languageJapanese;
    case 'ko':
      return l10n.languageKorean;
    case 'pt':
      return l10n.languagePortuguese;
    case 'ru':
      return l10n.languageRussian;
    case 'ar':
      return l10n.languageArabic;
    case 'hi':
      return l10n.languageHindi;
    default:
      return _localizedLocaleName(context, languageCode) ?? languageCode;
  }
}

String localizedRecognitionLocaleLabel(
  BuildContext context,
  String localeCode,
) {
  if (localeCode == 'multi') {
    return context.l10n.multiAuto;
  }
  return _localizedLocaleName(context, localeCode) ?? localeCode;
}

String localizedDeepgramLanguageLabel(BuildContext context, String localeCode) {
  if (localeCode == 'multi') {
    return context.l10n.multiAuto;
  }
  return _localizedLocaleName(context, localeCode) ?? localeCode;
}

String localizedSttProviderLabel(
  BuildContext context,
  SpeechSttProvider provider,
) {
  switch (provider) {
    case SpeechSttProvider.deepgram:
      return context.l10n.sttProviderDeepgram;
    case SpeechSttProvider.google:
      return context.l10n.sttProviderGoogle;
  }
}

String localizedTranslationProviderLabel(
  BuildContext context,
  SpeechTranslationProvider provider,
) {
  switch (provider) {
    case SpeechTranslationProvider.google:
      return context.l10n.translationProviderGoogle;
    case SpeechTranslationProvider.googleMlKit:
      return context.l10n.translationProviderGoogleMlKit;
  }
}

String localizedOutputProviderLabel(
  BuildContext context,
  SpeechOutputProvider provider,
) {
  switch (provider) {
    case SpeechOutputProvider.google:
      return context.l10n.outputProviderGoogle;
    case SpeechOutputProvider.deepgram:
      return context.l10n.outputProviderDeepgram;
  }
}

String _localizedDeviceUpdatePrefix(BuildContext context, String message) {
  switch (message) {
    case 'microphoneConnected':
      return context.l10n.microphoneConnected;
    case 'microphoneDisconnected':
      return context.l10n.microphoneDisconnected;
    case 'audioRouteChanged':
      return context.l10n.audioRouteChanged;
    case 'listeningDeviceListUpdated':
      return context.l10n.listeningDeviceListUpdated;
    default:
      return message;
  }
}

String? _localizedLocaleName(BuildContext context, String localeCode) {
  final normalized = localeCode.replaceAll('-', '_');
  return LocaleNames.of(context)?.nameOf(normalized);
}
