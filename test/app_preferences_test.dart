import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_intelligence/services/app_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads default preferences when nothing is persisted', () async {
    final preferences = AppPreferences();

    final snapshot = await preferences.load();

    expect(snapshot.deepgramRecognitionModel, 'nova-3');
    expect(snapshot.deepgramRecognitionLanguage, 'multi');
    expect(snapshot.speechToTextRecognitionLocale, 'multi');
    expect(snapshot.targetLanguage, 'en');
    expect(snapshot.hideTranslatedOriginalText, isTrue);
    expect(snapshot.audioPlaybackEnabled, isTrue);
    expect(snapshot.hasCompletedFirstLaunchWalkthrough, isFalse);
  });

  test('persists and reloads saved preferences', () async {
    final preferences = AppPreferences();

    await preferences.setDeepgramRecognitionModel('nova-3-medical');
    await preferences.setDeepgramRecognitionLanguage('en');
    await preferences.setSpeechToTextRecognitionLocale('es-ES');
    await preferences.setTargetLanguage('fr');
    await preferences.setHideTranslatedOriginalText(false);
    await preferences.setAudioPlaybackEnabled(false);
    await preferences.setHasCompletedFirstLaunchWalkthrough(true);

    final snapshot = await preferences.load();

    expect(snapshot.deepgramRecognitionModel, 'nova-3-medical');
    expect(snapshot.deepgramRecognitionLanguage, 'en');
    expect(snapshot.speechToTextRecognitionLocale, 'es-ES');
    expect(snapshot.targetLanguage, 'fr');
    expect(snapshot.hideTranslatedOriginalText, isFalse);
    expect(snapshot.audioPlaybackEnabled, isFalse);
    expect(snapshot.hasCompletedFirstLaunchWalkthrough, isTrue);
  });
}
