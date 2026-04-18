import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/controllers/two_way_chat_controller.dart';
import 'package:translation_intelligence/l10n/app_localizations.dart';
import 'package:translation_intelligence/main.dart';
import 'package:translation_intelligence/models/chat_message.dart';
import 'package:translation_intelligence/models/two_way_message.dart';
import 'package:translation_intelligence/services/backend_api_client.dart';

import 'fake_speech_controller.dart';
import 'fake_two_way_chat_controller.dart';

/// Wraps the real [MyHomePage] with pre-configured stub controllers so that no
/// Firebase, Deepgram, or backend connectivity is required during e2e tests.
///
/// Call [simulateRecognition] after the app is pumped to inject a speech
/// recognition result (original + translation) into the group chat flow.
class E2eTestApp extends StatefulWidget {
  const E2eTestApp({super.key});

  /// A global key used by tests to drive simulated speech events.
  static final controller = FakeSpeechController(speechEnabled: true);
  static final twoWayController = FakeTwoWayChatController();
  static final backendApiClient = BackendApiClient(
    baseUrl: 'https://e2e-test.invalid',
    authTokenProvider: () async => 'e2e-test-token',
  );

  /// Simulate a user speaking: injects the original text and its translation
  /// into the controller so the chat view can display them.
  static void simulateRecognition({
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
  State<E2eTestApp> createState() => _E2eTestAppState();
}

class _E2eTestAppState extends State<E2eTestApp> {
  @override
  void initState() {
    super.initState();
    // Mark the first-launch walkthrough as already seen so it doesn't block.
    SharedPreferences.setMockInitialValues({
      'hasCompletedFirstLaunchWalkthrough': true,
    });
  }

  @override
  Widget build(BuildContext context) {
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
          backendApiClient: E2eTestApp.backendApiClient,
          controller: E2eTestApp.controller,
          twoWayController: E2eTestApp.twoWayController,
        ),
      ),
    );
  }
}
