import 'dart:async';

/// A timer-based debouncer that schedules a single-shot dispatch after a
/// configurable delay. Subsequent calls to [schedule] before the timer fires
/// reset the delay with the new message.
class DebouncedMessageDispatcher {
  DebouncedMessageDispatcher({required this.delay, required this.onDispatch});

  final Duration delay;
  final void Function(String message) onDispatch;

  Timer? _timer;
  String? _pendingMessage;

  /// Schedule [message] to be dispatched after [delay].
  /// If another message is already pending, the timer resets.
  void schedule(String message) {
    _pendingMessage = message;
    _timer?.cancel();
    _timer = Timer(delay, () {
      final pending = _pendingMessage;
      if (pending == null || pending.isEmpty) return;
      _pendingMessage = null;
      onDispatch(pending);
    });
  }

  /// Cancel any pending dispatch and release the timer.
  void dispose() {
    _timer?.cancel();
  }
}
