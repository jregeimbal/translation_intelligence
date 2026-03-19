import 'dart:typed_data';

import '../models/speech_recognition_models.dart';

abstract class LiveRecognitionService {
  Future<bool> isApiKeyValid();

  Stream<SpeechRecognitionResult> startLiveRecognition(
    Stream<Uint8List> audioStream, {
    required String sourceLanguage,
    String? model,
    String? language,
    bool diarize = false,
    bool utterances = false,
    String sampleRate = '16000',
    bool interimResults = true,
    bool punctuate = true,
    bool smartFormat = false,
    bool detectLanguage = false,
  });
}
