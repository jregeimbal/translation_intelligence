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
import '../models/suggested_response.dart';
import '../services/app_language_catalog.dart';
import '../services/audio_playback_queue.dart';
import '../services/backend_api_client.dart';
import '../services/mic_activation_sound_player.dart';
import '../services/speech_pipeline.dart';
import '../services/speech_output_provider.dart';
import '../services/speech_stt_provider.dart';
import '../services/speech_translation_provider.dart';

final logger = Logger('GroupChatController'); // Create a logger with a name
const String _sessionResumeFailureMessage =
    'Listening stopped because the connection could not be resumed. Tap the mic to try again.';

/// Manages a live recognition session and exposes application-wide
/// state for group chat conversations.  Receives raw audio from the microphone
/// via `record` and sends it to speech recognition for transcription.
/// Translation/tts logic is unchanged from the previous version of the demo.
///
/// Notifies listeners when relevant properties change so individual widgets
/// can rebuild independently.
class GroupChatController extends ChangeNotifier {
  GroupChatController({
    String deepgramApiKey = '',
    BackendApiClient? backendApiClient,
    SpeechPipeline? speechPipeline,
    MicActivationSoundPlayer? micActivationSoundPlayer,
    Duration finalResultGroupingWindow = const Duration(seconds: 2),
    Duration audioPlaybackCompletionTimeout = const Duration(seconds: 30),
  }) : _speechPipeline =
           speechPipeline ??
           SpeechPipeline(
             deepgramApiKey: deepgramApiKey,
             backendApiClient: backendApiClient,
           ),
       _backendApiClient = backendApiClient,
       _micActivationSoundPlayer =
           micActivationSoundPlayer ?? DefaultMicActivationSoundPlayer(),
       _finalResultGroupingWindow = finalResultGroupingWindow,
       _audioPlaybackCompletionTimeout = audioPlaybackCompletionTimeout;
  final SpeechPipeline _speechPipeline;
  final BackendApiClient? _backendApiClient;
  final MicActivationSoundPlayer _micActivationSoundPlayer;
  Duration _finalResultGroupingWindow;
  final Duration _audioPlaybackCompletionTimeout;
  final AudioRecorder _recorder = AudioRecorder();
  AudioPlayer? _audioPlayer;
  final AudioPlaybackQueue _audioPlaybackQueue = AudioPlaybackQueue();
  bool _speechEnabled = false; // speech service + permission
  bool _isListening = false;
  bool _audioPlaybackEnabled = true;
  bool _hideTranslatedOriginalText = true;
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
  final Map<int, String> _optimisticMessageIdsBySpeaker = <int, String>{};
  // final List<SpeechRecognitionWord> _pendingFinalWords = [];
  List<QueuedChatMessage> _queuedMessages = [];
  final List<SpeechRecognitionWord> _partialWords = [];
  final List<ChatMessage> _chatMessages = [];
  List<InputDevice> _listeningDevices = const [];
  List<PlaybackDevice> _playbackDevices = const [];
  final StreamController<String> _listeningDeviceUpdateController =
      StreamController<String>.broadcast();
  final StreamController<SuggestedResponseEvent> _suggestedResponseController =
      StreamController<SuggestedResponseEvent>.broadcast();
  final Set<String> _requestedSuggestionMessageIds = <String>{};

  /// ID of speaker whose messages should be right-aligned in the UI.
  /// Null means no preference (all left).
  int? preferredSpeaker;

  set finalResultGroupingWindow(Duration value) {
    if (value != _finalResultGroupingWindow) {
      _finalResultGroupingWindow = value;
    }
  }

