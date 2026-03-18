import 'dart:collection';

class RateLimiter {
  RateLimiter({required this.window})
    : _eventsByKey = <String, Queue<DateTime>>{};

  final Duration window;
  final Map<String, Queue<DateTime>> _eventsByKey;

  bool allow(String key, int limit, DateTime now) {
    final queue = _eventsByKey.putIfAbsent(key, Queue<DateTime>.new);
    while (queue.isNotEmpty && now.difference(queue.first) >= window) {
      queue.removeFirst();
    }
    if (queue.length >= limit) {
      return false;
    }
    queue.addLast(now);
    return true;
  }
}
