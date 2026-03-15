enum SpeechOutputProvider { google, deepgram }

extension SpeechOutputProviderLabel on SpeechOutputProvider {
  String get label {
    switch (this) {
      case SpeechOutputProvider.google:
        return 'Google';
      case SpeechOutputProvider.deepgram:
        return 'Deepgram';
    }
  }
}
