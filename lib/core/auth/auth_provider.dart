import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage provider for auth tokens
///
/// Uses platform-specific secure storage:
/// - iOS: Keychain
/// - Android: EncryptedSharedPreferences (KeyStore)
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
});

/// Secure storage keys
class SecureStorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String authCode = 'auth_code'; // Base64-encoded AUTH_CODE
}

/// Auth token manager
///
/// Handles reading/writing auth tokens to secure storage
class AuthTokenManager {
  final FlutterSecureStorage _storage;

  AuthTokenManager(this._storage);

  /// Save access token
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: SecureStorageKeys.accessToken, value: token);
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: SecureStorageKeys.accessToken);
  }

  /// Delete access token
  Future<void> deleteAccessToken() async {
    await _storage.delete(key: SecureStorageKeys.accessToken);
  }

  /// Save refresh token
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: SecureStorageKeys.refreshToken, value: token);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: SecureStorageKeys.refreshToken);
  }

  /// Delete refresh token
  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: SecureStorageKeys.refreshToken);
  }

  /// Save user ID
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: SecureStorageKeys.userId, value: userId);
  }

  /// Get user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: SecureStorageKeys.userId);
  }

  /// Save user email
  Future<void> saveUserEmail(String email) async {
    await _storage.write(key: SecureStorageKeys.userEmail, value: email);
  }

  /// Get user email
  Future<String?> getUserEmail() async {
    return await _storage.read(key: SecureStorageKeys.userEmail);
  }

  /// Save AUTH_CODE (base64-encoded)
  Future<void> saveAuthCode(String authCode) async {
    await _storage.write(key: SecureStorageKeys.authCode, value: authCode);
  }

  /// Get AUTH_CODE
  Future<String?> getAuthCode() async {
    return await _storage.read(key: SecureStorageKeys.authCode);
  }

  /// Clear all auth data
  Future<void> clearAll() async {
    await _storage.delete(key: SecureStorageKeys.accessToken);
    await _storage.delete(key: SecureStorageKeys.refreshToken);
    await _storage.delete(key: SecureStorageKeys.userId);
    await _storage.delete(key: SecureStorageKeys.userEmail);
    await _storage.delete(key: SecureStorageKeys.authCode);
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}

/// Auth token manager provider
final authTokenManagerProvider = Provider<AuthTokenManager>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return AuthTokenManager(storage);
});

/// Check if user is authenticated
final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final tokenManager = ref.watch(authTokenManagerProvider);
  return await tokenManager.isAuthenticated();
});
