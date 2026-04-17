import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/widgets/debounced_message_dispatcher.dart';

void main() {
  test(
    'DebouncedMessageDispatcher dispatches only the latest queued message',
    () async {
      final received = <String>[];
      final dispatcher = DebouncedMessageDispatcher(
        delay: const Duration(milliseconds: 50),
        onDispatch: received.add,
      );

      dispatcher.schedule('first');
      dispatcher.schedule('second');
      dispatcher.schedule('third');

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(received, equals(['third']));

      dispatcher.dispose();
    },
  );

  test(
    'DebouncedMessageDispatcher can dispatch successive messages over time',
    () async {
      final received = <String>[];
      final dispatcher = DebouncedMessageDispatcher(
        delay: const Duration(milliseconds: 40),
        onDispatch: received.add,
      );

      dispatcher.schedule('one');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      dispatcher.schedule('two');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(received, equals(['one', 'two']));

      dispatcher.dispose();
    },
  );
}
