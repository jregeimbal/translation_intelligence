class DeepgramRecognitionCatalog {
  static const String defaultRecognitionModel = 'nova-3';
  static const String defaultRecognitionLanguage = 'multi';

  static const List<String> supportedRecognitionModels = [
    'nova-3',
    'nova-3-medical',
  ];

  static const Map<String, Map<String, String>>
  supportedRecognitionLanguagesByModel = {
    'nova-3': {
      'Multi': 'multi',
      'Arabic': 'ar',
      'Arabic (UAE)': 'ar-AE',
      'Arabic (Saudi Arabia)': 'ar-SA',
      'Arabic (Qatar)': 'ar-QA',
      'Arabic (Kuwait)': 'ar-KW',
      'Arabic (Syria)': 'ar-SY',
      'Arabic (Lebanon)': 'ar-LB',
      'Arabic (Palestine)': 'ar-PS',
      'Arabic (Jordan)': 'ar-JO',
      'Arabic (Egypt)': 'ar-EG',
      'Arabic (Sudan)': 'ar-SD',
      'Arabic (Chad)': 'ar-TD',
      'Arabic (Morocco)': 'ar-MA',
      'Arabic (Algeria)': 'ar-DZ',
      'Arabic (Tunisia)': 'ar-TN',
      'Arabic (Iraq)': 'ar-IQ',
      'Arabic (Iran)': 'ar-IR',
      'Belarusian': 'be',
      'Bengali': 'bn',
      'Bosnian': 'bs',
      'Bulgarian': 'bg',
      'Catalan': 'ca',
      'Croatian': 'hr',
      'Czech': 'cs',
      'Danish': 'da',
      'Danish (Denmark)': 'da-DK',
      'Dutch': 'nl',
      'English': 'en',
      'English (US)': 'en-US',
      'English (Australia)': 'en-AU',
      'English (UK)': 'en-GB',
      'English (India)': 'en-IN',
      'English (New Zealand)': 'en-NZ',
      'Estonian': 'et',
      'Finnish': 'fi',
      'Flemish': 'nl-BE',
      'Spanish': 'es',
      'French': 'fr',
      'French (Canada)': 'fr-CA',
      'German': 'de',
      'German (Switzerland)': 'de-CH',
      'Greek': 'el',
      'Hebrew': 'he',
      'Hindi': 'hi',
      'Hungarian': 'hu',
      'Indonesian': 'id',
      'Italian': 'it',
      'Japanese': 'ja',
      'Kannada': 'kn',
      'Korean': 'ko',
      'Korean (Korea)': 'ko-KR',
      'Latvian': 'lv',
      'Lithuanian': 'lt',
      'Macedonian': 'mk',
      'Malay': 'ms',
      'Marathi': 'mr',
      'Norwegian': 'no',
      'Persian': 'fa',
      'Polish': 'pl',
      'Portuguese': 'pt',
      'Portuguese (Brazil)': 'pt-BR',
      'Portuguese (Portugal)': 'pt-PT',
      'Romanian': 'ro',
      'Russian': 'ru',
      'Serbian': 'sr',
      'Slovak': 'sk',
      'Slovenian': 'sl',
      'Spanish (Latin America)': 'es-419',
      'Swedish': 'sv',
      'Swedish (Sweden)': 'sv-SE',
      'Tagalog': 'tl',
      'Tamil': 'ta',
      'Telugu': 'te',
      'Turkish': 'tr',
      'Ukrainian': 'uk',
      'Urdu': 'ur',
      'Vietnamese': 'vi',
    },
    'nova-3-medical': {
      'English': 'en',
      'English (US)': 'en-US',
      'English (Australia)': 'en-AU',
      'English (Canada)': 'en-CA',
      'English (UK)': 'en-GB',
      'English (Ireland)': 'en-IE',
      'English (India)': 'en-IN',
      'English (New Zealand)': 'en-NZ',
    },
  };

  static Map<String, String> supportedRecognitionLanguagesForModel(
    String model,
  ) {
    return supportedRecognitionLanguagesByModel[model] ??
        supportedRecognitionLanguagesByModel[defaultRecognitionModel]!;
  }

  static bool isRecognitionLanguageSupportedForModel(
    String model,
    String language,
  ) {
    return supportedRecognitionLanguagesForModel(model).containsValue(language);
  }

  static String defaultRecognitionLanguageForModel(String model) {
    switch (model) {
      case 'nova-3-medical':
        return 'en';
      case 'nova-3':
      default:
        return defaultRecognitionLanguage;
    }
  }
}
