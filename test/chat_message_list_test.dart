import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/models/chat_message.dart';
import 'package:translation_intelligence/widgets/chat_message.dart';

import 'speech_controller_stub.dart';
import 'test_app.dart';

void main() {
  group('ChatMessageList', () {
    testWidgets('shows listening placeholder when empty', (tester) async {
      final controller = TestSpeechController(
        isListening: true,
        speechEnabled: true,
      );

      await pumpTestApp(
        tester,
        ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const ChatMessageList(),
        ),
      );

      expect(find.textContaining('Listening'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.textContaining('Listening'),
          matching: find.byType(ShaderMask),
        ),
        findsOneWidget,
      );
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

      await pumpTestApp(
        tester,
        ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const ChatMessageList(),
        ),
      );

      expect(find.text('buffered preview text'), findsOneWidget);
      expect(find.text('buffered preview text...'), findsNothing);
      expect(find.textContaining('Listening...'), findsNothing);

      double bufferedPreviewOpacity() {
        final textFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              ((widget.data == 'buffered preview text') ||
                  (widget.data == null &&
                      widget.textSpan?.toPlainText() ==
                          'buffered preview text')),
        );
        expect(textFinder, findsOneWidget);

        final opacityAncestors = find
            .ancestor(of: textFinder, matching: find.byType(Opacity))
            .evaluate()
            .map((element) => element.widget)
            .whereType<Opacity>()
            .toList(growable: false);

        expect(opacityAncestors, isNotEmpty);
        return opacityAncestors.first.opacity;
      }

      expect(bufferedPreviewOpacity(), closeTo(0.7, 0.001));
      expect(
        find.ancestor(of: find.text('buffered preview text'), matching: find.byType(ShaderMask)),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('buffered preview text'), findsOneWidget);
      expect(bufferedPreviewOpacity(), closeTo(0.7, 0.001));
    });

    testWidgets('shows idle prompt when empty and idle', (tester) async {
      final controller = TestSpeechController(
        isListening: false,
        speechEnabled: true,
      );

      await pumpTestApp(
        tester,
        ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const ChatMessageList(),
        ),
      );

      expect(find.text('Tap the mic to start listening...'), findsOneWidget);
      expect(
        find.text('If needed, please adjust your language preference'),
        findsNothing,
      );
      expect(find.byType(DropdownMenuFormField<String>), findsNothing);
    });

    testWidgets('shows unavailable prompt when speech is disabled', (
      tester,
    ) async {
      final controller = TestSpeechController(
        isListening: false,
        speechEnabled: false,
      );

      await pumpTestApp(
        tester,
        ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const ChatMessageList(),
        ),
      );

      expect(find.text('Speech not available'), findsOneWidget);
    });

    testWidgets('renders speaker bubble with translation', (tester) async {
      final controller = TestSpeechController();
      final message = ChatMessage('Hola', speaker: 0, isFinal: true)
        ..translation = 'Hello';
      controller.preferredSpeaker = 0;
      controller.addMessage(message);

      await pumpTestApp(
        tester,
        ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const ChatMessageList(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Hola'), findsNothing);
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Speaker 1'), findsOneWidget);
      expect(find.byTooltip('Replay translation'), findsOneWidget);
      expect(find.text('Show original'), findsNothing);
      expect(find.text('Hide original'), findsNothing);
    });

    testWidgets('replays a translated message when replay button is tapped', (
      tester,
    ) async {
      final controller = TestSpeechController();
      final message = ChatMessage('Hola', speaker: 0, isFinal: true)
        ..translation = 'Hello';
      controller.addMessage(message);

      await pumpTestApp(
        tester,
        ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const ChatMessageList(),
        ),
      );

      await tester.tap(
        find.byKey(ValueKey<String>('${message.id}_replay_translation')),
      );
      await tester.pump();

      expect(controller.replayTranslationCallCount, equals(1));
      expect(controller.lastReplayedTranslation, equals('Hello'));
    });

    testWidgets('final message without translation keeps original visible', (
      tester,
    ) async {
      final controller = TestSpeechController();
      controller.addMessage(ChatMessage('No translation yet', isFinal: true));

      await pumpTestApp(
        tester,
        ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const ChatMessageList(),
        ),
      );

      expect(find.text('No translation yet'), findsOneWidget);
      expect(find.text('Show original'), findsNothing);
      expect(find.text('Hide original'), findsNothing);
    });

    testWidgets(
      'final messages toggle original visibility when bubble is tapped',
      (tester) async {
        final controller = TestSpeechController();
        controller.preferredSpeaker = 0;
        final message = ChatMessage('Hola', speaker: 0, isFinal: true)
          ..translation = 'Hello';
        controller.addMessage(message);

        await pumpTestApp(
          tester,
          ChangeNotifierProvider<SpeechController>.value(
            value: controller,
            child: const ChatMessageList(),
          ),
        );

        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Hola'), findsNothing);
        expect(find.text('Hello'), findsOneWidget);
        expect(find.text('Show original'), findsNothing);
        expect(find.text('Hide original'), findsNothing);

        await tester.tap(
          find.byKey(ValueKey<String>('chat_bubble_${message.id}')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hola'), findsOneWidget);

        final bodyText = tester.widget<Text>(find.text('Hola'));
        expect(bodyText.textAlign, TextAlign.right);

        await tester.tap(
          find.byKey(ValueKey<String>('chat_bubble_${message.id}')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hola'), findsNothing);
      },
    );

    testWidgets('global hide-original toggle shows all originals when off', (
      tester,
    ) async {
      final controller = TestSpeechController();
      controller.setHideTranslatedOriginalText(false);
      final message = ChatMessage('Hola', speaker: 0, isFinal: true)
        ..translation = 'Hello';
      controller.addMessage(message);

      await pumpTestApp(
        tester,
        ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const ChatMessageList(),
        ),
      );

      expect(find.text('Hola'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Show original'), findsNothing);
      expect(find.text('Hide original'), findsNothing);
    });

    testWidgets('hover hint toggles between show and hide original labels', (
      tester,
    ) async {
      final controller = TestSpeechController();
      final message = ChatMessage('Hola', speaker: 0, isFinal: true)
        ..translation = 'Hello';
      controller.addMessage(message);

      await pumpTestApp(
        tester,
        ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const ChatMessageList(),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();

      final bubbleFinder = find.byKey(
        ValueKey<String>('chat_bubble_${message.id}'),
      );
      await gesture.moveTo(tester.getCenter(bubbleFinder));
      await tester.pumpAndSettle();

      expect(find.text('Show original'), findsOneWidget);

      await tester.tap(bubbleFinder);
      await tester.pumpAndSettle();

      expect(find.text('Hola'), findsOneWidget);
      expect(find.text('Hide original'), findsOneWidget);

      await gesture.moveTo(const Offset(0, 0));
      await tester.pumpAndSettle();

      expect(find.text('Show original'), findsNothing);
      expect(find.text('Hide original'), findsNothing);
    });

    testWidgets('original text animates out when translation finalizes', (
      tester,
    ) async {
      final controller = TestSpeechController();
      final message = ChatMessage('Hola', speaker: 0, isFinal: false);
      controller.addMessage(message);

      await pumpTestApp(
        tester,
        ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const ChatMessageList(),
        ),
      );

      expect(find.text('Hola'), findsOneWidget);
      expect(find.text('Hola...'), findsNothing);

      message.isFinal = true;
      message.translation = 'Hello';
      controller.notifyListeners();
      await tester.pump();

      expect(find.text('Hola'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('Hola'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Hola'), findsNothing);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('right-aligns primary speaker header and body text', (
      tester,
    ) async {
      final controller = TestSpeechController();
      controller.preferredSpeaker = 0;
      controller.addMessage(
        ChatMessage('Primary line', speaker: 0, isFinal: false),
      );

      await pumpTestApp(
        tester,
        ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const ChatMessageList(),
        ),
      );

      final headerAlign = tester.widgetList<Align>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Align &&
              widget.child is Row &&
              widget.alignment == Alignment.centerRight,
        ),
      );

      expect(headerAlign, isNotEmpty);

      final bodyText = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && widget.data == 'Primary line',
        ),
      );
      expect(bodyText.textAlign, TextAlign.right);
      expect(
        find.ancestor(of: find.text('Primary line'), matching: find.byType(ShaderMask)),
        findsOneWidget,
      );
    });

    testWidgets('left-aligns non-primary speaker header and body text', (
      tester,
    ) async {
      final controller = TestSpeechController();
      controller.preferredSpeaker = 1;
      controller.addMessage(
        ChatMessage('Guest line', speaker: 0, isFinal: false),
      );

      await pumpTestApp(
        tester,
        ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const ChatMessageList(),
        ),
      );

      final headerAlign = tester.widgetList<Align>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Align &&
              widget.child is Row &&
              widget.alignment == Alignment.centerLeft,
        ),
      );
      expect(headerAlign, isNotEmpty);

      final bodyText = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && widget.data == 'Guest line',
        ),
      );
      expect(bodyText.textAlign, TextAlign.left);
      expect(
        find.ancestor(of: find.text('Guest line'), matching: find.byType(ShaderMask)),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders grouped segments inline with punctuation-aware separators',
      (tester) async {
        final controller = TestSpeechController();
        controller.addMessage(
          ChatMessage(
            'Hello. General there',
            speaker: 0,
            isFinal: true,
            groups: const [
              ChatMessageGroup(id: 'g1', original: 'Hello.'),
              ChatMessageGroup(id: 'g2', original: 'General'),
              ChatMessageGroup(id: 'g3', original: 'there'),
            ],
          ),
        );

        await pumpTestApp(
          tester,
          ChangeNotifierProvider<SpeechController>.value(
            value: controller,
            child: const ChatMessageList(),
          ),
        );

        expect(find.text('Hello.'), findsOneWidget);
        expect(find.text('General'), findsOneWidget);
        expect(find.text('there'), findsOneWidget);
        expect(find.text(', '), findsOneWidget);
        expect(find.text(' '), findsOneWidget);
      },
    );

    testWidgets('renders gradient animation for partial messages', (tester) async {
      final controller = TestSpeechController();
      controller.addMessage(ChatMessage('Streaming update', isFinal: false));

      await pumpTestApp(
        tester,
        ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const ChatMessageList(),
        ),
      );

      final textFinder = find.text('Streaming update');
      expect(textFinder, findsOneWidget);
      expect(find.text('Streaming update...'), findsNothing);
      expect(
        find.ancestor(of: textFinder, matching: find.byType(ShaderMask)),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 450));
      expect(textFinder, findsOneWidget);

      await tester.pump(const Duration(milliseconds: 450));
      expect(textFinder, findsOneWidget);
    });

    testWidgets(
      'partial opacity remains reduced until message becomes final',
      (tester) async {
        final controller = TestSpeechController();
        final message = ChatMessage('Stabilized preview', isFinal: false);
        controller.addMessage(message);

        await pumpTestApp(
          tester,
          ChangeNotifierProvider<SpeechController>.value(
            value: controller,
            child: const ChatMessageList(),
          ),
        );

        double currentOpacityFor(String plainText) {
          final textFinder = find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                ((widget.data == plainText) ||
                    (widget.data == null &&
                        widget.textSpan?.toPlainText() == plainText)),
          );
          expect(textFinder, findsOneWidget);

          final opacityAncestors = find
              .ancestor(of: textFinder, matching: find.byType(Opacity))
              .evaluate()
              .map((element) => element.widget)
              .whereType<Opacity>()
              .toList(growable: false);
          expect(opacityAncestors, isNotEmpty);
          return opacityAncestors.first.opacity;
        }

        expect(currentOpacityFor('Stabilized preview'), closeTo(0.7, 0.001));
        expect(find.text('Stabilized preview...'), findsNothing);

        await tester.pump(const Duration(milliseconds: 500));

        expect(currentOpacityFor('Stabilized preview'), closeTo(0.7, 0.001));

        message.isFinal = true;
        controller.notifyListeners();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.text('Stabilized preview'), findsOneWidget);
        expect(currentOpacityFor('Stabilized preview'), greaterThan(0.7));
      },
    );

    testWidgets('renders grouped translation partials with gradient text', (
      tester,
    ) async {
      final controller = TestSpeechController();
      controller.addMessage(
        ChatMessage(
          'hello there now',
          speaker: 0,
          isFinal: false,
          groups: const [
            ChatMessageGroup(id: 'g1', original: 'hello', translation: 'hola'),
            ChatMessageGroup(
              id: 'g2',
              original: 'there now',
              translation: 'alli ahora',
            ),
            ChatMessageGroup(id: 'g3', original: 'ignored', translation: ''),
          ],
        )..translation = 'hola alli ahora',
      );

      await pumpTestApp(
        tester,
        ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const ChatMessageList(),
        ),
      );

      expect(find.text('hola'), findsOneWidget);
      expect(find.text('alli ahora'), findsOneWidget);
      expect(find.text(', '), findsWidgets);
      expect(find.text('...'), findsNothing);
      expect(
        find.ancestor(
          of: find.text('alli ahora'),
          matching: find.byType(ShaderMask),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows jump button when scrolled away and jumps to latest', (
      tester,
    ) async {
      final controller = TestSpeechController();
      final messages = List.generate(
        30,
        (index) => ChatMessage('Message $index', isFinal: true),
      );
      for (final message in messages) {
        controller.addMessage(message);
      }

      await pumpTestApp(
        tester,
        SizedBox(
          height: 220,
          child: ChangeNotifierProvider<SpeechController>.value(
            value: controller,
            child: const ChatMessageList(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();

      controller.addMessage(ChatMessage('Newest message', isFinal: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Jump to latest'), findsOneWidget);

      await tester.tap(find.text('Jump to latest'));
      await tester.pumpAndSettle();

      expect(find.text('Jump to latest'), findsNothing);
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      final bottomGap =
          scrollable.position.maxScrollExtent - scrollable.position.pixels;
      expect(bottomGap, lessThan(25.0));
      expect(find.text('Newest message'), findsOneWidget);
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

      await pumpTestApp(
        tester,
        SizedBox(
          height: 220,
          child: ChangeNotifierProvider<SpeechController>.value(
            value: controller,
            child: const ChatMessageList(),
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
