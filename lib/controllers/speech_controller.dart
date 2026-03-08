import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/queued_chat_message.dart';
import '../services/audio_playback_queue.dart';
import '../services/speech_pipeline.dart';
import '../services/speech_output_provider.dart';
import '../services/speech_stt_provider.dart';
import '../services/speech_translation_provider.dart';
import '../widgets/chat_message.dart';

final logger = Logger('SpeechController'); // Create a logger with a name

/// Manages a live recognition session and exposes application-wide
/// state.  Receives raw audio from the microphone via `record` and sends it to
/// speech recognition for transcription.  Translation/tts logic is unchanged from the
/// previous version of the demo.
///
/// Notifies listeners when relevant properties change so individual widgets
/// can rebuild independently.
class SpeechController extends ChangeNotifier {
  final SpeechPipeline _speechPipeline;
  Duration _finalResultGroupingWindow;
  final Duration _audioPlaybackCompletionTimeout;
  final AudioRecorder _recorder = AudioRecorder();
  AudioPlayer? _audioPlayer;
  final AudioPlaybackQueue _audioPlaybackQueue = AudioPlaybackQueue();
  final String googleApiKey;

  bool _speechEnabled = false; // speech service + permission
  bool _isListening = false;
  String _speechError = '';
  double _amplitude = 0.0; // normalized 0.0‑1.0 (mapped from dB-truncated values)
  StreamSubscription<SpeechRecognitionResult>? _recognitionSub;
  StreamSubscription<double>? _ampSub;
  SpeechRecognitionSession? _recognitionSession;
  Timer? _finalResultTimer;
  // final List<SpeechRecognitionWord> _pendingFinalWords = [];
  List<QueuedChatMessage> _queuedMessages = [];
  final List<SpeechRecognitionWord> _partialWords = [];
  final List<ChatMessage> _chatMessages = [];

  /// ID of speaker whose messages should be right-aligned in the UI.
  /// Null means no preference (all left).
  int? preferredSpeaker;

  SpeechController({
    required this.googleApiKey,
    required String deepgramApiKey,
    SpeechPipeline? speechPipeline,
    Duration finalResultGroupingWindow = const Duration(seconds: 2),
    Duration audioPlaybackCompletionTimeout = const Duration(seconds: 30),
  }) : _speechPipeline =
           speechPipeline ??
           SpeechPipeline(
             googleApiKey: googleApiKey,
             deepgramApiKey: deepgramApiKey,
           ),
       _finalResultGroupingWindow = finalResultGroupingWindow,
       _audioPlaybackCompletionTimeout = audioPlaybackCompletionTimeout;

  set finalResultGroupingWindow(Duration value) {
    if (value != _finalResultGroupingWindow) {
      _finalResultGroupingWindow = value;
    }
  }
  bool get speechEnabled => _speechEnabled;
  bool get isListening => _isListening;
  String get speechError => _speechError;
  double get amplitude => _amplitude;
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  SpeechOutputProvider get outputProvider => _speechPipeline.outputProvider;
  SpeechSttProvider get sttProvider => _speechPipeline.sttProvider;
  SpeechTranslationProvider get translationProvider =>
      _speechPipeline.translationProvider;

  List<ChatMessage> wordsToMessages(List<ChatMessage> oldMessages, Iterable<SpeechRecognitionWord> words, {bool isFinal = false}) {
    final newMessages = (json.decode(json.encode(oldMessages)) as List).map((e) => ChatMessage.fromJson(e)).toList();

    Map<int, List<SpeechRecognitionWord>> mergedBySpeaker = {};

    // Group words by speaker, using -1 for unknown speakers
    for (var word in words) {
      final key = word.speaker ?? -1; // Use -1 as the key for unknown speakers
      mergedBySpeaker[key] =  [
        ...?mergedBySpeaker[key],
        word,
      ];
    }
    
    // Add a comma to the end of existing messages if the same speaker continues speaking in a new message
    for (var newMsg in newMessages) {
      if (mergedBySpeaker.containsKey(newMsg.speaker ?? -1)) {
        newMsg.original = '${newMsg.original},';
      }
      newMsg.isFinal = isFinal;
    }

    if (words.isNotEmpty) {
      // Merge words into existing messages by speaker, or create new messages if no existing message for that speaker
      for (var word in words) {
        if (newMessages.any((m) => m.speaker == word.speaker)) {
          // If there's already a message for this speaker, append the new word to it
          final existingMsg = newMessages.firstWhere((m) => m.speaker == word.speaker);
          existingMsg.original = '${existingMsg.original} ${word.word}';
        } else {
          // If there's no existing message for this speaker, create a new one
          newMessages.add(ChatMessage(
            word.word,
            speaker: word.speaker,
            isFinal: isFinal,
          ));
        }
      }
        
      logger.info('wordsToMessages newMessages: ${newMessages.toString()}');

    }
    return newMessages;
  }

