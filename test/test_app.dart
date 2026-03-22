import 'package:flutter/material.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/l10n/app_localizations.dart';

Widget buildTestApp(Widget child) {
  return MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
    localizationsDelegates: const [
      LocaleNamesLocalizationsDelegate(),
      ...AppLocalizations.localizationsDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Future<void> pumpTestApp(WidgetTester tester, Widget child) {
  return tester.pumpWidget(buildTestApp(child)).then((_) => tester.pump());
}
