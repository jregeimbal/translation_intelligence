class AuthenticatedUser {
  const AuthenticatedUser({
    required this.uid,
    required this.issuer,
    required this.audience,
  });

  final String uid;
  final String issuer;
  final String audience;
}

class RequestTraceContext {
  const RequestTraceContext({
    required this.requestId,
    required this.traceId,
    required this.clientIp,
  });

  final String requestId;
  final String? traceId;
  final String clientIp;
}

const authenticatedUserContextKey = 'authenticatedUser';
const requestTraceContextKey = 'requestTraceContext';
