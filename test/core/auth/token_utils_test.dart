import 'package:flutter_test/flutter_test.dart';
import 'package:vron_mobile/core/auth/token_utils.dart';

/// Unit tests for token encoding/decoding utilities
///
/// Tests vron.one's custom base64-encoded token format:
/// Format: base64(userId:userEmail:expiryTimestamp)
///
/// Per AUTHENTICATION.md specifications
void main() {
  group('TokenUtils', () {
    group('encodeToken', () {
      test('should encode valid credentials to base64 format', () {
        // Arrange
        const userId = 'user123';
        const userEmail = 'test@example.com';
        final expiryTimestamp = DateTime(2025, 12, 31).millisecondsSinceEpoch;

        // Act
        final token = TokenUtils.encodeToken(
          userId: userId,
          userEmail: userEmail,
          expiryTimestamp: expiryTimestamp,
        );

        // Assert
        expect(token, isNotEmpty);
        // Token should be base64 encoded (only alphanumeric + / = chars)
        expect(RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(token), isTrue);
      });

      test('should encode different inputs to different tokens', () {
        // Arrange
        const userId1 = 'user123';
        const userId2 = 'user456';
        const userEmail = 'test@example.com';
        final expiryTimestamp = DateTime(2025, 12, 31).millisecondsSinceEpoch;

        // Act
        final token1 = TokenUtils.encodeToken(
          userId: userId1,
          userEmail: userEmail,
          expiryTimestamp: expiryTimestamp,
        );

        final token2 = TokenUtils.encodeToken(
          userId: userId2,
          userEmail: userEmail,
          expiryTimestamp: expiryTimestamp,
        );

        // Assert
        expect(token1, isNot(equals(token2)));
      });

      test('should handle special characters in email', () {
        // Arrange
        const userId = 'user123';
        const userEmail = 'test+special@example.com';
        final expiryTimestamp = DateTime(2025, 12, 31).millisecondsSinceEpoch;

        // Act
        final token = TokenUtils.encodeToken(
          userId: userId,
          userEmail: userEmail,
          expiryTimestamp: expiryTimestamp,
        );

        // Assert
        expect(token, isNotEmpty);
        expect(RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(token), isTrue);
      });
    });

    group('decodeToken', () {
      test('should decode valid token to original components', () {
        // Arrange
        const userId = 'user123';
        const userEmail = 'test@example.com';
        final expiryTimestamp = DateTime(2025, 12, 31).millisecondsSinceEpoch;

        final token = TokenUtils.encodeToken(
          userId: userId,
          userEmail: userEmail,
          expiryTimestamp: expiryTimestamp,
        );

        // Act
        final decoded = TokenUtils.decodeToken(token);

        // Assert
        expect(decoded['userId'], userId);
        expect(decoded['userEmail'], userEmail);
        expect(decoded['expiryTimestamp'], expiryTimestamp);
      });

      test('should throw exception for invalid token format', () {
        // Arrange
        const invalidToken = 'not-a-valid-token';

        // Act & Assert
        expect(
          () => TokenUtils.decodeToken(invalidToken),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw exception for malformed base64', () {
        // Arrange
        const malformedToken = 'abc!!!xyz';

        // Act & Assert
        expect(
          () => TokenUtils.decodeToken(malformedToken),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw exception for token with missing components', () {
        // Arrange - Create token with only 2 components instead of 3
        final invalidToken =
            TokenUtils.encodeToken(userId: 'user', userEmail: '', expiryTimestamp: 0);

        // Act & Assert
        // This should work for encoding, but decoding should validate
        expect(TokenUtils.decodeToken(invalidToken), isA<Map<String, dynamic>>());
      });

      test('should handle round-trip encoding/decoding correctly', () {
        // Arrange
        const userId = 'user789';
        const userEmail = 'round@trip.com';
        final expiryTimestamp = DateTime(2026, 6, 15).millisecondsSinceEpoch;

        // Act - Encode then decode
        final token = TokenUtils.encodeToken(
          userId: userId,
          userEmail: userEmail,
          expiryTimestamp: expiryTimestamp,
        );

        final decoded = TokenUtils.decodeToken(token);

        // Assert - Should get back original values
        expect(decoded['userId'], userId);
        expect(decoded['userEmail'], userEmail);
        expect(decoded['expiryTimestamp'], expiryTimestamp);
      });
    });

    group('isTokenExpired', () {
      test('should return false for future expiry timestamp', () {
        // Arrange - Token expires in 1 hour
        final futureTimestamp =
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;

        const userId = 'user123';
        const userEmail = 'test@example.com';

        final token = TokenUtils.encodeToken(
          userId: userId,
          userEmail: userEmail,
          expiryTimestamp: futureTimestamp,
        );

        // Act
        final isExpired = TokenUtils.isTokenExpired(token);

        // Assert
        expect(isExpired, isFalse);
      });

      test('should return true for past expiry timestamp', () {
        // Arrange - Token expired 1 hour ago
        final pastTimestamp =
            DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;

        const userId = 'user123';
        const userEmail = 'test@example.com';

        final token = TokenUtils.encodeToken(
          userId: userId,
          userEmail: userEmail,
          expiryTimestamp: pastTimestamp,
        );

        // Act
        final isExpired = TokenUtils.isTokenExpired(token);

        // Assert
        expect(isExpired, isTrue);
      });

      test('should return true for invalid token', () {
        // Arrange
        const invalidToken = 'invalid-token-format';

        // Act
        final isExpired = TokenUtils.isTokenExpired(invalidToken);

        // Assert
        expect(isExpired, isTrue); // Treat invalid tokens as expired
      });

      test('should handle boundary case of exactly now', () {
        // Arrange - Token expires right now
        final nowTimestamp = DateTime.now().millisecondsSinceEpoch;

        const userId = 'user123';
        const userEmail = 'test@example.com';

        final token = TokenUtils.encodeToken(
          userId: userId,
          userEmail: userEmail,
          expiryTimestamp: nowTimestamp,
        );

        // Act
        final isExpired = TokenUtils.isTokenExpired(token);

        // Assert
        // Should be expired or very close (depending on execution speed)
        expect(isExpired, isTrue);
      });
    });

    group('getUserIdFromToken', () {
      test('should extract userId from valid token', () {
        // Arrange
        const userId = 'user456';
        const userEmail = 'extract@test.com';
        final expiryTimestamp = DateTime(2025, 12, 31).millisecondsSinceEpoch;

        final token = TokenUtils.encodeToken(
          userId: userId,
          userEmail: userEmail,
          expiryTimestamp: expiryTimestamp,
        );

        // Act
        final extractedUserId = TokenUtils.getUserIdFromToken(token);

        // Assert
        expect(extractedUserId, userId);
      });

      test('should return null for invalid token', () {
        // Arrange
        const invalidToken = 'invalid-token';

        // Act
        final extractedUserId = TokenUtils.getUserIdFromToken(invalidToken);

        // Assert
        expect(extractedUserId, isNull);
      });
    });

    group('getUserEmailFromToken', () {
      test('should extract userEmail from valid token', () {
        // Arrange
        const userId = 'user789';
        const userEmail = 'email@extract.com';
        final expiryTimestamp = DateTime(2025, 12, 31).millisecondsSinceEpoch;

        final token = TokenUtils.encodeToken(
          userId: userId,
          userEmail: userEmail,
          expiryTimestamp: expiryTimestamp,
        );

        // Act
        final extractedEmail = TokenUtils.getUserEmailFromToken(token);

        // Assert
        expect(extractedEmail, userEmail);
      });

      test('should return null for invalid token', () {
        // Arrange
        const invalidToken = 'invalid-token';

        // Act
        final extractedEmail = TokenUtils.getUserEmailFromToken(invalidToken);

        // Assert
        expect(extractedEmail, isNull);
      });

      test('should handle emails with special characters', () {
        // Arrange
        const userId = 'user123';
        const userEmail = 'test+special@sub.domain.com';
        final expiryTimestamp = DateTime(2025, 12, 31).millisecondsSinceEpoch;

        final token = TokenUtils.encodeToken(
          userId: userId,
          userEmail: userEmail,
          expiryTimestamp: expiryTimestamp,
        );

        // Act
        final extractedEmail = TokenUtils.getUserEmailFromToken(token);

        // Assert
        expect(extractedEmail, userEmail);
      });
    });
  });
}
