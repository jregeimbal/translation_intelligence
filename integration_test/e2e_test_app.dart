import 'package:flutter/material.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_intelligence/l10n/app_localizations.dart';
import 'package:translation_intelligence/main.dart';
import 'package:translation_intelligence/models/chat_message.dart';
import 'package:translation_intelligence/services/backend_api_client.dart';

import 'fake_speech_controller.dart';
import 'fake_two_way_chat_controller.dart';

/// Wraps the real [MyHomePage] with pre-configured stub controllers so that no
/// Firebase, Deepgram, or backend connectivity is required during e2e tests.
///
/// Each test should create a fresh [E2eTestApp] via [E2eTestApp.create] to
/// ensure controllers are not shared across tests.
class E2eTestApp extends StatelessWidget {
  const E2eTestApp._({
    required this.controller,
    required this.twoWayController,
  });

  factory E2eTestApp.create() {
    SharedPreferences.setMockInitialValues({
      'pref.hasCompletedFirstLaunchWalkthrough': true,
    });
    return E2eTestApp._(
      controller: FakeSpeechController(speechEnabled: true),
      twoWayController: FakeTwoWayChatController(),
    );
  }

  /// The fake speech controller used by this test instance.
  final FakeSpeechController controller;

  /// The fake two-way controller used by this test instance.
  final FakeTwoWayChatController twoWayController;

  /// Simulate a user speaking: injects the original text and its translation
  /// into the controller so the chat view can display them.
  void simulateRecognition({
    required String original,
    required String translation,
    int? speaker,
    String? sourceLanguageCode,
    String? targetLanguageCode,
  }) {
    final msg = ChatMessage(
      original,
      speaker: speaker,
      isFinal: true,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
    )..translation = translation;

    controller.addMessage(msg);
  }

  @override
  Widget build(BuildContext context) {
    final backendApiClient = BackendApiClient(
      baseUrl: 'https://e2e-test.invalid',
      authTokenProvider: () async => 'e2e-test-token',
    );

    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'OmniaLingo',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      localizationsDelegates: const [
        LocaleNamesLocalizationsDelegate(),
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MyHomePage(
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) {},
        initializer: () async => HomePageInitializationBundle(
          backendApiClient: backendApiClient,
          controller: controller,
          twoWayController: twoWayController,
        ),
      ),
    );
  }
}
