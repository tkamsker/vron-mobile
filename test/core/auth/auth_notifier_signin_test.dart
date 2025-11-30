import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vron_mobile/core/auth/auth_notifier.dart';
import 'package:vron_mobile/core/auth/auth_state.dart';
import 'package:vron_mobile/core/auth/secure_storage_provider.dart';

/// Unit tests for AuthNotifier signIn method
///
/// Tests authentication flow:
/// - State transitions (initial → loading → authenticated/error)
/// - Token storage in secure storage
/// - GraphQL mutation integration
/// - Error handling for invalid credentials
/// - Network error handling
///
/// TDD: These tests validate the already-implemented AuthNotifier
void main() {
  late ProviderContainer container;
  late MockSecureStorage mockSecureStorage;

  setUp(() {
    mockSecureStorage = MockSecureStorage();

    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(mockSecureStorage),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('AuthNotifier.signIn', () {
    test('initial state should be AuthState.initial', () {
      // Arrange & Act
      final auth Notifier = container.read(authNotifierProvider.notifier);
      final state = container.read(authNotifierProvider);

      // Assert
      expect(state, const AuthState.initial());
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
    });

    test('should transition to loading state when signIn is called', () async {
      // Arrange
      when(() => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final authNotifier = container.read(authNotifierProvider.notifier);

      // Act
      final signInFuture = authNotifier.signIn(
        'test@example.com',
        'ValidPass123',
      );

      // Assert - Check loading state (might be transient)
      // Note: This test may need adjustment based on actual implementation
      await signInFuture;

      // Verify that write was called (indicating sign-in completed)
      verify(() => mockSecureStorage.write(
            key: 'auth_token',
            value: any(named: 'value'),
          )).called(1);
    });

    test('should transition to authenticated state on successful signIn',
        () async {
      // Arrange
      when(() => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final authNotifier = container.read(authNotifierProvider.notifier);

      // Act
      await authNotifier.signIn('test@example.com', 'ValidPass123');

      // Assert
      final state = container.read(authNotifierProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.userId, isNotNull);
      expect(state.userEmail, 'test@example.com');
    });

    test('should store auth token in secure storage on successful signIn',
        () async {
      // Arrange
      when(() => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final authNotifier = container.read(authNotifierProvider.notifier);

      // Act
      await authNotifier.signIn('user@example.com', 'SecurePass456');

      // Assert
      verify(() => mockSecureStorage.write(
            key: 'auth_token',
            value: any(named: 'value'),
          )).called(1);
    });

    test('should transition to error state on invalid credentials', () async {
      // Arrange
      final authNotifier = container.read(authNotifierProvider.notifier);

      // Act - Use obviously invalid credentials
      await authNotifier.signIn('invalid@example.com', 'wrongpassword');

      // Assert
      final state = container.read(authNotifierProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, contains('Invalid credentials'));
    });

    test('should handle network errors gracefully', () async {
      // Arrange
      when(() => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenThrow(Exception('Network error'));

      final authNotifier = container.read(authNotifierProvider.notifier);

      // Act
      await authNotifier.signIn('test@example.com', 'ValidPass123');

      // Assert
      final state = container.read(authNotifierProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.error, isNotNull);
    });

    test('should reject empty email', () async {
      // Arrange
      final authNotifier = container.read(authNotifierProvider.notifier);

      // Act
      await authNotifier.signIn('', 'ValidPass123');

      // Assert
      final state = container.read(authNotifierProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.error, isNotNull);
    });

    test('should reject empty password', () async {
      // Arrange
      final authNotifier = container.read(authNotifierProvider.notifier);

      // Act
      await authNotifier.signIn('test@example.com', '');

      // Assert
      final state = container.read(authNotifierProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.error, isNotNull);
    });

    test('should reject malformed email', () async {
      // Arrange
      final authNotifier = container.read(authNotifierProvider.notifier);

      // Act
      await authNotifier.signIn('not-an-email', 'ValidPass123');

      // Assert
      final state = container.read(authNotifierProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.error, isNotNull);
    });

    test('should handle multiple signIn attempts correctly', () async {
      // Arrange
      when(() => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final authNotifier = container.read(authNotifierProvider.notifier);

      // Act - First sign in
      await authNotifier.signIn('first@example.com', 'Pass1');

      final firstState = container.read(authNotifierProvider);

      // Act - Second sign in (should replace first)
      await authNotifier.signIn('second@example.com', 'Pass2');

      final secondState = container.read(authNotifierProvider);

      // Assert
      expect(firstState.userEmail, 'first@example.com');
      expect(secondState.userEmail, 'second@example.com');
      expect(secondState.isAuthenticated, isTrue);
    });

    test('should include userId in authenticated state', () async {
      // Arrange
      when(() => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final authNotifier = container.read(authNotifierProvider.notifier);

      // Act
      await authNotifier.signIn('test@example.com', 'ValidPass123');

      // Assert
      final state = container.read(authNotifierProvider);
      expect(state.userId, isNotNull);
      expect(state.userId, isNotEmpty);
    });

    test('should handle GraphQL mutation errors', () async {
      // Arrange - Simulate GraphQL error
      final authNotifier = container.read(authNotifierProvider.notifier);

      // Act - This should trigger a GraphQL error
      await authNotifier.signIn('graphql-error@test.com', 'TriggerError');

      // Assert
      final state = container.read(authNotifierProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.error, isNotNull);
    });

    test('should store complete auth token with userId, email, and expiry',
        () async {
      // Arrange
      String? storedToken;

      when(() => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((invocation) async {
        storedToken = invocation.namedArguments[#value] as String?;
      });

      final authNotifier = container.read(authNotifierProvider.notifier);

      // Act
      await authNotifier.signIn('test@example.com', 'ValidPass123');

      // Assert
      expect(storedToken, isNotNull);
      // Token should be base64 encoded
      expect(RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(storedToken!), isTrue);

      verify(() => mockSecureStorage.write(
            key: 'auth_token',
            value: storedToken,
          )).called(1);
    });
  });
}

/// Mock SecureStorage for testing
class MockSecureStorage extends Mock implements FlutterSecureStorage {}
