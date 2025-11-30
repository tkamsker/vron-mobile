/// Authentication state for the app
///
/// Represents the current authentication status and user information
class AuthState {
  /// Whether the user is authenticated
  final bool isAuthenticated;

  /// Whether authentication is in progress
  final bool isLoading;

  /// Error message if authentication failed
  final String? error;

  /// User ID if authenticated
  final String? userId;

  /// User email if authenticated
  final String? userEmail;

  /// Access token (stored in secure storage, not in state)
  /// This is null here for security reasons

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.userId,
    this.userEmail,
  });

  /// Initial state (not authenticated, not loading)
  const AuthState.initial()
      : isAuthenticated = false,
        isLoading = false,
        error = null,
        userId = null,
        userEmail = null;

  /// Authenticated state
  const AuthState.authenticated({
    required this.userId,
    required this.userEmail,
  })  : isAuthenticated = true,
        isLoading = false,
        error = null;

  /// Loading state (authentication in progress)
  const AuthState.loading()
      : isAuthenticated = false,
        isLoading = true,
        error = null,
        userId = null,
        userEmail = null;

  /// Error state (authentication failed)
  const AuthState.error(String errorMessage)
      : isAuthenticated = false,
        isLoading = false,
        error = errorMessage,
        userId = null,
        userEmail = null;

  /// Unauthenticated state
  const AuthState.unauthenticated()
      : isAuthenticated = false,
        isLoading = false,
        error = null,
        userId = null,
        userEmail = null;

  /// Copy with modifications
  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    String? userId,
    String? userEmail,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AuthState &&
        other.isAuthenticated == isAuthenticated &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.userId == userId &&
        other.userEmail == userEmail;
  }

  @override
  int get hashCode {
    return Object.hash(
      isAuthenticated,
      isLoading,
      error,
      userId,
      userEmail,
    );
  }

  @override
  String toString() {
    return 'AuthState(isAuthenticated: $isAuthenticated, isLoading: $isLoading, error: $error, userId: $userId, userEmail: $userEmail)';
  }
}
