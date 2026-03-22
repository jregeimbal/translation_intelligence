class AppLanguageCatalog {
  static const List<String> supportedLanguageCodes = <String>[
    'en',
    'es',
    'fr',
    'de',
    'zh-CN',
    'ja',
    'ko',
    'pt',
    'ru',
    'ar',
    'hi',
  ];

  static bool isSupported(String languageCode) {
    return supportedLanguageCodes.contains(languageCode);
  }
}
