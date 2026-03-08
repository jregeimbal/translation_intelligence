import 'package:flutter_test/flutter_test.dart';
import 'package:translation_intelligence/services/audio_playback_queue.dart';

void main() {
  group('AudioPlaybackQueue', () {
    test('runs enqueued playback tasks sequentially', () async {
      final queue = AudioPlaybackQueue();
      final events = <String>[];

      final first = queue.enqueue(() async {
        events.add('start-1');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        events.add('end-1');
      });

      final second = queue.enqueue(() async {
        events.add('start-2');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        events.add('end-2');
      });

      final third = queue.enqueue(() async {
        events.add('start-3');
        events.add('end-3');
      });

      await Future.wait([first, second, third]);

      expect(
        events,
        equals(['start-1', 'end-1', 'start-2', 'end-2', 'start-3', 'end-3']),
      );
    });

    test('continues processing tasks after a playback error', () async {
      final queue = AudioPlaybackQueue();
      var didRunAfterFailure = false;

      await queue.enqueue(() async {
        throw StateError('playback failed');
      });

      await queue.enqueue(() async {
        didRunAfterFailure = true;
      });

      expect(didRunAfterFailure, isTrue);
    });
  });
}
