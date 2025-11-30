import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:vron_graphql_client/vron_graphql_client.dart';
import 'auth_state.dart';
import 'auth_provider.dart';
import '../cache/cache_manager.dart';
import '../database/database_provider.dart';

/// Sign in input
class SignInInput {
  final String email;
  final String password;

  const SignInInput({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

/// Auth notifier - Manages authentication state
///
/// Handles:
/// - Sign in with email/password
/// - Sign out
/// - Token refresh
/// - Auth state persistence
class AuthNotifier extends StateNotifier<AuthState> {
  final GraphQLClient _graphqlClient;
  final AuthTokenManager _tokenManager;
  final CacheManager _cacheManager;
  final DatabaseOperations _dbOps;

  AuthNotifier(
    this._graphqlClient,
    this._tokenManager,
    this._cacheManager,
    this._dbOps,
  ) : super(const AuthState.initial()) {
    // Check if user is already authenticated on initialization
    _checkAuthStatus();
  }

  /// Check authentication status on app startup
  Future<void> _checkAuthStatus() async {
    try {
      final isAuth = await _tokenManager.isAuthenticated();

      if (isAuth) {
        final userId = await _tokenManager.getUserId();
        final userEmail = await _tokenManager.getUserEmail();

        if (userId != null && userEmail != null) {
          state = AuthState.authenticated(
            userId: userId,
            userEmail: userEmail,
          );
        } else {
          // Invalid auth state, clear tokens
          await _tokenManager.clearAll();
          state = const AuthState.unauthenticated();
        }
      } else {
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      state = const AuthState.unauthenticated();
    }
  }

  /// Sign in with email and password
  ///
  /// Makes GraphQL mutation to authenticate user and stores tokens
  Future<void> signIn(String email, String password) async {
    try {
      state = const AuthState.loading();

      // GraphQL sign in mutation
      const signInMutation = '''
        mutation SignIn(\$input: SignInInput!) {
          signIn(input: \$input) {
            accessToken
          }
        }
      ''';

      final result = await _graphqlClient.mutate(
        MutationOptions(
          document: gql(signInMutation),
          variables: {
            'input': {
              'email': email,
              'password': password,
            }
          },
        ),
      );

      if (result.hasException) {
        final errorMessage = _extractErrorMessage(result.exception);
        state = AuthState.error(errorMessage);
        return;
      }

      final data = result.data;
      if (data == null) {
        state = const AuthState.error('No data returned from sign in');
        return;
      }

      // Extract access token
      final signInData = data['signIn'] as Map<String, dynamic>?;
      final accessToken = signInData?['accessToken'] as String?;

      if (accessToken == null || accessToken.isEmpty) {
        state = const AuthState.error('Invalid access token');
        return;
      }

      // Save access token
      await _tokenManager.saveAccessToken(accessToken);
      await _tokenManager.saveUserEmail(email);

      // Generate and save AUTH_CODE
      final authCode = _generateAuthCode(accessToken);
      await _tokenManager.saveAuthCode(authCode);

      // For now, use email as user ID (should be extracted from token in production)
      final userId = email; // TODO: Extract from JWT token
      await _tokenManager.saveUserId(userId);

      state = AuthState.authenticated(
        userId: userId,
        userEmail: email,
      );
    } catch (e) {
      state = AuthState.error('Sign in failed: ${e.toString()}');
    }
  }

  /// Sign out
  ///
  /// Makes GraphQL mutation to invalidate token on server
  /// and clears local tokens and cache
  Future<void> signOut() async {
    try {
      state = const AuthState.loading();

      // GraphQL sign out mutation
      const signOutMutation = '''
        mutation SignOut {
          signOut
        }
      ''';

      // Attempt to sign out on server (ignore errors)
      try {
        await _graphqlClient.mutate(
          MutationOptions(
            document: gql(signOutMutation),
          ),
        );
      } catch (e) {
        // Ignore server sign out errors
      }

      // Clear local tokens
      await _tokenManager.clearAll();

      // Clear caches
      await _cacheManager.clearAll();
      await _dbOps.clearAllCache();

      state = const AuthState.unauthenticated();
    } catch (e) {
      // Even if sign out fails, clear local data
      await _tokenManager.clearAll();
      state = const AuthState.unauthenticated();
    }
  }

  /// Refresh authentication token
  ///
  /// Note: Current API doesn't have refresh token endpoint
  /// This is a placeholder for future implementation
  Future<void> refreshToken() async {
    try {
      // TODO: Implement token refresh when API supports it
      // For now, just check if token is still valid
      final isAuth = await _tokenManager.isAuthenticated();

      if (!isAuth) {
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      state = const AuthState.unauthenticated();
    }
  }

  /// Generate AUTH_CODE from access token
  ///
  /// Format per vron.one specification:
  /// ```json
  /// {
  ///   "MERCHANT": {
  ///     "accessToken": "<ACCESS_TOKEN>"
  ///   },
  ///   "activeRoles": {
  ///     "merchants": "MERCHANT"
  ///   }
  /// }
  /// ```
  String _generateAuthCode(String accessToken) {
    final authJson = {
      'MERCHANT': {
        'accessToken': accessToken,
      },
      'activeRoles': {
        'merchants': 'MERCHANT',
      },
    };

    return base64Encode(utf8.encode(jsonEncode(authJson)));
  }

  /// Extract error message from GraphQL exception
  String _extractErrorMessage(OperationException? exception) {
    if (exception == null) return 'Unknown error';

    if (exception.graphqlErrors.isNotEmpty) {
      final error = exception.graphqlErrors.first;
      final message = error.message;

      // Extract error code from extensions if available
      final extensions = error.extensions;
      if (extensions != null && extensions['code'] != null) {
        final code = extensions['code'];
        return '$message (Code: $code)';
      }

      return message;
    }

    if (exception.linkException != null) {
      return 'Network error: ${exception.linkException.toString()}';
    }

    return 'Unknown error occurred';
  }
}

/// Auth notifier provider
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final graphqlClient = ref.watch(graphqlClientProvider);
  final tokenManager = ref.watch(authTokenManagerProvider);
  final cacheManager = ref.watch(cacheManagerProvider);
  final dbOps = ref.watch(databaseOperationsProvider);

  return AuthNotifier(
    graphqlClient,
    tokenManager,
    cacheManager,
    dbOps,
  );
});

/// Convenience provider for auth state
final authStateProvider = Provider<AuthState>((ref) {
  return ref.watch(authNotifierProvider);
});

/// Convenience provider for checking if authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).isAuthenticated;
});
