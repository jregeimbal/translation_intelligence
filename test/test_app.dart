import 'package:flutter/material.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/controllers/two_way_chat_controller.dart';
import 'package:translation_intelligence/l10n/app_localizations.dart';
import 'package:translation_intelligence/models/two_way_message.dart';

import 'speech_controller_stub.dart';

/// Fake TwoWayChatController for widget tests.
class _FakeTwoWayChatController extends ChangeNotifier
    implements TwoWayChatController {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #messages:
        return const <TwoWayMessage>[];
      case #canChangeLanguages:
        return true;
      case #speechEnabled:
        return true;
      case #isListening:
        return false;
      case #speechError:
      case #lastWords:
        return '';
      case #amplitude:
        return 0.0;
      case #activeSessionSampleRate:
      case #activeSessionSttProvider:
      case #activeSessionSourceLanguage:
      case #activeSessionResolvedLanguageCode:
      case #activeSessionListeningDeviceId:
      case #activeSessionStartedAt:
      case #activeSpeaker:
        return null;
      case #primaryLanguage:
        return 'en';
      case #guestLanguage:
        return 'es';
      case #deepgramRecognitionLanguage:
        return 'multi';
      case #speechToTextRecognitionLocale:
        return 'multi';
    }

    return super.noSuchMethod(invocation);
  }
}

Widget buildTestApp(
  Widget child, {
  SpeechController? speechController,
  TwoWayChatController? twoWayController,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(
        value: speechController ?? TestSpeechController(),
      ),
      ChangeNotifierProvider.value(
        value: twoWayController ?? _FakeTwoWayChatController(),
      ),
    ],
    child: MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      builder: (context, appChild) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(disableAnimations: true),
          child: appChild!,
        );
      },
      localizationsDelegates: const [
        LocaleNamesLocalizationsDelegate(),
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

Future<void> pumpTestApp(
  WidgetTester tester,
  Widget child, {
  SpeechController? speechController,
  TwoWayChatController? twoWayController,
}) {
  return tester
      .pumpWidget(
        buildTestApp(
          child,
          speechController: speechController,
          twoWayController: twoWayController,
        ),
      )
      .then((_) => tester.pump());
}
