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

const authenticatedUserContextKey = 'authenticatedUser';
