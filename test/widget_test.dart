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
import 'package:translation_intelligence/models/chat_message.dart';
import 'package:translation_intelligence/widgets/footer.dart';

import 'speech_controller_stub.dart';
import 'test_app.dart';

void main() {
  testWidgets('SpeechFooter shows speakers and hide-original toggle', (
    tester,
  ) async {
    final controller = TestSpeechController();
    controller.addMessage(ChatMessage('Hello', speaker: 0));

    await pumpTestApp(
      tester,
      SizedBox(
        width: 1000,
        child: ChangeNotifierProvider<SpeechController>.value(
          value: controller,
          child: const SpeechFooter(),
        ),
      ),
    );

    expect(find.text('Primary Speaker'), findsOneWidget);
    expect(find.byTooltip('Hide translation original text'), findsOneWidget);

    final footerStack = tester.widget<Stack>(find.byType(Stack).first);
    expect(footerStack.alignment, Alignment.center);

    final leftAlignedRow = tester.widget<Align>(
      find.byWidgetPredicate(
        (widget) => widget is Align && widget.alignment == Alignment.centerLeft,
      ),
    );
    expect(leftAlignedRow.alignment, Alignment.centerLeft);

    final rightAlignedRow = tester.widget<Align>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Align && widget.alignment == Alignment.centerRight,
      ),
    );
    expect(rightAlignedRow.alignment, Alignment.centerRight);

    controller.setHideTranslatedOriginalText(false);
    await tester.pumpAndSettle();
    expect(controller.hideTranslatedOriginalText, isFalse);

    // Clear via controller to avoid overlay timing issues.
    controller.clearMessages();
    await tester.pumpAndSettle();

    expect(find.text('Primary speaker'), findsNothing);
  });
}
