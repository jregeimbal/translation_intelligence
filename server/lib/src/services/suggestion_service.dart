import 'dart:convert';

import 'package:logging/logging.dart';

import '../models/suggest_response.dart';
import '../models/suggest_response_request.dart';
import '../models/translate_request.dart' as models;
import 'google_auth_client_factory.dart';
import 'translation_service.dart';

abstract class SuggestionService {
  bool get isAvailable;

  Future<SuggestResponse> suggest(SuggestResponseRequest request);
}

class UnavailableSuggestionService implements SuggestionService {
  const UnavailableSuggestionService();

  @override
  bool get isAvailable => false;

  @override
  Future<SuggestResponse> suggest(SuggestResponseRequest request) {
    throw StateError('Suggestion service is unavailable');
  }
}

class GeminiSuggestionService implements SuggestionService {
  GeminiSuggestionService({
    required GoogleAuthClientFactory authFactory,
    required String projectId,
    required String model,
    required TranslationService translationService,
  }) : _authFactory = authFactory,
       _projectId = projectId,
       _model = model,
       _translationService = translationService;

  final GoogleAuthClientFactory _authFactory;
  final String _projectId;
  final String _model;
  final TranslationService _translationService;
  final Logger _logger = Logger('GeminiSuggestionService');

  static const _scopes = <String>[
    'https://www.googleapis.com/auth/cloud-platform',
    'https://www.googleapis.com/auth/generative-language.retriever',
  ];

  @override
  bool get isAvailable => true;

  @override
  Future<SuggestResponse> suggest(SuggestResponseRequest request) async {
    final originalReply = await _generateTargetLanguageReply(request);
    final translatedReply = await _translationService.translate(
      models.TranslateRequest(
        text: originalReply,
        sourceLanguage: request.sourceLanguageCode == 'multi'
            ? null
            : request.sourceLanguageCode,
        targetLanguage: request.targetLanguageCode == 'multi'
            ? 'en'
            : request.targetLanguageCode,
      ),
    );

    return SuggestResponse(
      originalText: originalReply,
      translatedText: translatedReply,
      sourceLanguageCode: request.sourceLanguageCode == 'multi'
            ? 'multi'
            : request.sourceLanguageCode,
      targetLanguageCode: request.targetLanguageCode == 'multi'
            ? 'en'
            : request.targetLanguageCode,
    );
  }

  Future<String> _generateTargetLanguageReply(
    SuggestResponseRequest request,
  ) async {
    final client = await _authFactory.getClient(_scopes);
    final requestPayload = <String, Object?>{
      'generationConfig': <String, Object?>{
        'temperature': 0.7,
        'maxOutputTokens': 65536,
        'responseMimeType': 'application/json',
      },
      'contents': <Object?>[
        <String, Object?>{
          'role': 'user',
          'parts': <Object?>[
            <String, Object?>{'text': _buildPrompt(request)},
          ],
        },
      ],
    };

    _logStructured(Level.INFO, <String, Object?>{
      'event': 'gemini_generate_content_request',
      'model': _model,
      'projectId': _projectId,
      'url':
          'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
      'request': request.toJson(),
      'payload': requestPayload,
    });

    final response = await client.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
      ),
      headers: {
        'content-type': 'application/json',
        'x-goog-user-project': _projectId,
      },
      body: jsonEncode(requestPayload),
    );

    _logStructured(Level.INFO, <String, Object?>{
      'event': 'gemini_generate_content_response',
      'model': _model,
      'statusCode': response.statusCode,
      'headers': response.headers,
      'body': _truncateForLog(response.body),
    });

    if (response.statusCode != 200) {
      throw StateError(
        'Gemini suggestion request failed: ${response.statusCode} ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List<dynamic>?;
    final firstCandidate = candidates?.firstOrNull as Map<String, dynamic>?;
    final content = firstCandidate?['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final firstPart = parts?.firstOrNull as Map<String, dynamic>?;
    final rawText = firstPart?['text'] as String?;

    _logStructured(Level.INFO, <String, Object?>{
      'event': 'gemini_generate_content_candidate_text',
      'model': _model,
      'rawText': _truncateForLog(rawText),
    });

    if (rawText == null || rawText.trim().isEmpty) {
      throw StateError('Gemini suggestion response was missing text');
    }

    final payload = _decodeCandidatePayload(rawText);
    final suggestion = payload['suggestedReply'] as String?;
    if (suggestion == null || suggestion.trim().isEmpty) {
      throw StateError('Gemini suggestion payload was missing suggestedReply');
    }

    return suggestion.trim();
  }

  String _buildPrompt(SuggestResponseRequest request) {
    return '''
You are generating a concise spoken reply suggestion for a live translation app.

Return JSON only with this shape:
{"suggestedReply":"..."}

Rules:
- Write the reply in the source language.
- Keep it natural, polite, and conversational.
- Keep it to one short sentence.
- Do not include markdown, notes, or extra keys.

Incoming message in source language ${request.sourceLanguageCode != 'multi' ? '(${request.sourceLanguageCode})' : ''}: ${request.messageText}
''';
  }

  Map<String, dynamic> _decodeCandidatePayload(String rawText) {
    try {
      return jsonDecode(rawText) as Map<String, dynamic>;
    } on FormatException catch (error) {
      _logStructured(Level.WARNING, <String, Object?>{
        'event': 'gemini_generate_content_parse_error',
        'model': _model,
        'message': error.message,
        'offset': error.offset,
        'source': _truncateForLog(error.source?.toString()),
        'rawText': _truncateForLog(rawText),
      });
      rethrow;
    }
  }

  void _logStructured(Level level, Map<String, Object?> payload) {
    _logger.log(level, jsonEncode(payload));
  }

  String? _truncateForLog(String? value, {int maxLength = 4000}) {
    if (value == null) {
      return null;
    }
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}...(truncated)';
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
