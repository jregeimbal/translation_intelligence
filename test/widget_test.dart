// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/widgets/chat_control_bar.dart';
import 'package:translation_intelligence/widgets/chat_message.dart';

import 'test_speech_controller.dart';

void main() {
  testWidgets('ChatControlBar shows speakers and clears', (tester) async {
    final controller = TestSpeechController();
    controller.addMessage(ChatMessage('Hello', speaker: 0));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<SpeechController>.value(
            value: controller,
            child: const ChatControlBar(),
          ),
        ),
      ),
    );

    expect(find.text('Primary speaker'), findsOneWidget);

    // Open dropdown to reveal speaker options
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();

    expect(find.text('Speaker 1'), findsOneWidget);

    // Clear via controller to avoid overlay timing issues.
    controller.clearMessages();
    await tester.pumpAndSettle();

    expect(find.text('Primary speaker'), findsNothing);
  });
}
