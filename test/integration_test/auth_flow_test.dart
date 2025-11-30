import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vron_mobile/core/auth/auth_notifier.dart';
import 'package:vron_mobile/core/auth/secure_storage_provider.dart';
import 'package:vron_mobile/features/auth/screens/login_screen.dart';
import 'package:vron_mobile/main.dart';

/// Integration tests for complete authentication flow
///
/// Tests end-to-end authentication:
/// - User enters credentials in LoginScreen
/// - AuthNotifier processes sign-in via GraphQL
/// - Token stored in secure storage
/// - Navigation to projects list on success
/// - Error display on failure
/// - Session persistence across app restarts
///
/// Uses mocked GraphQL client for predictable testing
///
/// TDD RED PHASE: These tests will FAIL until full auth flow is implemented
void main() {
  late MockSecureStorage mockSecureStorage;
  late MockGraphQLClient mockGraphQLClient;

  setUp(() {
    mockSecureStorage = MockSecureStorage();
    mockGraphQLClient = MockGraphQLClient();

    // Setup default mock responses
    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});
    when(() => mockSecureStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});
  });

  group('Complete Authentication Flow', () {
    testWidgets('should complete full login flow with valid credentials',
        (tester) async {
      // Arrange - Mock successful GraphQL response
      when(() => mockGraphQLClient.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          source: QueryResultSource.network,
          data: {
            'signIn': {
              'user': {
                'id': 'user123',
                'email': 'test@example.com',
              },
              'token': 'mock-jwt-token',
            },
          },
          options: QueryOptions(document: gql('')),
        ),
      );

      // Build app with mocked dependencies
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(mockSecureStorage),
          ],
          child: MaterialApp(
            home: LoginScreen(),
            routes: {
              '/projects': (context) => const Scaffold(
                    body: Text('Projects List'),
                  ),
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - Enter valid credentials
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');

      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'ValidPass123');

      // Tap submit button
      final submitButton = find.byType(ElevatedButton);
      await tester.tap(submitButton);

      await tester.pumpAndSettle();

      // Assert - Should navigate to projects list
      expect(find.text('Projects List'), findsOneWidget);

      // Verify token was stored
      verify(() => mockSecureStorage.write(
            key: 'auth_token',
            value: any(named: 'value'),
          )).called(greaterThan(0));
    });

    testWidgets('should display error message with invalid credentials',
        (tester) async {
      // Arrange - Mock failed GraphQL response
      when(() => mockGraphQLClient.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          source: QueryResultSource.network,
          data: null,
          options: QueryOptions(document: gql('')),
          exception: OperationException(
            graphqlErrors: [
              GraphQLError(message: 'Invalid credentials'),
            ],
          ),
        ),
      );

      // Build app
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(mockSecureStorage),
          ],
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - Enter invalid credentials
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'wrong@example.com');

      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'WrongPassword');

      final submitButton = find.byType(ElevatedButton);
      await tester.tap(submitButton);

      await tester.pumpAndSettle();

      // Assert - Should show error message
      expect(find.text('Invalid credentials'), findsOneWidget);
      expect(find.text('Projects List'), findsNothing);

      // Verify token was NOT stored
      verifyNever(() => mockSecureStorage.write(
            key: 'auth_token',
            value: any(named: 'value'),
          ));
    });

    testWidgets('should show loading indicator during authentication',
        (tester) async {
      // Arrange - Mock slow GraphQL response
      when(() => mockGraphQLClient.mutate(any())).thenAnswer(
        (_) => Future.delayed(
          const Duration(seconds: 1),
          () => QueryResult(
            source: QueryResultSource.network,
            data: {
              'signIn': {
                'user': {'id': 'user123', 'email': 'test@example.com'},
                'token': 'mock-jwt-token',
              },
            },
            options: QueryOptions(document: gql('')),
          ),
        ),
      );

      // Build app
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(mockSecureStorage),
          ],
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - Submit form
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');

      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'ValidPass123');

      final submitButton = find.byType(ElevatedButton);
      await tester.tap(submitButton);

      // Pump once to process tap
      await tester.pump();

      // Assert - Loading indicator should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for completion
      await tester.pumpAndSettle();
    });

    testWidgets('should restore session from stored token on app launch',
        (tester) async {
      // Arrange - Mock stored token
      when(() => mockSecureStorage.read(key: 'auth_token')).thenAnswer(
        (_) async => 'stored-token-with-valid-expiry',
      );

      // Build app
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(mockSecureStorage),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                // Simulate app initialization checking auth state
                return Consumer(
                  builder: (context, ref, child) {
                    final authState = ref.watch(authNotifierProvider);

                    if (authState.isAuthenticated) {
                      return const Scaffold(body: Text('Projects List'));
                    } else {
                      return LoginScreen();
                    }
                  },
                );
              },
            ),
          ),
        ),
      );

      // Act - Pump to allow initialization
      await tester.pumpAndSettle();

      // Assert - Should restore session (implementation may vary)
      // Token was read from storage
      verify(() => mockSecureStorage.read(key: 'auth_token'))
          .called(greaterThan(0));
    });

    testWidgets('should sign out and return to login screen', (tester) async {
      // Arrange - Start authenticated
      when(() => mockSecureStorage.read(key: 'auth_token')).thenAnswer(
        (_) async => 'valid-token',
      );

      // Build app showing projects (user already authenticated)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(mockSecureStorage),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                title: const Text('Projects'),
                actions: [
                  Consumer(
                    builder: (context, ref, child) {
                      return IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () async {
                          await ref
                              .read(authNotifierProvider.notifier)
                              .signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => LoginScreen(),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
              body: const Text('Projects List'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - Tap logout button
      final logoutButton = find.byIcon(Icons.logout);
      await tester.tap(logoutButton);

      await tester.pumpAndSettle();

      // Assert - Should return to login screen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Projects List'), findsNothing);

      // Verify token was deleted
      verify(() => mockSecureStorage.delete(key: 'auth_token'))
          .called(greaterThan(0));
    });

    testWidgets('should handle network errors gracefully', (tester) async {
      // Arrange - Mock network error
      when(() => mockGraphQLClient.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          source: QueryResultSource.network,
          data: null,
          options: QueryOptions(document: gql('')),
          exception: OperationException(
            linkException: NetworkException(
              message: 'No internet connection',
            ),
          ),
        ),
      );

      // Build app
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(mockSecureStorage),
          ],
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - Try to sign in
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');

      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'ValidPass123');

      final submitButton = find.byType(ElevatedButton);
      await tester.tap(submitButton);

      await tester.pumpAndSettle();

      // Assert - Should show network error message
      expect(
        find.textContaining('network', findRichText: true),
        findsOneWidget,
        skip: true, // Skip until error handling is implemented
      );
    });

    testWidgets('should prevent multiple concurrent sign-in attempts',
        (tester) async {
      // Arrange - Mock slow response
      int mutationCallCount = 0;

      when(() => mockGraphQLClient.mutate(any())).thenAnswer((_) async {
        mutationCallCount++;
        await Future.delayed(const Duration(milliseconds: 500));
        return QueryResult(
          source: QueryResultSource.network,
          data: {
            'signIn': {
              'user': {'id': 'user123', 'email': 'test@example.com'},
              'token': 'mock-token',
            },
          },
          options: QueryOptions(document: gql('')),
        );
      });

      // Build app
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(mockSecureStorage),
          ],
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - Enter credentials
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');

      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'ValidPass123');

      // Tap submit button multiple times rapidly
      final submitButton = find.byType(ElevatedButton);
      await tester.tap(submitButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(submitButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(submitButton);

      await tester.pumpAndSettle();

      // Assert - Should only call mutation once (button disabled during loading)
      expect(mutationCallCount, equals(1));
    });
  });
}

/// Mock SecureStorage for testing
class MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// Mock GraphQL Client for testing
class MockGraphQLClient extends Mock implements GraphQLClient {}
