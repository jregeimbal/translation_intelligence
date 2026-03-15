import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/chat_message.dart';
import '../models/playback_device.dart';
import '../models/queued_chat_message.dart';
import '../services/audio_playback_queue.dart';
import '../services/speech_pipeline.dart';
import '../services/speech_output_provider.dart';
import '../services/speech_stt_provider.dart';
import '../services/speech_translation_provider.dart';

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
  bool _audioPlaybackEnabled = true;
  String _speechError = '';
  double _amplitude =
      0.0; // normalized 0.0‑1.0 (mapped from dB-truncated values)
  StreamSubscription<SpeechRecognitionResult>? _recognitionSub;
  StreamSubscription<double>? _ampSub;
  StreamSubscription<dynamic>? _listeningDeviceChangeSub;
  SpeechRecognitionSession? _recognitionSession;
  int? _activeSessionSampleRate;
  SpeechSttProvider? _activeSessionSttProvider;
  String? _activeSessionSourceLanguage;
  String? _activeSessionResolvedLanguageCode;
  String? _activeSessionListeningDeviceId;
  DateTime? _activeSessionStartedAt;
  final Map<int, Timer> _finalResultTimersBySpeaker = <int, Timer>{};
  // final List<SpeechRecognitionWord> _pendingFinalWords = [];
  List<QueuedChatMessage> _queuedMessages = [];
  final List<SpeechRecognitionWord> _partialWords = [];
  final List<ChatMessage> _chatMessages = [];
  List<InputDevice> _listeningDevices = const [];
  List<PlaybackDevice> _playbackDevices = const [];
  final StreamController<String> _listeningDeviceUpdateController =
      StreamController<String>.broadcast();

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
  bool get audioPlaybackEnabled => _audioPlaybackEnabled;
  String get speechError => _speechError;
  double get amplitude => _amplitude;
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  SpeechOutputProvider get outputProvider => _speechPipeline.outputProvider;
  SpeechSttProvider get sttProvider => _speechPipeline.sttProvider;
  SpeechTranslationProvider get translationProvider =>
      _speechPipeline.translationProvider;
  String get deepgramRecognitionModel =>
      _speechPipeline.deepgramRecognitionModel;
  String get deepgramRecognitionLanguage =>
      _speechPipeline.deepgramRecognitionLanguage;
  String get speechToTextRecognitionLocale =>
      _speechPipeline.speechToTextRecognitionLocale;
  List<String> get deepgramRecognitionModels =>
      _speechPipeline.deepgramRecognitionModels;
  Map<String, String> get deepgramRecognitionLanguages =>
      _speechPipeline.deepgramRecognitionLanguages;
  Map<String, String> get speechToTextRecognitionLocales =>
      _speechPipeline.speechToTextRecognitionLocales;
  List<InputDevice> get listeningDevices =>
      List<InputDevice>.unmodifiable(_listeningDevices);
  String? get listeningDeviceId => _speechPipeline.listeningDeviceId;
  List<PlaybackDevice> get playbackDevices =>
      List<PlaybackDevice>.unmodifiable(_playbackDevices);
  String? get playbackDeviceId => _speechPipeline.playbackDeviceId;
  Stream<String> get listeningDeviceUpdates =>
      _listeningDeviceUpdateController.stream;
  int? get activeSessionSampleRate => _activeSessionSampleRate;
  SpeechSttProvider? get activeSessionSttProvider => _activeSessionSttProvider;
  String? get activeSessionSourceLanguage => _activeSessionSourceLanguage;
  String? get activeSessionResolvedLanguageCode =>
      _activeSessionResolvedLanguageCode;
  String? get activeSessionListeningDeviceId => _activeSessionListeningDeviceId;
  DateTime? get activeSessionStartedAt => _activeSessionStartedAt;

  List<ChatMessage> wordsToMessages(
    List<ChatMessage> oldMessages,
    Iterable<SpeechRecognitionWord> words, {
    bool isFinal = false,
  }) {
    final newMessages = oldMessages
        .map(
          (msg) => ChatMessage(
            msg.original,
            speaker: msg.speaker,
            isFinal: msg.isFinal,
            id: msg.id,
            timestamp: msg.timestamp,
            groups: msg.groups,
          )..translation = msg.translation,
        )
        .toList();

    Map<int, List<SpeechRecognitionWord>> mergedBySpeaker = {};

    // Group words by speaker, using -1 for unknown speakers
    for (var word in words) {
      final key = word.speaker ?? -1; // Use -1 as the key for unknown speakers
      mergedBySpeaker[key] = [...?mergedBySpeaker[key], word];
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
          final existingMsg = newMessages.firstWhere(
            (m) => m.speaker == word.speaker,
          );
          existingMsg.original = '${existingMsg.original} ${word.word}';
        } else {
          // If there's no existing message for this speaker, create a new one
          newMessages.add(
            ChatMessage(word.word, speaker: word.speaker, isFinal: isFinal),
          );
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

  void setAudioPlaybackEnabled(bool enabled) {
    if (_audioPlaybackEnabled == enabled) return;
    _audioPlaybackEnabled = enabled;
    notifyListeners();
  }

  void setDeepgramRecognitionModel(String model) {
    if (_speechPipeline.deepgramRecognitionModel == model) return;
    _speechPipeline.setDeepgramRecognitionModel(model);
    notifyListeners();
  }

  void setDeepgramRecognitionLanguage(String language) {
    if (_speechPipeline.deepgramRecognitionLanguage == language) return;
    _speechPipeline.setDeepgramRecognitionLanguage(language);
    notifyListeners();
  }

  void setSpeechToTextRecognitionLocale(String locale) {
    if (_speechPipeline.speechToTextRecognitionLocale == locale) return;
    _speechPipeline.setSpeechToTextRecognitionLocale(locale);
    notifyListeners();
  }

  Future<void> refreshSpeechToTextRecognitionLocales() async {
    await _speechPipeline.refreshSpeechToTextRecognitionLocales();
    notifyListeners();
  }

  Future<void> refreshListeningDevices() async {
    try {
      _listeningDevices = await _recorder.listInputDevices();
    } catch (_) {
      _listeningDevices = const [];
    }

    final selectedId = _speechPipeline.listeningDeviceId;
    if (selectedId != null &&
        !_listeningDevices.any((device) => device.id == selectedId)) {
      _speechPipeline.setListeningDeviceId(null);
    }
    notifyListeners();
  }

  Future<void> refreshPlaybackDevices() async {
    final devices = await _speechPipeline.listPlaybackDevices();
    _playbackDevices = devices;

    final selectedId = _speechPipeline.playbackDeviceId;
    final currentRouteId = await _speechPipeline.getCurrentPlaybackDeviceId();

    if (selectedId == null) {
      _speechPipeline.setPlaybackDeviceIdLocally(currentRouteId);
    } else if (!_playbackDevices.any((device) => device.id == selectedId)) {
      _speechPipeline.setPlaybackDeviceIdLocally(currentRouteId);
    }

    notifyListeners();
  }

  Future<void> _handleListeningDeviceRouteChange(dynamic event) async {
    final eventName = event is Map
        ? (event['event']?.toString() ?? 'route_changed')
        : 'route_changed';
    final previousSignature = _listeningDevices
        .map((device) => '${device.id}|${device.label}')
        .join(';');
    final previousSelectedId = _speechPipeline.listeningDeviceId;
    final previousPlaybackSignature = _playbackDevices
        .map((device) => '${device.id}|${device.name}|${device.type}')
        .join(';');
    final previousPlaybackSelectedId = _speechPipeline.playbackDeviceId;

    await refreshListeningDevices();
    await refreshPlaybackDevices();

    final updatedSignature = _listeningDevices
        .map((device) => '${device.id}|${device.label}')
        .join(';');
    final updatedSelectedId = _speechPipeline.listeningDeviceId;
    final updatedPlaybackSignature = _playbackDevices
        .map((device) => '${device.id}|${device.name}|${device.type}')
        .join(';');
    final updatedPlaybackSelectedId = _speechPipeline.playbackDeviceId;

    if (previousSignature == updatedSignature &&
        previousSelectedId == updatedSelectedId &&
        previousPlaybackSignature == updatedPlaybackSignature &&
        previousPlaybackSelectedId == updatedPlaybackSelectedId) {
      return;
    }

    String message;
    switch (eventName) {
      case 'devices_added':
        message = 'Microphone connected';
        break;
      case 'devices_removed':
        message = 'Microphone disconnected';
        break;
      case 'route_changed':
        message = 'Audio route changed';
        break;
      default:
        message = 'Listening device list updated';
    }

    if (updatedSelectedId != null) {
      final selected = _listeningDevices
          .where((device) => device.id == updatedSelectedId)
          .cast<InputDevice?>()
          .firstWhere((_) => true, orElse: () => null);
      if (selected != null) {
        final label = selected.label.isNotEmpty ? selected.label : selected.id;
        message = '$message: $label';
      }
    }

    if (!_listeningDeviceUpdateController.isClosed) {
      _listeningDeviceUpdateController.add(message);
    }
  }

  void setListeningDeviceId(String? deviceId) {
    if (_speechPipeline.listeningDeviceId == deviceId) return;
    _speechPipeline.setListeningDeviceId(deviceId);
    notifyListeners();
  }

  Future<bool> setPlaybackDeviceId(String? deviceId) async {
    final applied = await _speechPipeline.setPlaybackDeviceId(deviceId);
    await refreshPlaybackDevices();
    return applied;
  }

  // translation + TTS helpers ------------------------------------------------

  // Desired language code for translation (Google Translate format).
  // Defaults to English; the UI allows the user to override this.
  String _targetLanguage = 'en';
  String get targetLanguage => _targetLanguage;

  /// Friendly name for the current translation language, falling back to
  /// the raw code if not found in the map.
  String get targetLanguageName {
    final entry = supportedLanguages.entries.firstWhere(
      (e) => e.value == _targetLanguage,
      orElse: () => MapEntry(_targetLanguage, _targetLanguage),
    );
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
      if (!_audioPlaybackEnabled) {
        return;
      }
      final audio = await _synthesizeSpeech(translated, _targetLanguage);
      await _playAudio(audio);
    } catch (e) {
      logger.severe('translation/tts error', e);
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
      if (!_audioPlaybackEnabled) {
        return;
      }
      final audio = await _synthesizeSpeech(translated, _targetLanguage);
      await _playAudio(audio);
    } catch (e) {
      logger.severe('queued translation/tts error', e);
    }
  }

  void _applyQueuedTranslationToCommittedMessage(
    QueuedChatMessage queued,
    String translation,
  ) {
    if (queued.groups.isNotEmpty) {
      final lastIndex = queued.groups.length - 1;
      final currentGroup = queued.groups[lastIndex];
      queued.groups[lastIndex] = ChatMessageGroup(
        id: currentGroup.id,
        original: currentGroup.original,
        translation: translation,
      );
    }

    for (var i = _chatMessages.length - 1; i >= 0; i--) {
      final committed = _chatMessages[i];
      if (committed.speaker != queued.speaker) {
        continue;
      }

      if (committed.id == queued.id) {
        final committedGroups = List<ChatMessageGroup>.from(committed.groups);
        if (committedGroups.isNotEmpty) {
          final committedLastIndex = committedGroups.length - 1;
          final committedGroup = committedGroups[committedLastIndex];
          committedGroups[committedLastIndex] = ChatMessageGroup(
            id: committedGroup.id,
            original: committedGroup.original,
            translation: translation,
          );
          final translationText = committedGroups
              .map((group) => group.translation)
              .whereType<String>()
              .join(' ')
              .trim();
          _chatMessages[i] = ChatMessage(
            committed.original,
            speaker: committed.speaker,
            isFinal: committed.isFinal,
            id: committed.id,
            timestamp: committed.timestamp,
            groups: committedGroups,
          )..translation = translationText.isEmpty ? null : translationText;
        }
        break;
      }
    }
  }

  Future<String?> _translateText(String text) async {
    return _speechPipeline.translateText(
      text: text,
      targetLanguage: _targetLanguage,
      sourceLanguage:
          'es', // for testing, we can hardcode Spanish as the source to verify translation is working https://developers.google.com/ml-kit/language/translation/translation-language-support
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
        logger.finest('${DateTime.now().toUtc()} Audio playback started');
      } catch (e) {
        logger.severe('audio playback error $e', e);
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
      logger.warning('${DateTime.now().toUtc()} Microphone permission denied');
      _speechError = 'Microphone permission denied';
      _speechEnabled = false;
      notifyListeners();
      return;
    }
    final isValid = await _speechPipeline.isSpeechApiKeyValid();
    if (!isValid) {
      logger.warning('${DateTime.now().toUtc()} Invalid speech API key');
      _speechError = 'Invalid speech API key';
      _speechEnabled = false;
      notifyListeners();
      return;
    }
    _speechEnabled = hasPerm && isValid;
    await refreshListeningDevices();
    await refreshPlaybackDevices();
    _listeningDeviceChangeSub ??= _speechPipeline
        .listeningDeviceRouteChanges()
        .listen((event) {
          unawaited(_handleListeningDeviceRouteChange(event));
        }, onError: (_) {});
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
      sourceLanguage: _speechPipeline.sttProvider == SpeechSttProvider.deepgram
          ? _speechPipeline.deepgramRecognitionLanguage
          : 'multi',
      diarize: true,
      utterances: true,
    );
    _recognitionSession = session;
    _activeSessionSampleRate = session.sampleRate;
    _activeSessionSttProvider = session.sttProvider;
    _activeSessionSourceLanguage = session.sourceLanguage;
    _activeSessionResolvedLanguageCode = session.resolvedLanguageCode;
    _activeSessionListeningDeviceId = session.listeningDeviceId;
    _activeSessionStartedAt = session.startedAt;
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
    _activeSessionSampleRate = null;
    _activeSessionSttProvider = null;
    _activeSessionSourceLanguage = null;
    _activeSessionResolvedLanguageCode = null;
    _activeSessionListeningDeviceId = null;
    _activeSessionStartedAt = null;
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
      _queueFinalResult(
        SpeechRecognitionResult(words: List.from(_partialWords), isFinal: true),
      );
      _partialWords.clear();
    }

    _flushPendingFinalResults();

    _isListening = false;
    _amplitude = 0.0;
    notifyListeners();
  }

  bool get _hasPendingFinalResults => _queuedMessages.isNotEmpty;

  int _speakerFlushKey(int? speaker) => speaker ?? -1;

  String _pendingPreviewText() {
    return _queuedMessages.map((msg) => msg.original).join(' ').trim();
  }

  String _extractQueuedGroupText(
    String? previousOriginal,
    String nextOriginal,
  ) {
    final prev = (previousOriginal ?? '').trim();
    final next = nextOriginal.trim();
    if (prev.isEmpty || next.isEmpty || !next.startsWith(prev)) {
      return next;
    }
    final suffix = next
        .substring(prev.length)
        .replaceFirst(RegExp(r'^[,\s]+'), '');
    return suffix.isEmpty ? next : suffix;
  }

  void _onRecognitionResult(SpeechRecognitionResult result) {
    final shouldAdvanceToQueue = result.isFinal || result.speechFinal;

    if (result.words.isNotEmpty) {
      logger.info(
        '${DateTime.now().toUtc()} RECOGNIZED: ${result.wordsToText()} - FINAL: ${result.isFinal} - SPEECH_FINAL: ${result.speechFinal}',
      );
      if (shouldAdvanceToQueue) {
        _queueFinalResult(result);
        _partialWords.clear();
        _schedulePendingFinalFlush(result.words.map((word) => word.speaker));
      } else {
        _partialWords.clear();
        _partialWords.addAll(result.words); // add to partialWords
        _schedulePendingFinalFlush(result.words.map((word) => word.speaker));
      }
    } else {
      logger.finest(
        '${DateTime.now().toUtc()} RECOGNIZED RESULT WITH NO WORDS - FINAL: ${result.isFinal} - SPEECH_FINAL: ${result.speechFinal}',
      );
      if (result.speechFinal && _partialWords.isNotEmpty) {
        final bufferedResult = SpeechRecognitionResult(
          isFinal: false,
          speechFinal: true,
          words: List<SpeechRecognitionWord>.from(_partialWords),
        );
        _queueFinalResult(bufferedResult);
        _partialWords.clear();
        _schedulePendingFinalFlush(
          bufferedResult.words.map((word) => word.speaker),
        );
      }
    }
    notifyListeners();
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

      _queuedMessages = queuedAsMessages.map((queuedMsg) {
        final previous = previousBySpeaker[queuedMsg.speaker];
        final previousTranslation = previous?.translation;
        final previousOriginal = previous?.original;
        final processingStarted =
            previous != null && previous.original == queuedMsg.original
            ? previous.processingStarted
            : false;

        final previousGroups = previous == null
            ? const <ChatMessageGroup>[]
            : List<ChatMessageGroup>.from(previous.groups);
        final nextGroupIndex = previousGroups.length;
        final nextGroups = <ChatMessageGroup>[
          ...previousGroups,
          if (previousOriginal != queuedMsg.original)
            ChatMessageGroup(
              id: '${queuedMsg.id}_g$nextGroupIndex',
              original: _extractQueuedGroupText(
                previousOriginal,
                queuedMsg.original,
              ),
              translation: null,
            ),
        ];

        return QueuedChatMessage(
          id: previous?.id ?? queuedMsg.id,
          original: queuedMsg.original,
          speaker: queuedMsg.speaker,
          translation: previousTranslation,
          processingStarted: processingStarted,
          groups: nextGroups,
        );
      }).toList();

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

  void _schedulePendingFinalFlush(Iterable<int?> speakers) {
    final speakerKeys = speakers.map(_speakerFlushKey).toSet();
    if (speakerKeys.isEmpty) {
      return;
    }

    if (_finalResultGroupingWindow == Duration.zero) {
      for (final speakerKey in speakerKeys) {
        _flushPendingFinalResultsForSpeaker(speakerKey);
      }
      notifyListeners();
      return;
    }

    for (final speakerKey in speakerKeys) {
      _finalResultTimersBySpeaker[speakerKey]?.cancel();
      _finalResultTimersBySpeaker[speakerKey] = Timer(
        _finalResultGroupingWindow,
        () {
          _flushPendingFinalResultsForSpeaker(speakerKey);
          notifyListeners();
        },
      );
    }
  }

  void _flushPendingFinalResultsForSpeaker(int speakerKey) {
    _finalResultTimersBySpeaker.remove(speakerKey)?.cancel();

    final speaker = speakerKey == -1 ? null : speakerKey;
    final queuedBySpeaker = _queuedMessages
        .where((queued) => queued.speaker == speaker)
        .toList(growable: false);

    if (queuedBySpeaker.isEmpty) {
      return;
    }

    _queuedMessages.removeWhere((queued) => queued.speaker == speaker);

    logger.info(
      '${DateTime.now().toUtc()} COMMITING FINAL RESULT FOR SPEAKER $speaker: '
      '"${queuedBySpeaker.map((msg) => msg.original).join(' ')}" '
      'with ${queuedBySpeaker.length} messages',
    );

    final nonWordOrSpace = RegExp(r'[\w]$', unicode: true);

    for (final queued in queuedBySpeaker) {
      var finalOriginal = queued.original;
      if (nonWordOrSpace.hasMatch(finalOriginal)) {
        finalOriginal = '$finalOriginal.';
      }

      final groups = List<ChatMessageGroup>.from(queued.groups);
      if (groups.isNotEmpty) {
        final last = groups.last;
        final finalizedLastOriginal = nonWordOrSpace.hasMatch(last.original)
            ? '${last.original}.'
            : last.original;
        groups[groups.length - 1] = ChatMessageGroup(
          id: last.id,
          original: finalizedLastOriginal,
          translation: last.translation,
        );
      }
      final finalTranslation = groups
          .map((group) => group.translation)
          .whereType<String>()
          .join(' ')
          .trim();
      final finalizedMessage = ChatMessage(
        finalOriginal,
        speaker: queued.speaker,
        isFinal: true,
        id: queued.id,
        groups: groups,
      )..translation = finalTranslation.isEmpty ? null : finalTranslation;

      _chatMessages.add(finalizedMessage);
      _maybeDefaultPreferred(finalizedMessage.speaker);

      if (finalizedMessage.translation == null && !queued.processingStarted) {
        unawaited(_translateAndSpeak(finalizedMessage));
      }
    }
  }

  void _flushPendingFinalResults() {
    for (final timer in _finalResultTimersBySpeaker.values) {
      timer.cancel();
    }
    _finalResultTimersBySpeaker.clear();

    if (!_hasPendingFinalResults) {
      return;
    }

    logger.info(
      '${DateTime.now().toUtc()} COMMITING FINAL RESULT: "${_pendingPreviewText()}" with ${_queuedMessages.length} messages',
    );

    final speakersInQueue = _queuedMessages
        .map((queued) => _speakerFlushKey(queued.speaker))
        .toSet();

    for (final speakerKey in speakersInQueue) {
      _flushPendingFinalResultsForSpeaker(speakerKey);
    }
  }

  @override
  void dispose() {
    // make sure wakelock is turned off
    unawaited(WakelockPlus.disable().catchError((_) {}));
    for (final timer in _finalResultTimersBySpeaker.values) {
      timer.cancel();
    }
    _finalResultTimersBySpeaker.clear();
    unawaited(_recognitionSession?.stop() ?? Future.value());
    unawaited(_recognitionSub?.cancel() ?? Future.value());
    unawaited(_ampSub?.cancel() ?? Future.value());
    unawaited(_listeningDeviceChangeSub?.cancel() ?? Future.value());
    unawaited(_listeningDeviceUpdateController.close());
    _recorder.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }
}
