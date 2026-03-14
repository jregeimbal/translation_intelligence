import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/widgets/chat_message.dart';

import 'speech_controller_stub.dart';

void main() {
  group('ChatMessageList', () {
    testWidgets('shows listening placeholder when empty', (tester) async {
      final controller = TestSpeechController(
        isListening: true,
        speechEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SpeechController>.value(
              value: controller,
              child: const ChatMessageList(),
            ),
          ),
        ),
      );

      expect(find.textContaining('Listening'), findsOneWidget);
    });

    testWidgets('optimistically renders buffered text before first commit', (
      tester,
    ) async {
      final controller = TestSpeechController(
        isListening: true,
        speechEnabled: true,
      );
      controller.setListeningState(
        isListening: true,
        lastWords: 'buffered preview text',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SpeechController>.value(
              value: controller,
              child: const ChatMessageList(),
            ),
          ),
        ),
      );

      expect(find.text('buffered preview text...'), findsOneWidget);
      expect(find.textContaining('Listening...'), findsNothing);
    });

    testWidgets('shows idle prompt when empty and idle', (tester) async {
      final controller = TestSpeechController(
        isListening: false,
        speechEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SpeechController>.value(
              value: controller,
              child: const ChatMessageList(),
            ),
          ),
        ),
      );

      expect(find.text('Tap the mic to start listening...'), findsOneWidget);
      expect(
        find.text('If needed, please adjust your language preference'),
        findsNothing,
      );
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('renders speaker bubble with translation', (tester) async {
      final controller = TestSpeechController();
      final message = ChatMessage('Hola', speaker: 0, isFinal: true)
        ..translation = 'Hello';
      controller.preferredSpeaker = 0;
      controller.addMessage(message);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SpeechController>.value(
              value: controller,
              child: const ChatMessageList(),
            ),
          ),
        ),
      );

      expect(find.text('Hola'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Speaker 1'), findsOneWidget);
    });

    testWidgets('animates ellipsis for partial messages', (tester) async {
      final controller = TestSpeechController();
      controller.addMessage(ChatMessage('Streaming update', isFinal: false));

      List<double> ellipsisDotOpacities() {
        final textFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == null &&
              widget.textSpan?.toPlainText() == 'Streaming update...',
        );
        expect(textFinder, findsOneWidget);

        final richTextSource = tester.widget<Text>(textFinder);
        final root = richTextSource.textSpan as TextSpan;
        final dotSpans = (root.children ?? const <InlineSpan>[])
            .whereType<TextSpan>()
            .where((span) => span.text == '.')
            .toList();

        expect(dotSpans, hasLength(3));
        return dotSpans
            .map((span) => span.style?.color?.a ?? 1.0)
            .toList(growable: false);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SpeechController>.value(
              value: controller,
              child: const ChatMessageList(),
            ),
          ),
        ),
      );

      expect(find.text('Streaming update...'), findsOneWidget);
      final firstFrame = ellipsisDotOpacities();
      expect(firstFrame[0], greaterThan(firstFrame[1]));
      expect(firstFrame[0], greaterThan(firstFrame[2]));

      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Streaming update...'), findsOneWidget);
      final secondFrame = ellipsisDotOpacities();
      expect(secondFrame[1], greaterThan(secondFrame[0]));
      expect(secondFrame[1], greaterThan(secondFrame[2]));

      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Streaming update...'), findsOneWidget);
      final thirdFrame = ellipsisDotOpacities();
      expect(thirdFrame[2], greaterThan(thirdFrame[0]));
      expect(thirdFrame[2], greaterThan(thirdFrame[1]));
    });

    testWidgets('auto-scrolls when translation updates existing message', (
      tester,
    ) async {
      final controller = TestSpeechController();
      final messages = List.generate(
        24,
        (index) => ChatMessage('Message $index', isFinal: true),
      );
      for (final message in messages) {
        controller.addMessage(message);
      }
      final lastMessage = messages.last;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 220,
              child: ChangeNotifierProvider<SpeechController>.value(
                value: controller,
                child: const ChatMessageList(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      final initialBottomGap =
          scrollable.position.maxScrollExtent - scrollable.position.pixels;
      expect(initialBottomGap, lessThan(25.0));

      lastMessage.translation =
          'Translated message text that increases row height significantly.';
      controller.notifyListeners();
      await tester.pumpAndSettle();

      final updatedScrollable = tester.state<ScrollableState>(
        find.byType(Scrollable),
      );
      final updatedBottomGap =
          updatedScrollable.position.maxScrollExtent -
          updatedScrollable.position.pixels;
      expect(find.text(lastMessage.translation!), findsOneWidget);
      expect(updatedBottomGap, lessThanOrEqualTo(initialBottomGap + 1.0));
    });
  });
}
