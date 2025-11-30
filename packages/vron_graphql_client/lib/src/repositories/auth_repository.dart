import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../graphql_client_provider.dart';

/// Repository for authentication operations
///
/// Handles sign-in and sign-out mutations via GraphQL API
///
/// Methods:
/// - signIn: Authenticate user with email/password
/// - signOut: End current user session
///
/// Returns structured results with user data and auth tokens
class AuthRepository {
  final GraphQLClient _client;

  AuthRepository(this._client);

  /// Sign in with email and password
  ///
  /// Returns:
  /// - userId: Unique user identifier
  /// - userEmail: User's email address
  /// - token: JWT authentication token
  /// - expiresAt: Token expiration timestamp (milliseconds since epoch)
  ///
  /// Throws:
  /// - OperationException: On GraphQL errors or network failures
  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    const mutation = r'''
      mutation SignIn($email: String!, $password: String!) {
        signIn(input: { email: $email, password: $password }) {
          user {
            id
            email
            firstName
            lastName
            role
          }
          token
          expiresAt
        }
      }
    ''';

    final result = await _client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          'email': email,
          'password': password,
        },
        fetchPolicy: FetchPolicy.networkOnly, // Always fresh for auth
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final data = result.data?['signIn'];
    if (data == null) {
      throw Exception('Sign in failed: No data returned');
    }

    final user = data['user'];
    return SignInResult(
      userId: user['id'] as String,
      userEmail: user['email'] as String,
      firstName: user['firstName'] as String?,
      lastName: user['lastName'] as String?,
      role: user['role'] as String?,
      token: data['token'] as String,
      expiresAt: DateTime.parse(data['expiresAt'] as String),
    );
  }

  /// Sign out current user
  ///
  /// Returns:
  /// - success: Whether sign-out was successful
  /// - message: Optional success/error message
  ///
  /// Throws:
  /// - OperationException: On GraphQL errors or network failures
  ///
  /// Note: Even if server sign-out fails, client should clear local auth state
  Future<SignOutResult> signOut() async {
    const mutation = r'''
      mutation SignOut {
        signOut {
          success
          message
        }
      }
    ''';

    final result = await _client.mutate(
      MutationOptions(
        document: gql(mutation),
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      // Log error but don't throw - client should sign out regardless
      return SignOutResult(
        success: false,
        message: result.exception?.toString() ?? 'Sign out failed',
      );
    }

    final data = result.data?['signOut'];
    return SignOutResult(
      success: data?['success'] as bool? ?? true,
      message: data?['message'] as String?,
    );
  }
}

/// Result of sign-in operation
class SignInResult {
  final String userId;
  final String userEmail;
  final String? firstName;
  final String? lastName;
  final String? role;
  final String token;
  final DateTime expiresAt;

  const SignInResult({
    required this.userId,
    required this.userEmail,
    this.firstName,
    this.lastName,
    this.role,
    required this.token,
    required this.expiresAt,
  });

  @override
  String toString() {
    return 'SignInResult(userId: $userId, userEmail: $userEmail, '
        'token: ${token.substring(0, 10)}..., expiresAt: $expiresAt)';
  }
}

/// Result of sign-out operation
class SignOutResult {
  final bool success;
  final String? message;

  const SignOutResult({
    required this.success,
    this.message,
  });

  @override
  String toString() {
    return 'SignOutResult(success: $success, message: $message)';
  }
}

/// Provider for AuthRepository
///
/// Provides singleton instance with injected GraphQL client
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(graphQLClientProvider);
  return AuthRepository(client);
});
