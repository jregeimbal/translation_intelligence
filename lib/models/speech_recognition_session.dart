import 'dart:typed_data';

import '../services/speech_stt_provider.dart';
import 'speech_recognition_models.dart';

class MicrophoneCaptureSession {

  const MicrophoneCaptureSession({
    required this.audioStream,
    required this.amplitudeStream,
    required this.stop,
    required this.sampleRate,
  });
  final Stream<Uint8List> audioStream;
  final Stream<double> amplitudeStream;
  final Future<void> Function() stop;
  final int sampleRate;
}

class SpeechRecognitionSession {

  SpeechRecognitionSession({
    required this.resultStream,
    required this.amplitudeStream,
    required this.stop,
    this.sampleRate,
    this.sttProvider = SpeechSttProvider.deepgram,
    this.sourceLanguage = 'multi',
    this.resolvedLanguageCode,
    this.listeningDeviceId,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();
  final Stream<SpeechRecognitionResult> resultStream;
  final Stream<double> amplitudeStream;
  final Future<void> Function() stop;
  final int? sampleRate;
  final SpeechSttProvider sttProvider;
  final String sourceLanguage;
  final String? resolvedLanguageCode;
  final String? listeningDeviceId;
  final DateTime startedAt;
}
