import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/queued_chat_message.dart';
import '../models/suggested_response.dart';
import '../services/backend_api_client.dart';

class SuggestionController extends ChangeNotifier {

  SuggestionController({BackendApiClient? backendApiClient})
    : _backendApiClient = backendApiClient {
    _preferredSpeaker = null;
  }
  final BackendApiClient? _backendApiClient;

  final Set<String> _requestedSuggestionMessageIds = <String>{};
  final StreamController<SuggestedResponseEvent> _suggestedResponseController =
      StreamController<SuggestedResponseEvent>.broadcast();

  int? _preferredSpeaker;

  bool get isClosed => _suggestedResponseController.isClosed;
  Stream<SuggestedResponseEvent> get suggestedResponses =>
      _suggestedResponseController.stream;

  void setPreferredSpeaker(int? speaker) {
    _preferredSpeaker = speaker;
  }

  Future<void> maybeRequestSuggestedResponse(ChatMessage message) async {
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

  Future<void> maybeRequestSuggestedResponseForQueued(
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
    if (_preferredSpeaker == null || speaker == null) {
      return false;
    }
    if (speaker == _preferredSpeaker) {
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

  @override
  void dispose() {
    _suggestedResponseController.close();
    super.dispose();
  }
}