  bool get speechEnabled => _speechEnabled;
  bool get isListening => _isListening;
  bool get audioPlaybackEnabled => _audioPlaybackEnabled;
  bool get hideTranslatedOriginalText => _hideTranslatedOriginalText;
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
  Stream<SuggestedResponseEvent> get suggestedResponses =>
      _suggestedResponseController.stream;
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
            sourceLanguageCode: msg.sourceLanguageCode,
            targetLanguageCode: msg.targetLanguageCode,
          )..translation = msg.translation,
        )
        .toList();

    final mergedBySpeaker = <int?, List<SpeechRecognitionWord>>{};

    for (final word in words) {
      mergedBySpeaker[word.speaker] = [...?mergedBySpeaker[word.speaker], word];
    }

    for (var index = 0; index < newMessages.length; index++) {
      final newMsg = newMessages[index];
      final speakerWords = mergedBySpeaker.remove(newMsg.speaker);
      if (speakerWords == null || speakerWords.isEmpty) {
        continue;
      }

      final partialText = speakerWords
          .map((word) => word.word)
          .join(' ')
          .trim();
      if (partialText.isEmpty) {
        continue;
      }

      final separator = RegExp(r'[.!?]$').hasMatch(newMsg.original.trimRight())
          ? ' '
          : ', ';
      final updatedOriginal = '${newMsg.original}$separator$partialText';

      if (newMsg.groups.isNotEmpty) {
        final liveGroupId = '${newMsg.id}_g${newMsg.groups.length}';
        final updatedGroups = List<ChatMessageGroup>.from(newMsg.groups)
          ..add(ChatMessageGroup(id: liveGroupId, original: partialText));
        newMessages[index] = ChatMessage(
          updatedOriginal,
          speaker: newMsg.speaker,
          isFinal: isFinal,
          id: newMsg.id,
          timestamp: newMsg.timestamp,
          groups: updatedGroups,
          sourceLanguageCode: newMsg.sourceLanguageCode,
          targetLanguageCode: newMsg.targetLanguageCode,
        )..translation = newMsg.translation;
      } else {
        newMsg.original = updatedOriginal;
        newMsg.isFinal = isFinal;
      }
    }

    for (final entry in mergedBySpeaker.entries) {
      final partialText = entry.value.map((word) => word.word).join(' ').trim();
      if (partialText.isEmpty) {
        continue;
      }
      newMessages.add(
        ChatMessage(
          partialText,
          speaker: entry.key,
          isFinal: isFinal,
          id: _optimisticMessageIdForSpeaker(entry.key),
        ),
      );
    }

    logger.info('wordsToMessages newMessages: ${newMessages.toString()}');
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

  String _optimisticMessageIdForSpeaker(int? speaker) {
    final speakerKey = _speakerFlushKey(speaker);
    return _optimisticMessageIdsBySpeaker.putIfAbsent(
      speakerKey,
      () => 'msg_${DateTime.now().microsecondsSinceEpoch}_${speaker ?? 'u'}',
    );
  }

  void _clearOptimisticMessageIdForSpeaker(int? speaker) {
    _optimisticMessageIdsBySpeaker.remove(_speakerFlushKey(speaker));
  }

  void _clearAllOptimisticMessageIds() {
    _optimisticMessageIdsBySpeaker.clear();
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
    _clearAllOptimisticMessageIds();
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

  void setAudioPlaybackEnabled({required bool enabled}) {
    if (_audioPlaybackEnabled == enabled) return;
    _audioPlaybackEnabled = enabled;
    notifyListeners();
  }

  void setHideTranslatedOriginalText({required bool enabled}) {
    if (_hideTranslatedOriginalText == enabled) return;
    _hideTranslatedOriginalText = enabled;
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
        message = 'microphoneConnected';
        break;
      case 'devices_removed':
        message = 'microphoneDisconnected';
        break;
      case 'route_changed':
        message = 'audioRouteChanged';
        break;
      default:
        message = 'listeningDeviceListUpdated';
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

  /// Whether the current translation language is one the app localizes.
  bool get hasSupportedTargetLanguage {
    return AppLanguageCatalog.isSupported(_targetLanguage);
  }

  void setTargetLanguage(String lang) {
    if (lang != _targetLanguage) {
      _targetLanguage = lang;
      notifyListeners();
    }
  }

  static const List<String> supportedLanguages =
      AppLanguageCatalog.supportedLanguageCodes;

  Future<void> _translateAndSpeak(ChatMessage msg) async {
    // if this message is from the preferred speaker, we still translate
    // (so UI shows the english), but we don't play TTS audio.
    try {
      final translated = await _translateText(msg.original);
      if (translated == null) return;
      msg.translation = translated;
      notifyListeners();
      unawaited(_maybeRequestSuggestedResponse(msg));
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
      if (msg.groups.isEmpty) return;
      final translated = await _translateText(msg.groups.last.original);
      logger.finer(
        'Translation result for "${msg.groups.last.original}": $translated',
      );
      if (translated == null) return;
      _applyQueuedTranslationToCommittedMessage(msg, translated);
      notifyListeners();
      unawaited(_maybeRequestSuggestedResponseForQueued(msg));
      if (msg.speaker != null && msg.speaker == preferredSpeaker) {
        return;
      }
      if (!_audioPlaybackEnabled) {
        return;
      }
      final audio = await _synthesizeSpeech(translated, _targetLanguage);
      await _playAudio(audio);
    } catch (e) {
      logger.severe('queued translation/tts error: ${e.toString()}', e);
    }
  }

  Future<void> replayTranslation(ChatMessage message) async {
    final translation = _resolvedTranslationText(message);
    if (translation == null) return;

    try {
      final audio = await _synthesizeSpeech(translation, _targetLanguage);
      await _playAudio(audio);
    } catch (e) {
      logger.severe('translation replay error: ${e.toString()}', e);
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
      queued.translation = _joinQueuedGroupTranslations(queued.groups);
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
            sourceLanguageCode: committed.sourceLanguageCode,
            targetLanguageCode: committed.targetLanguageCode,
          )..translation = translationText.isEmpty ? null : translationText;
          unawaited(_maybeRequestSuggestedResponse(_chatMessages[i]));
        }
        break;
      }
    }
  }

  Future<void> _maybeRequestSuggestedResponse(ChatMessage message) async {
    if (!message.isFinal) {
      return;
    }

    final response = await _requestSuggestedResponse(
      messageId: message.id,
      speaker: message.speaker,
      messageText: message.original,
      messageTranslation: _resolvedTranslationText(message),
      sourceLanguageCode: message.sourceLanguageCode,
      targetLanguageCode: message.targetLanguageCode,
    );
    if (response == null || _suggestedResponseController.isClosed) {
      return;
    }

    _suggestedResponseController.add(
      SuggestedResponseEvent(messageId: message.id, response: response),
    );
  }

  Future<void> _maybeRequestSuggestedResponseForQueued(
    QueuedChatMessage message,
  ) async {
    final response = await _requestSuggestedResponse(
      messageId: message.id,
      speaker: message.speaker,
      messageText: message.original,
      messageTranslation: message.translation?.trim(),
      sourceLanguageCode: message.sourceLanguageCode,
      targetLanguageCode: message.targetLanguageCode,
    );
    if (response == null || _suggestedResponseController.isClosed) {
      return;
    }

    _suggestedResponseController.add(
      SuggestedResponseEvent(messageId: message.id, response: response),
    );
  }

  Future<SuggestedResponse?> _requestSuggestedResponse({
    required String messageId,
    required int? speaker,
    required String messageText,
    required String? messageTranslation,
    required String? sourceLanguageCode,
    required String? targetLanguageCode,
  }) async {
    if (!_canRequestSuggestedResponseForFields(
      messageId: messageId,
      speaker: speaker,
      translation: messageTranslation,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
      messageText: messageText,
    )) {
      return null;
    }

    if (!_requestedSuggestionMessageIds.add(messageId)) {
      return null;
    }

    final backendApiClient = _backendApiClient;
    if (backendApiClient == null) {
      return null;
    }

    return backendApiClient.suggestResponse(
      messageText: messageText,
      messageTranslation: messageTranslation!.trim(),
      sourceLanguageCode: sourceLanguageCode!,
      targetLanguageCode: targetLanguageCode!,
    );
  }

  bool _canRequestSuggestedResponseForFields({
    required String messageId,
    required int? speaker,
    required String? translation,
    required String? sourceLanguageCode,
    required String? targetLanguageCode,
    required String messageText,
  }) {
    if (messageId.isEmpty || messageText.trim().isEmpty) {
      return false;
    }
    if (preferredSpeaker == null || speaker == null) {
      return false;
    }
    if (speaker == preferredSpeaker) {
      return false;
    }
    if (translation == null || translation.trim().isEmpty) {
      return false;
    }
    if (sourceLanguageCode == null || sourceLanguageCode.isEmpty) {
      return false;
    }
    if (targetLanguageCode == null || targetLanguageCode.isEmpty) {
      return false;
    }
    return true;
  }

  String? _currentSuggestionSourceLanguageCode() {
    final resolvedLanguageCode = _activeSessionResolvedLanguageCode?.trim();
    if (resolvedLanguageCode != null && resolvedLanguageCode.isNotEmpty) {
      return resolvedLanguageCode;
    }

    final sourceLanguage = _activeSessionSourceLanguage?.trim();
    if (sourceLanguage == null || sourceLanguage.isEmpty) {
      return null;
    }
    if (sourceLanguage == 'multi') {
      return null;
    }
    return sourceLanguage;
  }

  Future<String?> _translateText(String text) async {
    final sourceLanguage = _activeSessionSourceLanguage;

    return _speechPipeline.translateText(
      text: text,
      targetLanguage: _targetLanguage,
      sourceLanguage: sourceLanguage == null || sourceLanguage == 'multi'
          ? null
          : sourceLanguage,
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
      _speechError = 'microphonePermissionDenied';
      _speechEnabled = false;
      notifyListeners();
      return;
    }
    final isValid = await _speechPipeline.isSpeechApiKeyValid();
    if (!isValid) {
      logger.warning('${DateTime.now().toUtc()} Invalid speech API key');
      _speechError = 'invalidSpeechApiKey';
      _speechEnabled = false;
      notifyListeners();
      return;
    }
    _speechEnabled = hasPerm && isValid;
    _speechError = '';
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

    final SpeechRecognitionSession session;
    try {
      session = await _speechPipeline.startRecognitionSession(
        _recorder,
        sourceLanguage:
            _speechPipeline.sttProvider == SpeechSttProvider.deepgram
            ? _speechPipeline.deepgramRecognitionLanguage
            : 'multi',
        diarize: true,
        utterances: true,
      );
    } catch (_) {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      rethrow;
    }
    _recognitionSession = session;
    _activeSessionSampleRate = session.sampleRate;
    _activeSessionSttProvider = session.sttProvider;
    _activeSessionSourceLanguage = session.sourceLanguage;
    _activeSessionResolvedLanguageCode = session.resolvedLanguageCode;
    _activeSessionListeningDeviceId = session.listeningDeviceId;
    _activeSessionStartedAt = session.startedAt;
    _recognitionSub?.cancel();
    _recognitionSub = session.resultStream.listen(
      _onRecognitionResult,
      onError: (Object error, StackTrace stackTrace) {
        unawaited(_handleRecognitionSessionFailure(error, stackTrace));
      },
    );
    _ampSub?.cancel();
    _ampSub = session.amplitudeStream.listen((value) {
      _amplitude = value;
      notifyListeners();
    });

    _isListening = true;
    _speechError = '';
    notifyListeners();
    unawaited(_micActivationSoundPlayer.play());
  }

  /// Stop the microphone stream and send any pending words as a message.
  Future<void> stopListening() async {
    await _stopListeningInternal(clearSpeechError: true);
  }

  Future<void> _stopListeningInternal({required bool clearSpeechError}) async {
    if (!_isListening) return;

    await _recognitionSession?.stop();
    _recognitionSession = null;
    _activeSessionSampleRate = null;
    _activeSessionSttProvider = null;
    _activeSessionSourceLanguage = null;
    _activeSessionResolvedLanguageCode = null;
    _activeSessionListeningDeviceId = null;
    _activeSessionStartedAt = null;
    final recognitionSub = _recognitionSub;
    _recognitionSub = null;
    unawaited(recognitionSub?.cancel());
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
      _clearAllOptimisticMessageIds();
    }

    _flushPendingFinalResults();

    _isListening = false;
    _amplitude = 0.0;
    if (clearSpeechError) {
      _speechError = '';
    }
    notifyListeners();
  }

  Future<void> _handleRecognitionSessionFailure(
    Object error,
    StackTrace stackTrace,
  ) async {
    logger.warning('speech recognition session failed', error, stackTrace);
    if (!_isListening) {
      return;
    }
    _speechError = _sessionResumeFailureMessage;
    await _stopListeningInternal(clearSpeechError: false);
  }

  bool get _hasPendingFinalResults => _queuedMessages.isNotEmpty;

  int _speakerFlushKey(int? speaker) => speaker ?? -1;

  String _pendingPreviewText() {
    return _queuedMessages.map((msg) => msg.original).join(' ').trim();
  }

  String _joinQueuedGroupOriginals(List<ChatMessageGroup> groups) {
    final buffer = StringBuffer();
    for (var index = 0; index < groups.length; index++) {
      final text = groups[index].original.trim();
      if (text.isEmpty) {
        continue;
      }
      if (buffer.isNotEmpty) {
        final previousText = groups[index - 1].original.trimRight();
        buffer.write(RegExp(r'[.!?]$').hasMatch(previousText) ? ' ' : ', ');
      }
      buffer.write(text);
    }
    return buffer.toString();
  }

  String? _joinQueuedGroupTranslations(List<ChatMessageGroup> groups) {
    final translation = groups
        .map((group) => group.translation?.trim())
        .whereType<String>()
        .where((text) => text.isNotEmpty)
        .join(' ')
        .trim();
    return translation.isEmpty ? null : translation;
  }

  bool _shouldReplaceLatestQueuedGroup(
    ChatMessageGroup previousGroup,
    String nextOriginal,
  ) {
    final previous = previousGroup.original.trim().replaceFirst(
      RegExp(r'[,.!?\s]+$'),
      '',
    );
    final next = nextOriginal.trim();
    if (previous.isEmpty || next.isEmpty) {
      return false;
    }
    if (next == previous) {
      return false;
    }
    return next.startsWith('$previous ') || next.startsWith('$previous,');
  }

  void _onRecognitionResult(SpeechRecognitionResult result) {
    final shouldAdvanceToQueue = result.isFinal || result.speechFinal;

    if (result.words.isNotEmpty) {
      _maybeDefaultPreferred(result.words.first.speaker);
      logger.info(
        '${DateTime.now().toUtc()} RECOGNIZED: ${result.wordsToText()} - FINAL: ${result.isFinal} - SPEECH_FINAL: ${result.speechFinal}',
      );
      if (shouldAdvanceToQueue) {
        _queueFinalResult(result);
        _partialWords.clear();
        for (final word in result.words) {
          _clearOptimisticMessageIdForSpeaker(word.speaker);
        }
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
      if (shouldAdvanceToQueue && _partialWords.isNotEmpty) {
        final bufferedResult = SpeechRecognitionResult(
          isFinal: false,
          speechFinal: true,
          words: List<SpeechRecognitionWord>.from(_partialWords),
        );
        _queueFinalResult(bufferedResult);
        for (final word in bufferedResult.words) {
          _clearOptimisticMessageIdForSpeaker(word.speaker);
        }
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
      final latestOriginalBySpeaker = <int?, String>{};
      for (final word in result.words) {
        final speaker = word.speaker;
        latestOriginalBySpeaker.update(
          speaker,
          (value) => '$value ${word.word}',
          ifAbsent: () => word.word,
        );
      }

      final previousBySpeaker = {
        for (final queued in _queuedMessages) queued.speaker: queued,
      };

      QueuedChatMessage buildQueuedMessage(int? speaker, String nextOriginal) {
        final previous = previousBySpeaker[speaker];
        final processingStarted =
            previous != null && previous.original == nextOriginal
            ? previous.processingStarted
            : false;
        final queuedId =
            previous?.id ?? _optimisticMessageIdForSpeaker(speaker);
        _clearOptimisticMessageIdForSpeaker(speaker);

        final nextGroups = previous == null
            ? <ChatMessageGroup>[]
            : List<ChatMessageGroup>.from(previous.groups);

        if (nextGroups.isEmpty) {
          nextGroups.add(
            ChatMessageGroup(id: '${queuedId}_g0', original: nextOriginal),
          );
        } else if (_shouldReplaceLatestQueuedGroup(
          nextGroups.last,
          nextOriginal,
        )) {
          final lastIndex = nextGroups.length - 1;
          final lastGroup = nextGroups[lastIndex];
          nextGroups[lastIndex] = ChatMessageGroup(
            id: lastGroup.id,
            original: nextOriginal,
            translation: lastGroup.translation,
          );
        } else if (nextGroups.last.original != nextOriginal) {
          nextGroups.add(
            ChatMessageGroup(
              id: '${queuedId}_g${nextGroups.length}',
              original: nextOriginal,
            ),
          );
        }

        return QueuedChatMessage(
          id: queuedId,
          original: _joinQueuedGroupOriginals(nextGroups),
          speaker: speaker,
          translation: _joinQueuedGroupTranslations(nextGroups),
          processingStarted: processingStarted,
          sourceLanguageCode:
              previous?.sourceLanguageCode ??
              _currentSuggestionSourceLanguageCode(),
          targetLanguageCode: previous?.targetLanguageCode ?? _targetLanguage,
          groups: nextGroups,
        );
      }

      final nextQueuedMessages = <QueuedChatMessage>[];
      final updatedSpeakers = <int?>{};

      for (final queued in _queuedMessages) {
        if (latestOriginalBySpeaker.containsKey(queued.speaker)) {
          nextQueuedMessages.add(
            buildQueuedMessage(
              queued.speaker,
              latestOriginalBySpeaker[queued.speaker]!,
            ),
          );
          updatedSpeakers.add(queued.speaker);
        } else {
          nextQueuedMessages.add(queued);
        }
      }

      for (final entry in latestOriginalBySpeaker.entries) {
        if (updatedSpeakers.contains(entry.key)) continue;
        nextQueuedMessages.add(buildQueuedMessage(entry.key, entry.value));
      }

      _queuedMessages = nextQueuedMessages;

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
        sourceLanguageCode: queued.sourceLanguageCode,
        targetLanguageCode: queued.targetLanguageCode,
      )..translation = finalTranslation.isEmpty ? null : finalTranslation;

      _chatMessages.add(finalizedMessage);
      _maybeDefaultPreferred(finalizedMessage.speaker);

      if (finalizedMessage.translation != null) {
        unawaited(_maybeRequestSuggestedResponse(finalizedMessage));
      }

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
    unawaited(_suggestedResponseController.close());
    unawaited(_micActivationSoundPlayer.dispose());
    _recorder.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }
}
