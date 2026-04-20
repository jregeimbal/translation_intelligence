import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/queued_chat_message.dart';
import '../models/speech_recognition_models.dart';

class MessageProcessorController extends ChangeNotifier {

  MessageProcessorController({
    Duration finalResultGroupingWindow = const Duration(seconds: 2),
  }) : _finalResultGroupingWindow = finalResultGroupingWindow;
  final Duration _finalResultGroupingWindow;

  final Map<int, Timer> _finalResultTimersBySpeaker = <int, Timer>{};
  final Map<int, String> _optimisticMessageIdsBySpeaker = <int, String>{};
  final List<QueuedChatMessage> _queuedMessages = [];
  final List<SpeechRecognitionWord> _partialWords = [];
  final List<ChatMessage> _chatMessages = [];

  int? _preferredSpeaker;

  int? get preferredSpeaker => _preferredSpeaker;

  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  List<QueuedChatMessage> get queuedMessages =>
      List.unmodifiable(_queuedMessages);

  void setPreferredSpeaker(int? speaker) {
    _preferredSpeaker = speaker;
    notifyListeners();
  }

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
    if (_preferredSpeaker == null && speaker != null) {
      setPreferredSpeaker(speaker);
    }
  }

  Set<int> get speakers =>
      _chatMessages.map((m) => m.speaker).whereType<int>().toSet();

  void clearMessages() {
    _chatMessages.clear();
    _clearAllOptimisticMessageIds();
    notifyListeners();
  }

  void _queueFinalResult(SpeechRecognitionResult result) {
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
          sourceLanguageCode: previous?.sourceLanguageCode,
          targetLanguageCode: previous?.targetLanguageCode ?? 'en',
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

      _queuedMessages.clear();
      _queuedMessages.addAll(nextQueuedMessages);

      for (final queued in _queuedMessages) {
        final previous = previousBySpeaker[queued.speaker];
        if (previous?.original != queued.original) {
          _maybeDefaultPreferred(queued.speaker);
          queued.processingStarted = true;
        }
      }
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

      if (finalizedMessage.translation == null && !queued.processingStarted) {
        _maybeDefaultPreferred(finalizedMessage.speaker);
      }
    }
  }

  void _flushPendingFinalResults() {
    for (final timer in _finalResultTimersBySpeaker.values) {
      timer.cancel();
    }
    _finalResultTimersBySpeaker.clear();

    if (_queuedMessages.isEmpty) {
      return;
    }

    final speakersInQueue = _queuedMessages
        .map((queued) => _speakerFlushKey(queued.speaker))
        .toSet();

    for (final speakerKey in speakersInQueue) {
      _flushPendingFinalResultsForSpeaker(speakerKey);
    }
  }

  void onRecognitionResult(SpeechRecognitionResult result) {
    final shouldAdvanceToQueue = result.isFinal || result.speechFinal;

    if (result.words.isNotEmpty) {
      _maybeDefaultPreferred(result.words.first.speaker);

      if (shouldAdvanceToQueue) {
        _queueFinalResult(result);
        _partialWords.clear();
        for (final word in result.words) {
          _clearOptimisticMessageIdForSpeaker(word.speaker);
        }
        _schedulePendingFinalFlush(result.words.map((word) => word.speaker));
      } else {
        _partialWords.clear();
        _partialWords.addAll(result.words);
        _schedulePendingFinalFlush(result.words.map((word) => word.speaker));
      }
    } else {
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

  void stopListening() {
    if (_partialWords.isNotEmpty) {
      final bufferedResult = SpeechRecognitionResult(
        words: List.from(_partialWords),
        isFinal: true,
      );
      _queueFinalResult(bufferedResult);
      _partialWords.clear();
      _clearAllOptimisticMessageIds();
    }

    _flushPendingFinalResults();

    _partialWords.clear();
    _clearAllOptimisticMessageIds();
  }

  int _speakerFlushKey(int? speaker) => speaker ?? -1;

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

  @override
  void dispose() {
    for (final timer in _finalResultTimersBySpeaker.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
