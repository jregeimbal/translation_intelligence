enum SpeechTranslationProvider { google, googleMlKit }

extension SpeechTranslationProviderLabel on SpeechTranslationProvider {
  String get label {
    switch (this) {
      case SpeechTranslationProvider.google:
        return 'Google Cloud';
      case SpeechTranslationProvider.googleMlKit:
        return 'Google ML Kit';
    }
  }
}
