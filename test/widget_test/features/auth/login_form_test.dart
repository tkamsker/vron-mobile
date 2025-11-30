import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vron_mobile/features/auth/widgets/login_form.dart';

/// Widget tests for LoginForm validation
///
/// Tests validation logic for:
/// - Email field (required, valid email format)
/// - Password field (required, minimum length)
/// - Submit button enabled/disabled state
/// - Error message display
///
/// TDD RED PHASE: These tests will FAIL until LoginForm is implemented
void main() {
  group('LoginForm Widget Tests', () {
    testWidgets('should display email and password fields', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginForm(
              onSubmit: (email, password) {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('should show validation error for empty email', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginForm(
              onSubmit: (email, password) {},
            ),
          ),
        ),
      );

      // Act - Find submit button and tap it without filling fields
      final submitButton = find.byType(ElevatedButton);
      await tester.tap(submitButton);
      await tester.pump();

      // Assert
      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('should show validation error for invalid email format',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginForm(
              onSubmit: (email, password) {},
            ),
          ),
        ),
      );

      // Act - Enter invalid email
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'invalid-email');

      final submitButton = find.byType(ElevatedButton);
      await tester.tap(submitButton);
      await tester.pump();

      // Assert
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('should show validation error for empty password',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginForm(
              onSubmit: (email, password) {},
            ),
          ),
        ),
      );

      // Act - Enter valid email but no password
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');

      final submitButton = find.byType(ElevatedButton);
      await tester.tap(submitButton);
      await tester.pump();

      // Assert
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('should show validation error for short password',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginForm(
              onSubmit: (email, password) {},
            ),
          ),
        ),
      );

      // Act - Enter short password (less than 8 characters)
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');

      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'short');

      final submitButton = find.byType(ElevatedButton);
      await tester.tap(submitButton);
      await tester.pump();

      // Assert
      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
    });

    testWidgets('should call onSubmit with valid email and password',
        (tester) async {
      // Arrange
      String? submittedEmail;
      String? submittedPassword;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginForm(
              onSubmit: (email, password) {
                submittedEmail = email;
                submittedPassword = password;
              },
            ),
          ),
        ),
      );

      // Act - Enter valid credentials
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');

      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'ValidPass123');

      final submitButton = find.byType(ElevatedButton);
      await tester.tap(submitButton);
      await tester.pump();

      // Assert
      expect(submittedEmail, 'test@example.com');
      expect(submittedPassword, 'ValidPass123');
    });

    testWidgets('should disable submit button while loading', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginForm(
              onSubmit: (email, password) {},
              isLoading: true,
            ),
          ),
        ),
      );

      // Assert
      final submitButton =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('should show loading indicator when isLoading is true',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginForm(
              onSubmit: (email, password) {},
              isLoading: true,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should toggle password visibility', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginForm(
              onSubmit: (email, password) {},
            ),
          ),
        ),
      );

      // Act - Find password field
      final passwordField =
          tester.widget<TextFormField>(find.byType(TextFormField).last);

      // Initially password should be obscured
      expect(passwordField.obscureText, isTrue);

      // Tap visibility toggle button
      final visibilityToggle = find.byIcon(Icons.visibility);
      await tester.tap(visibilityToggle);
      await tester.pump();

      // After toggle, password should be visible
      final passwordFieldAfter =
          tester.widget<TextFormField>(find.byType(TextFormField).last);
      expect(passwordFieldAfter.obscureText, isFalse);

      // Tap again to hide
      final visibilityOffToggle = find.byIcon(Icons.visibility_off);
      await tester.tap(visibilityOffToggle);
      await tester.pump();

      // Should be obscured again
      final passwordFieldFinal =
          tester.widget<TextFormField>(find.byType(TextFormField).last);
      expect(passwordFieldFinal.obscureText, isTrue);
    });

    testWidgets('should display error message when provided', (tester) async {
      // Arrange
      const errorMessage = 'Invalid credentials';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginForm(
              onSubmit: (email, password) {},
              errorMessage: errorMessage,
            ),
          ),
        ),
      );

      // Assert
      expect(find.text(errorMessage), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
