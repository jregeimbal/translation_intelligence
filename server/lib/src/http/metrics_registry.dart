class MetricsRegistry {
  int httpRequestsTotal = 0;
  int httpRateLimitedTotal = 0;
  int websocketSessionsStarted = 0;
  int websocketSessionsRejected = 0;
  int websocketSessionsCompleted = 0;
  int websocketAudioChunksTotal = 0;

  void recordHttpRequest() {
    httpRequestsTotal += 1;
  }

  void recordHttpRateLimited() {
    httpRateLimitedTotal += 1;
  }

  void recordWebSocketSessionStarted() {
    websocketSessionsStarted += 1;
  }

  void recordWebSocketSessionRejected() {
    websocketSessionsRejected += 1;
  }

  void recordWebSocketSessionCompleted() {
    websocketSessionsCompleted += 1;
  }

  void recordWebSocketAudioChunk() {
    websocketAudioChunksTotal += 1;
  }
}
