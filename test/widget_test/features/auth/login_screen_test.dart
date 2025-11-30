import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vron_mobile/core/auth/auth_notifier.dart';
import 'package:vron_mobile/core/auth/auth_state.dart';
import 'package:vron_mobile/features/auth/screens/login_screen.dart';

/// Widget tests for LoginScreen UI
///
/// Tests UI components and user interactions:
/// - Screen layout and branding
/// - Integration with LoginForm
/// - Error display from AuthNotifier
/// - Navigation on successful authentication
/// - Loading state display
///
/// TDD RED PHASE: These tests will FAIL until LoginScreen is implemented
void main() {
  group('LoginScreen Widget Tests', () {
    testWidgets('should display app logo and branding', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Assert
      expect(find.text('VRON'), findsOneWidget);
      expect(find.text('Mobile Companion'), findsOneWidget);
    });

    testWidgets('should display LoginForm widget', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Assert - LoginForm should be present
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email + Password
      expect(find.byType(ElevatedButton), findsOneWidget); // Submit button
    });

    testWidgets('should display welcome message', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Assert
      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        find.text('Sign in with your vron.one account'),
        findsOneWidget,
      );
    });

    testWidgets('should display loading indicator during authentication',
        (tester) async {
      // Arrange - Create mock provider that returns loading state
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) {
              return MockAuthNotifier(const AuthState.loading());
            }),
          ],
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display error message from auth state',
        (tester) async {
      // Arrange - Create mock provider that returns error state
      const errorMessage = 'Invalid credentials';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) {
              return MockAuthNotifier(
                const AuthState.unauthenticated(
                  error: errorMessage,
                ),
              );
            }),
          ],
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Assert
      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('should call AuthNotifier.signIn when form is submitted',
        (tester) async {
      // Arrange
      bool signInCalled = false;
      String? calledEmail;
      String? calledPassword;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) {
              return MockAuthNotifierWithCallback(
                onSignIn: (email, password) {
                  signInCalled = true;
                  calledEmail = email;
                  calledPassword = password;
                },
              );
            }),
          ],
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Act - Fill form and submit
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');

      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'ValidPass123');

      final submitButton = find.byType(ElevatedButton);
      await tester.tap(submitButton);
      await tester.pump();

      // Assert
      expect(signInCalled, isTrue);
      expect(calledEmail, 'test@example.com');
      expect(calledPassword, 'ValidPass123');
    });

    testWidgets('should have sign-up link', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Assert
      expect(find.text("Don't have an account?"), findsOneWidget);
      expect(find.text('Sign up'), findsOneWidget);
    });

    testWidgets('should navigate to sign-up when sign-up link is tapped',
        (tester) async {
      // Arrange
      bool navigatedToSignUp = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
            routes: {
              '/signup': (context) {
                navigatedToSignUp = true;
                return const Scaffold(body: Text('Sign Up'));
              },
            },
          ),
        ),
      );

      // Act - Tap sign-up link
      final signUpLink = find.text('Sign up');
      await tester.tap(signUpLink);
      await tester.pumpAndSettle();

      // Assert
      expect(navigatedToSignUp, isTrue);
    });

    testWidgets('should have forgot password link', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Assert
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('should be scrollable for small screens', (tester) async {
      // Arrange - Set small screen size
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Assert - Should have scrollable widget
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Cleanup
      addTearDown(tester.view.resetPhysicalSize);
    });
  });
}

/// Mock AuthNotifier that returns a fixed state
class MockAuthNotifier extends AuthNotifier {
  final AuthState _state;

  MockAuthNotifier(this._state);

  @override
  AuthState build() => _state;

  @override
  Future<void> signIn(String email, String password) async {
    // Mock implementation
  }

  @override
  Future<void> signOut() async {
    // Mock implementation
  }

  @override
  Future<void> refresh() async {
    // Mock implementation
  }
}

/// Mock AuthNotifier with callback for testing sign-in calls
class MockAuthNotifierWithCallback extends AuthNotifier {
  final Function(String email, String password)? onSignIn;

  MockAuthNotifierWithCallback({this.onSignIn});

  @override
  AuthState build() => const AuthState.initial();

  @override
  Future<void> signIn(String email, String password) async {
    onSignIn?.call(email, password);
  }

  @override
  Future<void> signOut() async {
    // Mock implementation
  }

  @override
  Future<void> refresh() async {
    // Mock implementation
  }
}
