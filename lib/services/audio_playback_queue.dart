import 'dart:async';

class AudioPlaybackQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> enqueue(Future<void> Function() playbackTask) {
    _tail = _tail
        .catchError((_) {})
        .then((_) => playbackTask())
        .catchError((_) {});

    return _tail;
  }
}