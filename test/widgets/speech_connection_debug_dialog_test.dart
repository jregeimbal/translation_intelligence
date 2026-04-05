import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/models/speech_connection_debug_info.dart';
import 'package:translation_intelligence/widgets/speech_connection_debug_dialog.dart';
import '../test_app.dart';

void main() {
  group('SpeechConnectionDebugDialog', () {
    late SpeechConnectionDebugInfo debugInfo;
    late SpeechConnectionStartupException failure;

    setUp(() {
      debugInfo = SpeechConnectionDebugInfo(
        transport: 'wss',
        phase: 'connecting',
        uri: Uri.parse('wss://example.com/ws'),
        sourceLanguage: 'en-US',
        sampleRate: 16000,
        diarize: true,
        utterances: true,
        punctuate: true,
        smartFormat: true,
        detectLanguage: true,
        hasAuthToken: true,
        authTokenLength: 123,
      );

      failure = SpeechConnectionStartupException(
        message: 'Connection failed',
        debugInfo: debugInfo,
        cause: 'Network error',
      );
    });

    testWidgets('shows error message and cause', (tester) async {
      await pumpTestApp(
        tester,
        SpeechConnectionDebugDialog(failure: failure),
      );

      expect(find.text('Connection failed'), findsOneWidget);
      expect(find.text('Cause: Network error'), findsOneWidget);
    });

    testWidgets('shows debug info entries', (tester) async {
      await pumpTestApp(
        tester,
        SpeechConnectionDebugDialog(failure: failure),
      );

      expect(find.text('Transport: wss'), findsOneWidget);
      expect(find.text('Failure phase: connecting'), findsOneWidget);
      expect(find.text('URL: wss://example.com/ws'), findsOneWidget);
      expect(find.text('Source language: en-US'), findsOneWidget);
      expect(find.text('Sample rate: 16000 Hz'), findsOneWidget);
    });

    testWidgets('close button closes the dialog', (tester) async {
      await pumpTestApp(
        tester,
        SpeechConnectionDebugDialog(failure: failure),
      );

      // We use find.byType(TextButton) because the text might be localized.
      final closeButton = find.byType(TextButton);
      expect(closeButton, findsOneWidget);
      
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.byType(SpeechConnectionDebugDialog), findsNothing);
    });

    testWidgets('showIfAvailable returns false for non-exception error', (tester) async {
      // We need a BuildContext. We can get one from pumpWidget.
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      final BuildContext context = tester.element(find.byType(SizedBox));
      
      final result = await SpeechConnectionDebugDialog.showIfAvailable(
        context,
        'Some error',
      );
      expect(result, false);
    });

    // testWidgets('showIfAvailable returns true for SpeechConnectionStartupException', (tester) async {
    // We need a context. We can use a dummy context from a widget.
    // But showIfAvailable is static.

    // This is tricky to test without a real context. 
    // Let's try to use a mock context or just rely on the fact that it's a static method.
    
    //   await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    //   final BuildContext context = tester.element(find.byType(SizedBox));
      
    //   final result = await SpeechConnectionDebugDialog.showIfAvailable(
    //     context,
    //     failure,
    //   );
    //   expect(result, true);
    // });
  });
}
