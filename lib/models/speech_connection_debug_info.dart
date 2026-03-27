class SpeechConnectionDebugInfo {
  const SpeechConnectionDebugInfo({
    required this.transport,
    required this.phase,
    required this.uri,
    required this.sourceLanguage,
    required this.sampleRate,
    required this.diarize,
    required this.utterances,
    required this.punctuate,
    required this.smartFormat,
    required this.detectLanguage,
    required this.hasAuthToken,
    required this.authTokenLength,
    this.model,
    this.language,
    this.listeningDeviceId,
    this.timeout,
  });

  final String transport;
  final String phase;
  final Uri uri;
  final String sourceLanguage;
  final int sampleRate;
  final String? model;
  final String? language;
  final bool diarize;
  final bool utterances;
  final bool punctuate;
  final bool smartFormat;
  final bool detectLanguage;
  final String? listeningDeviceId;
  final bool hasAuthToken;
  final int authTokenLength;
  final Duration? timeout;

  List<MapEntry<String, String>> toDisplayEntries() {
    return <MapEntry<String, String>>[
      MapEntry('Transport', transport),
      MapEntry('Failure phase', phase),
      MapEntry('URL', uri.toString()),
      MapEntry('Scheme', uri.scheme),
      MapEntry('Host', uri.host.isEmpty ? '(none)' : uri.host),
      MapEntry('Port', _portLabel()),
      MapEntry('Path', uri.path.isEmpty ? '/' : uri.path),
      if (uri.query.isNotEmpty) MapEntry('Query', uri.query),
      MapEntry('Source language', sourceLanguage),
      MapEntry('Sample rate', '$sampleRate Hz'),
      MapEntry('Model', model ?? '(default)'),
      MapEntry('Language', language ?? '(auto)'),
      MapEntry('Listening device', listeningDeviceId ?? 'auto'),
      MapEntry('Auth token present', hasAuthToken ? 'yes' : 'no'),
      MapEntry('Auth token length', authTokenLength.toString()),
      MapEntry('Diarize', diarize ? 'true' : 'false'),
      MapEntry('Utterances', utterances ? 'true' : 'false'),
      MapEntry('Punctuate', punctuate ? 'true' : 'false'),
      MapEntry('Smart format', smartFormat ? 'true' : 'false'),
      MapEntry('Detect language', detectLanguage ? 'true' : 'false'),
      if (timeout != null)
        MapEntry('Startup timeout', '${timeout!.inMilliseconds} ms'),
    ];
  }

  String _portLabel() {
    if (uri.hasPort) {
      return uri.port.toString();
    }

    switch (uri.scheme) {
      case 'wss':
      case 'https':
        return '443';
      case 'ws':
      case 'http':
        return '80';
      default:
        return '(default)';
    }
  }
}

class SpeechConnectionStartupException implements Exception {
  const SpeechConnectionStartupException({
    required this.message,
    required this.debugInfo,
    this.cause,
  });

  final String message;
  final SpeechConnectionDebugInfo debugInfo;
  final Object? cause;

  @override
  String toString() => message;
}
