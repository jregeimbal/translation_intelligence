import 'package:flutter/material.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/l10n/app_localizations.dart';
import 'package:translation_intelligence/models/speech_connection_debug_info.dart';
import 'package:translation_intelligence/widgets/speech_connection_debug_dialog.dart';

void main() {
  group('SpeechConnectionDebugDialog', () {
    testWidgets('displays dialog with error message', (WidgetTester tester) async {
      final debugInfo = SpeechConnectionDebugInfo(
        transport: 'wss',
        phase: 'connection',
        uri: Uri.parse('wss://example.com:443/path?query=value'),
        sourceLanguage: 'en',
        sampleRate: 16000,
        diarize: true,
        utterances: false,
        punctuate: true,
        smartFormat: false,
        detectLanguage: true,
        hasAuthToken: true,
        authTokenLength: 256,
        model: 'test-model',
        language: 'en-US',
        listeningDeviceId: 'device-123',
        timeout: const Duration(seconds: 30),
      );

      final exception = SpeechConnectionStartupException(
        message: 'Connection failed',
        debugInfo: debugInfo,
        cause: Exception('Network error'),
      );

      await tester.pumpWidget(
        MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: const [
            LocaleNamesLocalizationsDelegate(),
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  SpeechConnectionDebugDialog.showIfAvailable(
                    context,
                    exception,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Listening Connection Debug'), findsOneWidget);
      expect(find.text('Connection failed'), findsOneWidget);
      expect(find.text('Cause: Exception: Network error'), findsOneWidget);
    });

    testWidgets('displays debug info entries', (WidgetTester tester) async {
      final debugInfo = SpeechConnectionDebugInfo(
        transport: 'wss',
        phase: 'authentication',
        uri: Uri.parse('wss://api.example.com:8080/v1/listen?param=value'),
        sourceLanguage: 'es',
        sampleRate: 44100,
        diarize: false,
        utterances: true,
        punctuate: false,
        smartFormat: true,
        detectLanguage: false,
        hasAuthToken: false,
        authTokenLength: 0,
        model: null,
        language: null,
        listeningDeviceId: null,
        timeout: const Duration(seconds: 30),
      );

      final exception = SpeechConnectionStartupException(
        message: 'Authentication failed',
        debugInfo: debugInfo,
      );

      await tester.pumpWidget(
        MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: const [
            LocaleNamesLocalizationsDelegate(),
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  SpeechConnectionDebugDialog.showIfAvailable(
                    context,
                    exception,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Transport: wss'), findsOneWidget);
      expect(find.text('Failure phase: authentication'), findsOneWidget);
      expect(find.text('URL: wss://api.example.com:8080/v1/listen?param=value'), findsOneWidget);
      expect(find.text('Scheme: wss'), findsOneWidget);
      expect(find.text('Host: api.example.com'), findsOneWidget);
      expect(find.text('Port: 8080'), findsOneWidget);
      expect(find.text('Path: /v1/listen'), findsOneWidget);
      expect(find.text('Query: param=value'), findsOneWidget);
      expect(find.text('Source language: es'), findsOneWidget);
      expect(find.text('Sample rate: 44100 Hz'), findsOneWidget);
      expect(find.text('Model: (default)'), findsOneWidget);
      expect(find.text('Language: (auto)'), findsOneWidget);
      expect(find.text('Listening device: auto'), findsOneWidget);
      expect(find.text('Auth token present: no'), findsOneWidget);
      expect(find.text('Auth token length: 0'), findsOneWidget);
      expect(find.text('Diarize: false'), findsOneWidget);
      expect(find.text('Utterances: true'), findsOneWidget);
      expect(find.text('Punctuate: false'), findsOneWidget);
      expect(find.text('Smart format: true'), findsOneWidget);
      expect(find.text('Detect language: false'), findsOneWidget);
      expect(find.text('Startup timeout: 30000 ms'), findsOneWidget);
    });

    testWidgets('closes dialog when close button is tapped', (WidgetTester tester) async {
      final debugInfo = SpeechConnectionDebugInfo(
        transport: 'ws',
        phase: 'initialization',
        uri: Uri.parse('ws://localhost:3000/listen'),
        sourceLanguage: 'en',
        sampleRate: 16000,
        diarize: false,
        utterances: false,
        punctuate: false,
        smartFormat: false,
        detectLanguage: false,
        hasAuthToken: false,
        authTokenLength: 0,
      );

      final exception = SpeechConnectionStartupException(
        message: 'Initialization failed',
        debugInfo: debugInfo,
      );

      await tester.pumpWidget(
        MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: const [
            LocaleNamesLocalizationsDelegate(),
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  SpeechConnectionDebugDialog.showIfAvailable(
                    context,
                    exception,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('does not show dialog for non-SpeechConnectionStartupException errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: const [
            LocaleNamesLocalizationsDelegate(),
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  SpeechConnectionDebugDialog.showIfAvailable(
                    context,
                    Exception('Generic error'),
                  );
                },
                child: const Text('Open Button'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open Button'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('handles empty URI components', (WidgetTester tester) async {
      final debugInfo = SpeechConnectionDebugInfo(
        transport: 'http',
        phase: 'connection',
        uri: Uri.parse('http://example.com'),
        sourceLanguage: 'fr',
        sampleRate: 8000,
        diarize: true,
        utterances: true,
        punctuate: true,
        smartFormat: true,
        detectLanguage: true,
        hasAuthToken: true,
        authTokenLength: 128,
      );

      final exception = SpeechConnectionStartupException(
        message: 'Connection error',
        debugInfo: debugInfo,
      );

      await tester.pumpWidget(
        MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: const [
            LocaleNamesLocalizationsDelegate(),
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  SpeechConnectionDebugDialog.showIfAvailable(
                    context,
                    exception,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Path: /'), findsOneWidget);
      expect(find.text('Port: 80'), findsOneWidget);
    });

    testWidgets('handles default ports correctly', (WidgetTester tester) async {
      final wssDebugInfo = SpeechConnectionDebugInfo(
        transport: 'wss',
        phase: 'test',
        uri: Uri.parse('wss://example.com/path'),
        sourceLanguage: 'en',
        sampleRate: 16000,
        diarize: false,
        utterances: false,
        punctuate: false,
        smartFormat: false,
        detectLanguage: false,
        hasAuthToken: false,
        authTokenLength: 0,
      );

      final wsDebugInfo = SpeechConnectionDebugInfo(
        transport: 'ws',
        phase: 'test',
        uri: Uri.parse('ws://example.com/path'),
        sourceLanguage: 'en',
        sampleRate: 16000,
        diarize: false,
        utterances: false,
        punctuate: false,
        smartFormat: false,
        detectLanguage: false,
        hasAuthToken: false,
        authTokenLength: 0,
      );

      expect(wssDebugInfo.toDisplayEntries().any((e) => e.key == 'Port' && e.value == '443'), isTrue);
      expect(wsDebugInfo.toDisplayEntries().any((e) => e.key == 'Port' && e.value == '80'), isTrue);
    });
  });

  group('SpeechConnectionDebugInfo', () {
    test('toDisplayEntries returns all expected entries', () {
      final debugInfo = SpeechConnectionDebugInfo(
        transport: 'wss',
        phase: 'connection',
        uri: Uri.parse('wss://example.com:443/path?query=value'),
        sourceLanguage: 'en',
        sampleRate: 16000,
        diarize: true,
        utterances: false,
        punctuate: true,
        smartFormat: false,
        detectLanguage: true,
        hasAuthToken: true,
        authTokenLength: 256,
        model: 'test-model',
        language: 'en-US',
        listeningDeviceId: 'device-123',
        timeout: const Duration(seconds: 30),
      );

      final entries = debugInfo.toDisplayEntries();

      expect(entries.length, greaterThan(10));
      expect(
        entries.any((e) => e.key == 'Transport' && e.value == 'wss'),
        isTrue,
      );
      expect(
        entries.any((e) => e.key == 'Failure phase' && e.value == 'connection'),
        isTrue,
      );
      expect(
        entries.any((e) =>
            e.key == 'URL' && e.value == 'wss://example.com:443/path?query=value'),
        isTrue,
      );
    });

    test('toDisplayEntries handles null values correctly', () {
      final debugInfo = SpeechConnectionDebugInfo(
        transport: 'ws',
        phase: 'test',
        uri: Uri.parse('ws://example.com'),
        sourceLanguage: 'en',
        sampleRate: 16000,
        diarize: false,
        utterances: false,
        punctuate: false,
        smartFormat: false,
        detectLanguage: false,
        hasAuthToken: false,
        authTokenLength: 0,
      );

      final entries = debugInfo.toDisplayEntries();

      expect(
        entries.any((e) => e.key == 'Model' && e.value == '(default)'),
        isTrue,
      );
      expect(
        entries.any((e) => e.key == 'Language' && e.value == '(auto)'),
        isTrue,
      );
      expect(
        entries.any((e) => e.key == 'Listening device' && e.value == 'auto'),
        isTrue,
      );
      expect(
        entries.any((e) => e.key == 'Startup timeout'),
        isFalse,
      );
    });

    test('SpeechConnectionStartupException toString returns message', () {
      final exception = SpeechConnectionStartupException(
        message: 'Test error message',
        debugInfo: SpeechConnectionDebugInfo(
          transport: 'wss',
          phase: 'test',
          uri: Uri.parse('wss://example.com'),
          sourceLanguage: 'en',
          sampleRate: 16000,
          diarize: false,
          utterances: false,
          punctuate: false,
          smartFormat: false,
          detectLanguage: false,
          hasAuthToken: false,
          authTokenLength: 0,
        ),
      );

      expect(exception.toString(), equals('Test error message'));
    });
  });
}
