import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:stts/stts.dart';

import '../models/speech_recognition_models.dart';

final logger = Logger('STTS Service'); // Create a logger with a name

class SttsService {
  static const String defaultRecognitionLanguage = 'multi';

  final Stt _stt = Stt();
  final Tts _tts = Tts();
  StreamSubscription<SttRecognition>? _resultSub;

  Future<bool> initialize({String? languageCode}) async {
    final supported = await _stt.isSupported();
    if (!supported) return false;

    final hasPermission = await _stt.hasPermission();
    if (!hasPermission) return false;

    if (languageCode != null && languageCode.isNotEmpty) {
      try {
        await _stt.setLanguage(languageCode);
      } catch (_) {}
    }

    return true;
  }

  Future<void> startListening({
    required String? languageCode,
    required void Function(SpeechRecognitionResult result) onResult,
    required void Function(double value) onAmplitude,
  }) async {
    final ready = await initialize(languageCode: languageCode);
    if (!ready) {
      throw Exception('STTS is unavailable on this device');
    }
    logger.info(
      'STTS started listening with language: ${languageCode ?? 'default'}',
    );
    logger.info(
      'STTS supported locales: ${await supportedRecognitionLocales()}',
    );
    await _resultSub?.cancel();
    _resultSub = _stt.onResultChanged.listen((recognition) {
      onAmplitude(recognition.isFinal ? 0.0 : 0.5);
      onResult(
        SpeechRecognitionResult.fromTranscript(
          transcript: recognition.text.trim(),
          isFinal: recognition.isFinal,
        ),
      );
    });

    await _stt.start(const SttRecognitionOptions());
  }

  Future<Map<String, String>> supportedRecognitionLocales() async {
    final locales = <String>{};

    try {
      final dynamic dynamicStt = _stt;
      final dynamic result = await dynamicStt.getLocales();
      locales.addAll(_extractLocaleCodes(result));
    } catch (_) {}

    if (locales.isEmpty) {
      try {
        locales.addAll(await _stt.getLanguages());
      } catch (_) {}
    }

    final sorted = locales.where((locale) => locale.isNotEmpty).toList()
      ..sort();

    return <String, String>{
      'Multi (Auto)': defaultRecognitionLanguage,
      for (final locale in sorted) locale: locale,
    };
  }

  List<String> _extractLocaleCodes(dynamic result) {
    if (result is! Iterable) {
      return const <String>[];
    }

    final locales = <String>[];
    for (final item in result) {
      if (item is String) {
        locales.add(item);
        continue;
      }

      if (item is Map) {
        final localeId =
            item['localeId']?.toString() ??
            item['locale_id']?.toString() ??
            item['id']?.toString();
        if (localeId != null && localeId.isNotEmpty) {
          locales.add(localeId);
        }
      }
    }
    return locales;
  }

  Future<void> stopListening() async {
    await _resultSub?.cancel();
    _resultSub = null;
    await _stt.stop();
  }

  Future<Uint8List> synthesizeSpeech({
    required String text,
    String languageCode = 'en-US',
  }) async {
    if (text.trim().isEmpty) {
      return Uint8List(0);
    }

    final supported = await _tts.isSupported();
    if (!supported) {
      return Uint8List(0);
    }

    try {
      await _tts.setLanguage(languageCode);
    } catch (_) {}

    await _tts.start(text);
    return Uint8List(0);
  }

  String? languageCodeForAppLanguage(String appLang) {
    switch (appLang) {
      case 'multi':
        return null;
      case 'en':
        return 'en-US';
      case 'es':
        return 'es-ES';
      case 'fr':
        return 'fr-FR';
      case 'de':
        return 'de-DE';
      case 'zh-CN':
      case 'zh':
        return 'zh-CN';
      case 'ja':
        return 'ja-JP';
      case 'ko':
        return 'ko-KR';
      case 'pt':
        return 'pt-BR';
      case 'ru':
        return 'ru-RU';
      case 'ar':
        return 'ar-SA';
      case 'hi':
        return 'hi-IN';
      default:
        return appLang;
    }
  }
}
