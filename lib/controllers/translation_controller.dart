import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../models/chat_message.dart';
import '../services/app_language_catalog.dart';
import '../services/audio_playback_queue.dart';
import '../services/speech_output_provider.dart';
import '../services/speech_pipeline.dart';
import '../services/speech_stt_provider.dart';
import '../services/speech_translation_provider.dart';

final _logger = Logger('TranslationController');

class TranslationController extends ChangeNotifier {
  TranslationController({
    SpeechPipeline? speechPipeline,
    Duration audioPlaybackCompletionTimeout = const Duration(seconds: 30),
  }) : _speechPipeline = speechPipeline ?? SpeechPipeline(),
       _audioPlaybackCompletionTimeout = audioPlaybackCompletionTimeout;

  final SpeechPipeline _speechPipeline;
  final Duration _audioPlaybackCompletionTimeout;

  AudioPlayer? _audioPlayer;
  final AudioPlaybackQueue _audioPlaybackQueue = AudioPlaybackQueue();

  bool _audioPlaybackEnabled = true;
  String _targetLanguage = 'en';

  bool get audioPlaybackEnabled => _audioPlaybackEnabled;
  String get targetLanguage => _targetLanguage;

  SpeechOutputProvider get outputProvider => _speechPipeline.outputProvider;
  SpeechSttProvider get sttProvider => _speechPipeline.sttProvider;
  SpeechTranslationProvider get translationProvider =>
      _speechPipeline.translationProvider;

  bool get hasSupportedTargetLanguage {
    return AppLanguageCatalog.isSupported(_targetLanguage);
  }

  void setAudioPlaybackEnabled({required bool enabled}) {
    if (_audioPlaybackEnabled == enabled) return;
    _audioPlaybackEnabled = enabled;
    notifyListeners();
  }

  void setTargetLanguage(String lang) {
    if (lang != _targetLanguage) {
      _targetLanguage = lang;
      notifyListeners();
    }
  }

  void setOutputProvider(SpeechOutputProvider provider) {
    if (_speechPipeline.outputProvider == provider) return;
    _speechPipeline.setOutputProvider(provider);
    notifyListeners();
  }

  void setSttProvider(SpeechSttProvider provider) {
    if (_speechPipeline.sttProvider == provider) return;
    _speechPipeline.setSttProvider(provider);
    notifyListeners();
  }

  void setTranslationProvider(SpeechTranslationProvider provider) {
    if (_speechPipeline.translationProvider == provider) return;
    _speechPipeline.setTranslationProvider(provider);
    notifyListeners();
  }

  Future<void> replayTranslation(ChatMessage message) async {
    final translation = _resolvedTranslationText(message);
    if (translation == null) return;

    try {
      final audio = await _synthesizeSpeech(translation, _targetLanguage);
      await _playAudio(audio);
    } catch (e) {
      _logger.severe('translation replay error: ${e.toString()}', e);
    }
  }

  String? _resolvedTranslationText(ChatMessage message) {
    final directTranslation = message.translation?.trim();
    if (directTranslation != null && directTranslation.isNotEmpty) {
      return directTranslation;
    }

    final groupedTranslation = message.groups
        .map((group) => group.translation?.trim())
        .whereType<String>()
        .where((translation) => translation.isNotEmpty)
        .join(' ')
        .trim();
    return groupedTranslation.isEmpty ? null : groupedTranslation;
  }

  Future<Uint8List> _synthesizeSpeech(String text, String appLanguage) async {
    return _speechPipeline.synthesizeSpeech(
      text: text,
      languageCode: _speechPipeline.ttsLanguageCodeForAppLanguage(appLanguage),
    );
  }

  Future<void> _playAudio(Uint8List bytes) async {
    if (bytes.isEmpty) return;
    await _audioPlaybackQueue.enqueue(() async {
      try {
        _audioPlayer ??= AudioPlayer();
        final player = _audioPlayer!;
        _logger.finest(
          '${DateTime.now().toUtc()} Playing audio of length ${bytes.length} bytes',
        );
        final playbackContext =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? AudioContextConfig(
                focus: AudioContextConfigFocus.mixWithOthers,
              ).build()
            : null;
        await player.play(BytesSource(bytes), ctx: playbackContext);

        final completionFuture = player.onPlayerComplete.first
            .then((_) {})
            .catchError((_) {});

        await Future.any<void>([
          completionFuture,
          Future<void>.delayed(_audioPlaybackCompletionTimeout),
        ]);
        _logger.finest('${DateTime.now().toUtc()} Audio playback started');
      } catch (e) {
        _logger.severe('audio playback error $e', e);
      }
    });
  }

  void setSessionInfo({String? sourceLanguage}) {}

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }
}