  List<ChatMessage> getOptimisticMessages() {
    return wordsToMessages(_queuedMessagesAsChatMessages(), _partialWords);
  }

  List<ChatMessage> _queuedMessagesAsChatMessages() {
    return _queuedMessages
        .map((queued) => queued.toChatMessage(isFinal: false))
        .toList(growable: false);
  }

  void _maybeDefaultPreferred(int? speaker) {
    if (preferredSpeaker == null && speaker != null) {
      setPreferredSpeaker(speaker);
    }
  }

  /// Known speaker IDs seen in the conversation.
  Set<int> get speakers =>
      _chatMessages.map((m) => m.speaker).whereType<int>().toSet();

  /// Update the speaker that should be right-aligned.
  void setPreferredSpeaker(int? speaker) {
    preferredSpeaker = speaker;
    notifyListeners();
  }

  /// Remove all accumulated messages from the chat history.
  void clearMessages() {
    _chatMessages.clear();
    notifyListeners();
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

  // translation + TTS helpers ------------------------------------------------

  // Desired language code for translation (Google Translate format).
  // Defaults to English; the UI allows the user to override this.
  String _targetLanguage = 'en';
  String get targetLanguage => _targetLanguage;
  /// Friendly name for the current translation language, falling back to
  /// the raw code if not found in the map.
  String get targetLanguageName {
    final entry = supportedLanguages.entries
        .firstWhere((e) => e.value == _targetLanguage,
            orElse: () => MapEntry(_targetLanguage, _targetLanguage));
    return entry.key;
  }

  void setTargetLanguage(String lang) {
    if (lang != _targetLanguage) {
      _targetLanguage = lang;
      notifyListeners();
    }
  }

  /// A small map of user‑friendly names to language codes.  Feel free to
  /// extend this list as needed; Nova‑3 supports all of them.
  static const Map<String, String> supportedLanguages = {
    'English': 'en',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
    'Chinese (Simplified)': 'zh-CN',
    'Japanese': 'ja',
    'Korean': 'ko',
    'Portuguese': 'pt',
    'Russian': 'ru',
    'Arabic': 'ar',
    'Hindi': 'hi',
    // add any additional Nova‑3 supported codes here
  };

  Future<void> _translateAndSpeak(ChatMessage msg) async {
    // if this message is from the preferred speaker, we still translate
    // (so UI shows the english), but we don't play TTS audio.
    try {
      final translated = await _translateText(msg.original);
      if (translated == null) return;
      msg.translation = translated;
      notifyListeners();
      if (msg.speaker != null && msg.speaker == preferredSpeaker) {
        return; // skip TTS for the highlighted speaker
      }
      final audio = await _synthesizeSpeech(translated, _targetLanguage);
      await _playAudio(audio);
    } catch (e) {
      logger.severe(
        'translation/tts error',
        e,
      );
    }
  }

  Future<void> _translateAndSpeakQueued(QueuedChatMessage msg) async {
    try {
      final translated = await _translateText(msg.original);
      if (translated == null) return;
      msg.translation = translated;
      _applyQueuedTranslationToCommittedMessage(msg, translated);
      notifyListeners();
      if (msg.speaker != null && msg.speaker == preferredSpeaker) {
        return;
      }
      final audio = await _synthesizeSpeech(translated, _targetLanguage);
      await _playAudio(audio);
    } catch (e) {
      logger.severe(
        'queued translation/tts error',
        e,
      );
    }
  }

  void _applyQueuedTranslationToCommittedMessage(
    QueuedChatMessage queued,
    String translation,
  ) {
    for (var i = _chatMessages.length - 1; i >= 0; i--) {
      final committed = _chatMessages[i];
      if (committed.speaker != queued.speaker) {
        continue;
      }

      if (committed.original == queued.original ||
          committed.original == '${queued.original}.') {
        committed.translation = translation;
        break;
      }
    }
  }

  Future<String?> _translateText(String text) async {
    return _speechPipeline.translateText(
      text: text,
      targetLanguage: _targetLanguage,
      sourceLanguage: 'es', // for testing, we can hardcode Spanish as the source to verify translation is working https://developers.google.com/ml-kit/language/translation/translation-language-support
      returnOriginalOnFailure: false,
      throwOnMissingApiKey: true,
      nullWhenUnchanged: true,
    );
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
        logger.finest(
          '${DateTime.now().toUtc()} Playing audio of length ${bytes.length} bytes',
        );
        final playbackContext = !kIsWeb &&
                defaultTargetPlatform == TargetPlatform.android
            ? AudioContextConfig(
                focus: AudioContextConfigFocus.mixWithOthers,
              ).build()
            : null;
        await player.play(BytesSource(bytes), ctx: playbackContext);
        await Future.any<void>([
          player.onPlayerComplete.first,
          Future<void>.delayed(_audioPlaybackCompletionTimeout),
        ]);
        logger.finest(
          '${DateTime.now().toUtc()} Audio playback started',
        );
      } catch (e) {
        logger.severe(
          'audio playback error $e',
          e,
        );
      }
    });
  }

  /// Initialize recorder permission and verify the speech API key.
  ///
  /// After this completes `speechEnabled` will be true if we have both
  /// microphone permission and a valid key; otherwise widgets know to disable
  /// the mic button.
  Future<void> init() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      logger.warning(
        '${DateTime.now().toUtc()} Microphone permission denied',
      );
      _speechError = 'Microphone permission denied';
      _speechEnabled = false;
      notifyListeners();
      return;
    }
    final isValid = await _speechPipeline.isSpeechApiKeyValid();
    if (!isValid) {
      logger.warning(
        '${DateTime.now().toUtc()} Invalid speech API key'
      );
      _speechError = 'Invalid speech API key';
      _speechEnabled = false;
      notifyListeners();
      return;
    }
    _speechEnabled = hasPerm && isValid;
    notifyListeners();
  }

  /// Begin streaming microphone audio to the recognition service.
  Future<void> startListening() async {
    if (!_speechEnabled) return;

    // keep the screen awake while we are listening
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await WakelockPlus.enable();
    } catch (_) {}

    final session = await _speechPipeline.startRecognitionSession(
      _recorder,
      sourceLanguage: 'multi',
      diarize: true,
      utterances: true,
    );
    _recognitionSession = session;
    _recognitionSub?.cancel();
    _recognitionSub = session.resultStream.listen(_onRecognitionResult);
    _ampSub?.cancel();
    _ampSub = session.amplitudeStream.listen((value) {
      _amplitude = value;
      notifyListeners();
    });

    _isListening = true;
    notifyListeners();
  }

  /// Stop the microphone stream and send any pending words as a message.
  Future<void> stopListening() async {
    if (!_isListening) return;

    await _recognitionSession?.stop();
    _recognitionSession = null;
    await _recognitionSub?.cancel();
    _recognitionSub = null;
    await _ampSub?.cancel();
    _ampSub = null;

    // allow device to sleep again
    try {
      await WakelockPlus.disable();
    } catch (_) {}

    if (_partialWords.isNotEmpty) {
      // if there are any uncommitted words, add them as a final message
      _queueFinalResult(SpeechRecognitionResult(
        words: List.from(_partialWords),
        isFinal: true,
      ));
      _partialWords.clear();
    }

    _flushPendingFinalResults();

    _isListening = false;
    _amplitude = 0.0;
    notifyListeners();
  }

  bool get _hasPendingFinalResults =>
      _queuedMessages.isNotEmpty;

  String _pendingPreviewText() {
    return _queuedMessages.map((msg) => msg.original).join(' ').trim();
  }

  void _queueFinalResult(SpeechRecognitionResult result) {
    final recognizedText = result.wordsToText();
    logger.info(
      '${DateTime.now().toUtc()} QUEUEING FINAL RESULT: "$recognizedText" with ${result.words.length} words',
    );

    if (result.words.isNotEmpty) {
      final previousBySpeaker = {
        for (final queued in _queuedMessages) queued.speaker: queued,
      };

      final queuedAsMessages = wordsToMessages(
        _queuedMessagesAsChatMessages(),
        result.words,
      );

      _queuedMessages = queuedAsMessages
          .map((queuedMsg) {
            final previous = previousBySpeaker[queuedMsg.speaker];
            final previousTranslation =
                previous != null && previous.original == queuedMsg.original
                    ? previous.translation
                    : null;
            final processingStarted =
                previous != null && previous.original == queuedMsg.original
                    ? previous.processingStarted
                    : false;

            return QueuedChatMessage(
              original: queuedMsg.original,
              speaker: queuedMsg.speaker,
              translation: previousTranslation,
              processingStarted: processingStarted,
            );
          })
          .toList();

      for (final queued in _queuedMessages) {
        final previous = previousBySpeaker[queued.speaker];
        if (previous?.original != queued.original) {
          _maybeDefaultPreferred(queued.speaker);
          queued.processingStarted = true;
          unawaited(_translateAndSpeakQueued(queued));
        }
      }
      //_pendingFinalWords.addAll(result.words);
    }
  }

  void _schedulePendingFinalFlush() {
    _finalResultTimer?.cancel();

    if (_finalResultGroupingWindow == Duration.zero) {
      _flushPendingFinalResults();
      return;
    }

    _finalResultTimer = Timer(_finalResultGroupingWindow, () {
      _flushPendingFinalResults();
      notifyListeners();
    });
  }

  void _flushPendingFinalResults() {
    _finalResultTimer?.cancel();
    _finalResultTimer = null;

    if (!_hasPendingFinalResults) {
      return;
    }

    logger.info(
      '${DateTime.now().toUtc()} COMMITING FINAL RESULT: "${_pendingPreviewText()}" with ${_queuedMessages.length} messages',
    );

    // Could there be any pending messages that need to be flused?
    final messages = wordsToMessages(
      _queuedMessagesAsChatMessages(),
      [],
      isFinal: true,
    );

    if (messages.isEmpty) {
      return;
    }

    final queuedBySpeaker = {
      for (final queued in _queuedMessages) queued.speaker: queued,
    };

    _queuedMessages.clear();
    final nonWordOrSpace = RegExp(r'[\w]$', unicode: true);

    for (final message in messages) {
      logger.finer('Processing final message: "${message.original}" from speaker ${message.speaker}');
      final queued = queuedBySpeaker[message.speaker];
      if (queued != null) {
        message.translation = queued.translation;
      }
      if (nonWordOrSpace.hasMatch(message.original)) {
        logger.finest('Adding period to end of message: "${message.original}"');
        message.original = '${message.original}.';
      } else {
        logger.finest('No punctuation needed for message: "${message.original}"');
      }
      _chatMessages.add(message);
      _maybeDefaultPreferred(message.speaker);

      if (message.translation == null && (queued == null || !queued.processingStarted)) {
        unawaited(_translateAndSpeak(message));
      }
    }
  }

  void _onRecognitionResult(SpeechRecognitionResult result) {
    if (result.words.isNotEmpty) {
      logger.info(
        '${DateTime.now().toUtc()} RECOGNIZED: ${result.wordsToText()} - FINAL: ${result.isFinal}',
      );
      if (result.isFinal) {
        _queueFinalResult(result);
        _partialWords.clear();
      } else {
        _partialWords.clear();
        _partialWords.addAll(result.words); // add to partialWords
      }
      _schedulePendingFinalFlush();
    } else {
      logger.finest(
        '${DateTime.now().toUtc()} RECOGNIZED RESULT WITH NO WORDS - FINAL: ${result.isFinal}',
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    // make sure wakelock is turned off
    unawaited(WakelockPlus.disable().catchError((_) {}));
    _finalResultTimer?.cancel();
    unawaited(_recognitionSession?.stop() ?? Future.value());
    unawaited(_recognitionSub?.cancel() ?? Future.value());
    unawaited(_ampSub?.cancel() ?? Future.value());
    _recorder.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }
}
