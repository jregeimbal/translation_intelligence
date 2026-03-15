enum SpeechSttProvider { deepgram, google }

extension SpeechSttProviderLabel on SpeechSttProvider {
  String get label {
    switch (this) {
      case SpeechSttProvider.deepgram:
        return 'Deepgram';
      case SpeechSttProvider.google:
        return 'Speech to Text';
    }
  }
}
