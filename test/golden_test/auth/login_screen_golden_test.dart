import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vron_mobile/core/auth/auth_notifier.dart';
import 'package:vron_mobile/core/auth/auth_state.dart';
import 'package:vron_mobile/features/auth/screens/login_screen.dart';

/// Golden tests for LoginScreen UI
///
/// Visual regression tests that capture screenshots and compare with baseline images.
///
/// Purpose:
/// - Ensure UI remains consistent across changes
/// - Detect unintended visual regressions
/// - Document expected visual appearance
///
/// Tests cover:
/// - Initial login screen state
/// - Loading state
/// - Error state
/// - Different screen sizes (phone, tablet)
/// - Light and dark themes
///
/// To update golden files:
/// ```
/// flutter test --update-goldens test/golden_test/auth/login_screen_golden_test.dart
/// ```
///
/// TDD RED PHASE: These tests will FAIL until LoginScreen is implemented
void main() {
  group('LoginScreen Golden Tests', () {
    testWidgets('should match golden file for initial state', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert - Compare with golden file
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_screen_initial.png'),
      );
    });

    testWidgets('should match golden file for loading state', (tester) async {
      // Arrange - Mock loading state
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

      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_screen_loading.png'),
      );
    });

    testWidgets('should match golden file for error state', (tester) async {
      // Arrange - Mock error state
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) {
              return MockAuthNotifier(
                const AuthState.unauthenticated(
                  error: 'Invalid credentials. Please try again.',
                ),
              );
            }),
          ],
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_screen_error.png'),
      );
    });

    testWidgets('should match golden file for dark theme', (tester) async {
      // Arrange - Dark theme
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_screen_dark_theme.png'),
      );
    });

    testWidgets('should match golden file for light theme', (tester) async {
      // Arrange - Light theme (default)
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.light(),
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_screen_light_theme.png'),
      );
    });

    testWidgets('should match golden file for small screen (phone)',
        (tester) async {
      // Arrange - Small phone screen (iPhone SE size)
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_screen_small_phone.png'),
      );

      // Cleanup
      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('should match golden file for large screen (tablet)',
        (tester) async {
      // Arrange - Tablet screen (iPad size)
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_screen_tablet.png'),
      );

      // Cleanup
      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('should match golden file with form validation errors',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - Trigger validation by tapping submit with empty fields
      final submitButton = find.byType(ElevatedButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Assert - Should show validation errors
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_screen_validation_errors.png'),
      );
    });

    testWidgets('should match golden file with filled form', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - Fill in credentials
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');

      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'SecurePassword123');

      await tester.pumpAndSettle();

      // Assert - Should show filled form
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_screen_filled_form.png'),
      );
    });

    testWidgets('should match golden file for landscape orientation',
        (tester) async {
      // Arrange - Landscape orientation
      tester.view.physicalSize = const Size(812, 375); // iPhone landscape
      tester.view.devicePixelRatio = 3.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_screen_landscape.png'),
      );

      // Cleanup
      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('should match golden file for accessibility large text',
        (tester) async {
      // Arrange - Large text size for accessibility
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaleFactor: 2.0),
              child: LoginScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('goldens/login_screen_large_text.png'),
      );
    });
  });
}

/// Mock AuthNotifier that returns a fixed state for golden tests
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
