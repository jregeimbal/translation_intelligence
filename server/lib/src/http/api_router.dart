import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../models/translate_request.dart';
import '../models/tts_request.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import 'json_response.dart';

class ApiRouter {
  ApiRouter({
    required TranslationService translationService,
    required TtsService googleTtsService,
    required TtsService deepgramTtsService,
  }) : _translationService = translationService,
       _googleTtsService = googleTtsService,
       _deepgramTtsService = deepgramTtsService;

  final TranslationService _translationService;
  final TtsService _googleTtsService;
  final TtsService _deepgramTtsService;

  Router get router {
    final router = Router();
    router.get('/v1/health', _health);
    router.get('/v1/capabilities', _capabilities);
    router.post('/v1/translate', _translate);
    router.post('/v1/tts', _tts);
    return router;
  }

  Response _health(Request request) {
    return jsonResponse({'status': 'ok'});
  }

  Response _capabilities(Request request) {
    return jsonResponse({
      'translationProviders': ['google'],
      'ttsProviders': ['google', 'deepgram'],
      'status': 'ok',
    });
  }

  Future<Response> _translate(Request request) async {
    final translateRequest = TranslateRequest.fromJson(
      jsonDecode(await request.readAsString()) as Map<String, dynamic>,
    );
    final translatedText = await _translationService.translate(
      translateRequest,
    );

    return jsonResponse({
      'translatedText': translatedText,
      'targetLanguage': translateRequest.targetLanguage,
      if (translateRequest.sourceLanguage != null)
        'sourceLanguage': translateRequest.sourceLanguage,
    });
  }

  Future<Response> _tts(Request request) async {
    final ttsRequest = TtsRequest.fromJson(
      jsonDecode(await request.readAsString()) as Map<String, dynamic>,
    );

    final service = switch (ttsRequest.provider) {
      TtsProvider.google => _googleTtsService,
      TtsProvider.deepgram => _deepgramTtsService,
    };

    final audioBytes = await service.synthesize(ttsRequest);
    return Response.ok(audioBytes, headers: {'content-type': 'audio/mpeg'});
  }
}
