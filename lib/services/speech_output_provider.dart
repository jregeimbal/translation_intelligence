enum SpeechOutputProvider { google, deepgram, stts }

extension SpeechOutputProviderLabel on SpeechOutputProvider {
  String get label {
    switch (this) {
      case SpeechOutputProvider.google:
        return 'Google';
      case SpeechOutputProvider.deepgram:
        return 'Deepgram';
      case SpeechOutputProvider.stts:
        return 'STTS';
    }
  }
}
