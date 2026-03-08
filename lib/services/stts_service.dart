import 'dart:async';
import 'dart:typed_data';

import 'package:stts/stts.dart';

import 'speech_recognition_models.dart';

class SttsService {
  final Stt _stt = Stt();
  final Tts _tts = Tts();
  StreamSubscription<SttRecognition>? _resultSub;

  Future<bool> initialize({String languageCode = 'en-US'}) async {
    final supported = await _stt.isSupported();
    if (!supported) return false;

    final hasPermission = await _stt.hasPermission();
    if (!hasPermission) return false;

    try {
      await _stt.setLanguage(languageCode);
    } catch (_) {}

    return true;
  }

  Future<void> startListening({
    required String? languageCode,
    required void Function(SpeechRecognitionResult result) onResult,
    required void Function(double value) onAmplitude,
  }) async {
    final lang = languageCode ?? 'en-US';
    final ready = await initialize(languageCode: lang);
    if (!ready) {
      throw Exception('STTS is unavailable on this device');
    }

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
        return 'en-US';
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
