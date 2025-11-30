import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// Secure storage provider for auth tokens
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

/// Logger provider for auth operations
final authLoggerProvider = Provider<Logger>((ref) {
  return Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );
});

/// Creates auth link that adds Authorization header with base64-encoded token
///
/// Token format per AUTHENTICATION.md:
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
/// Encoded as base64 and sent as: `Authorization: Bearer <AUTH_CODE>`
AuthLink createAuthLink(Ref ref) {
  final storage = ref.read(secureStorageProvider);
  final logger = ref.read(authLoggerProvider);

  return AuthLink(
    getToken: () async {
      try {
        // Read access token from secure storage
        final accessToken = await storage.read(key: 'access_token');

        if (accessToken == null || accessToken.isEmpty) {
          logger.d('No access token found in secure storage');
          return null;
        }

        // Construct AUTH_CODE per vron.one specification
        final authJson = {
          'MERCHANT': {
            'accessToken': accessToken,
          },
          'activeRoles': {
            'merchants': 'MERCHANT',
          },
        };

        // Base64 encode
        final authCode = base64Encode(
          utf8.encode(jsonEncode(authJson)),
        );

        logger.d('Auth token encoded successfully');
        return 'Bearer $authCode';
      } catch (e, stackTrace) {
        logger.e(
          'Failed to construct auth token',
          error: e,
          stackTrace: stackTrace,
        );
        return null;
      }
    },
  );
}

/// Decodes AUTH_CODE back to access token
///
/// Used for debugging and token validation
String? decodeAuthCode(String authCode) {
  try {
    // Remove "Bearer " prefix if present
    final code = authCode.startsWith('Bearer ')
        ? authCode.substring(7)
        : authCode;

    // Base64 decode
    final jsonString = utf8.decode(base64Decode(code));
    final authJson = jsonDecode(jsonString) as Map<String, dynamic>;

    // Extract access token
    final merchant = authJson['MERCHANT'] as Map<String, dynamic>?;
    return merchant?['accessToken'] as String?;
  } catch (e) {
    return null;
  }
}

/// Validates AUTH_CODE structure
///
/// Returns true if AUTH_CODE has correct format
bool isValidAuthCode(String authCode) {
  try {
    final code = authCode.startsWith('Bearer ')
        ? authCode.substring(7)
        : authCode;

    final jsonString = utf8.decode(base64Decode(code));
    final authJson = jsonDecode(jsonString) as Map<String, dynamic>;

    // Validate structure
    final merchant = authJson['MERCHANT'] as Map<String, dynamic>?;
    final accessToken = merchant?['accessToken'] as String?;
    final activeRoles = authJson['activeRoles'] as Map<String, dynamic>?;
    final merchantRole = activeRoles?['merchants'] as String?;

    return accessToken != null &&
        accessToken.isNotEmpty &&
        merchantRole == 'MERCHANT';
  } catch (e) {
    return false;
  }
}
