import 'dart:async';
import 'dart:math';

import 'package:speech_to_text/speech_to_text.dart';

import '../models/speech_recognition_models.dart';

class SpeechToTextService {

  SpeechToTextService({
    SpeechToText? speechToText,
    Duration inactivityFinalizeDelay = const Duration(seconds: 1),
  }) : _speechToText = speechToText ?? SpeechToText(),
       _inactivityFinalizeDelay = inactivityFinalizeDelay;
  static const String defaultRecognitionLanguage = 'multi';

  final SpeechToText _speechToText;
  final Duration _inactivityFinalizeDelay;
  bool _initialized = false;
  Timer? _finalizeTimer;
  String _lastTranscript = '';
  String _lastFinalizedTranscript = '';

  Future<bool> initialize({String languageCode = 'en-US'}) async {
    if (_initialized) return true;
    _initialized = await _speechToText.initialize();
    return _initialized;
  }

  Future<void> startListening({
    required String? languageCode,
    required void Function(SpeechRecognitionResult result) onResult,
    required void Function(double value) onAmplitude,
  }) async {
    final ready = await initialize(languageCode: languageCode ?? 'en-US');
    if (!ready) {
      throw Exception('Speech to Text is unavailable on this device');
    }

    _finalizeTimer?.cancel();
    _lastTranscript = '';
    _lastFinalizedTranscript = '';

    void scheduleInactivityFinal() {
      _finalizeTimer?.cancel();
      _finalizeTimer = Timer(_inactivityFinalizeDelay, () {
        if (_lastTranscript.isEmpty ||
            _lastTranscript == _lastFinalizedTranscript) {
          return;
        }
        onResult(
          SpeechRecognitionResult.fromTranscript(
            transcript: _lastTranscript.substring(
              min(_lastTranscript.length, _lastFinalizedTranscript.length),
            ),
            isFinal: true,
          ),
        );
        _lastFinalizedTranscript = _lastTranscript;
        _lastTranscript = '';
      });
    }

    await _speechToText.listen(
      localeId: languageCode,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (result) {
        final transcript = result.recognizedWords.trim();
        final hasNewWords =
            transcript.isNotEmpty && transcript != _lastTranscript;
        _lastTranscript = transcript;

        onResult(
          SpeechRecognitionResult.fromTranscript(
            transcript: _lastTranscript.substring(
              min(_lastTranscript.length, _lastFinalizedTranscript.length),
            ),
            isFinal: result.finalResult,
          ),
        );

        if (result.finalResult) {
          _finalizeTimer?.cancel();
          if (transcript.isNotEmpty) {
            _lastFinalizedTranscript = transcript;
            _lastTranscript = '';
          }
          return;
        }

        if (hasNewWords) {
          scheduleInactivityFinal();
        }
      },
      onSoundLevelChange: (level) {
        final normalized = ((level + 2.0) / 12.0).clamp(0.0, 1.0);
        onAmplitude(normalized);
      },
    );
  }

  Future<void> stopListening() async {
    _finalizeTimer?.cancel();
    _finalizeTimer = null;
    _lastTranscript = '';
    _lastFinalizedTranscript = '';
    await _speechToText.stop();
  }

  Future<Map<String, String>> supportedRecognitionLocales() async {
    final locales = <String>{};

    try {
      final results = await _speechToText.locales();
      for (final locale in results) {
        final dynamic item = locale;
        final localeId = item.localeId?.toString();
        if (localeId != null && localeId.isNotEmpty) {
          locales.add(localeId);
        }
      }
    } catch (_) {}

    final sorted = locales.toList()..sort();
    return <String, String>{
      'multi': defaultRecognitionLanguage,
      for (final locale in sorted) locale: locale,
    };
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
