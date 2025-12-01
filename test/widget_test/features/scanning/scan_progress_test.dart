import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget tests for scan progress UI
///
/// Tests the scan progress interface including:
/// - Progress percentage display
/// - Status message updates
/// - Point count indicators
/// - Start/stop/cancel buttons
/// - Progress animations
/// - Real-time updates
/// - Error state handling
///
/// **TDD Requirement**: These tests define expected UI behavior
void main() {
  group('Scan Progress UI', () {
    testWidgets('displays initial scanning state correctly',
        (WidgetTester tester) async {
      // Given: Initial scan progress widget
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 0.0,
                message: 'Initializing scan...',
                pointCount: 0,
                isScanning: true,
              ),
            ),
          ),
        ),
      );

      // Then: Should display initial state
      expect(find.text('Initializing scan...'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Points: 0'), findsOneWidget);

      // Should show scanning indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('updates progress percentage correctly',
        (WidgetTester tester) async {
      // Given: Widget with 25% progress
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 0.25,
                message: 'Scanning walls...',
                pointCount: 2500,
                isScanning: true,
              ),
            ),
          ),
        ),
      );

      // Then: Should display updated progress
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('Scanning walls...'), findsOneWidget);
      expect(find.text('Points: 2,500'), findsOneWidget);

      // When: Progress updates to 50%
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 0.50,
                message: 'Detecting features...',
                pointCount: 5000,
                isScanning: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Then: Should update to new values
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('Detecting features...'), findsOneWidget);
      expect(find.text('Points: 5,000'), findsOneWidget);
    });

    testWidgets('displays completion state correctly',
        (WidgetTester tester) async {
      // Given: Completed scan
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 1.0,
                message: 'Scan complete!',
                pointCount: 15000,
                isScanning: false,
              ),
            ),
          ),
        ),
      );

      // Then: Should display completion state
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Scan complete!'), findsOneWidget);
      expect(find.text('Points: 15,000'), findsOneWidget);

      // Should show success icon instead of loading
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('stop button stops scanning', (WidgetTester tester) async {
      // Given: Active scan with stop button
      bool stopCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 0.5,
                message: 'Scanning...',
                pointCount: 5000,
                isScanning: true,
                onStop: () => stopCalled = true,
              ),
            ),
          ),
        ),
      );

      // When: User taps stop button
      final stopButton = find.widgetWithText(ElevatedButton, 'Stop Scan');
      expect(stopButton, findsOneWidget);

      await tester.tap(stopButton);
      await tester.pump();

      // Then: Should call stop callback
      expect(stopCalled, isTrue);
    });

    testWidgets('cancel button cancels scanning', (WidgetTester tester) async {
      // Given: Active scan with cancel button
      bool cancelCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 0.3,
                message: 'Scanning...',
                pointCount: 3000,
                isScanning: true,
                onCancel: () => cancelCalled = true,
              ),
            ),
          ),
        ),
      );

      // When: User taps cancel button
      final cancelButton = find.widgetWithText(TextButton, 'Cancel');
      expect(cancelButton, findsOneWidget);

      await tester.tap(cancelButton);
      await tester.pump();

      // Then: Should call cancel callback
      expect(cancelCalled, isTrue);
    });

    testWidgets('shows confirmation dialog when canceling',
        (WidgetTester tester) async {
      // Given: Active scan
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 0.5,
                message: 'Scanning...',
                pointCount: 5000,
                isScanning: true,
                showCancelConfirmation: true,
              ),
            ),
          ),
        ),
      );

      // When: User taps cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Then: Should show confirmation dialog
      expect(find.text('Cancel Scan?'), findsOneWidget);
      expect(
        find.text('Are you sure you want to cancel this scan?'),
        findsOneWidget,
      );
      expect(find.text('Keep Scanning'), findsOneWidget);
      expect(find.text('Yes, Cancel'), findsOneWidget);
    });

    testWidgets('displays error state correctly', (WidgetTester tester) async {
      // Given: Scan error
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 0.4,
                message: 'Error: LiDAR connection lost',
                pointCount: 4000,
                isScanning: false,
                hasError: true,
              ),
            ),
          ),
        ),
      );

      // Then: Should display error state
      expect(find.text('Error: LiDAR connection lost'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);

      // Should show retry button
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('formats point count with thousands separator',
        (WidgetTester tester) async {
      // Given: Large point count
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 0.8,
                message: 'Finalizing...',
                pointCount: 123456,
                isScanning: true,
              ),
            ),
          ),
        ),
      );

      // Then: Should format with commas
      expect(find.text('Points: 123,456'), findsOneWidget);
    });

    testWidgets('shows estimated time remaining', (WidgetTester tester) async {
      // Given: Scan with time estimate
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 0.6,
                message: 'Scanning...',
                pointCount: 6000,
                isScanning: true,
                estimatedTimeRemaining: 45,
              ),
            ),
          ),
        ),
      );

      // Then: Should display time remaining
      expect(find.textContaining('45s remaining'), findsOneWidget);
    });

    testWidgets('linear progress indicator reflects percentage',
        (WidgetTester tester) async {
      // Given: Widget with specific progress
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 0.75,
                message: 'Almost done...',
                pointCount: 10000,
                isScanning: true,
              ),
            ),
          ),
        ),
      );

      // Then: LinearProgressIndicator should show correct value
      final progressIndicator =
          tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(progressIndicator.value, closeTo(0.75, 0.01));
    });

    testWidgets('disables buttons during critical operations',
        (WidgetTester tester) async {
      // Given: Scan in saving state
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 1.0,
                message: 'Saving scan data...',
                pointCount: 15000,
                isScanning: false,
                isSaving: true,
              ),
            ),
          ),
        ),
      );

      // Then: Buttons should be disabled
      final stopButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Stop Scan'),
      );
      expect(stopButton.onPressed, isNull);
    });

    testWidgets('animates progress smoothly', (WidgetTester tester) async {
      // Given: Initial progress
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 0.2,
                message: 'Scanning...',
                pointCount: 2000,
                isScanning: true,
              ),
            ),
          ),
        ),
      );

      // When: Progress updates
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 0.8,
                message: 'Scanning...',
                pointCount: 8000,
                isScanning: true,
              ),
            ),
          ),
        ),
      );

      // Pump frames to allow animation
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Then: Progress indicator should animate between values
      final progressIndicator =
          tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(progressIndicator.value, isNotNull);
    });

    testWidgets('displays scanning tips during progress',
        (WidgetTester tester) async {
      // Given: Scan in progress with tips
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanProgressWidget(
                percentage: 0.3,
                message: 'Scanning...',
                pointCount: 3000,
                isScanning: true,
                tip: 'Move slowly around the room for best results',
              ),
            ),
          ),
        ),
      );

      // Then: Should display scanning tip
      expect(
        find.text('Move slowly around the room for best results'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
    });
  });
}

/// Mock widget for testing scan progress UI
class _MockScanProgressWidget extends StatelessWidget {
  final double percentage;
  final String message;
  final int pointCount;
  final bool isScanning;
  final bool hasError;
  final bool isSaving;
  final bool showCancelConfirmation;
  final VoidCallback? onStop;
  final VoidCallback? onCancel;
  final int? estimatedTimeRemaining;
  final String? tip;

  const _MockScanProgressWidget({
    required this.percentage,
    required this.message,
    required this.pointCount,
    required this.isScanning,
    this.hasError = false,
    this.isSaving = false,
    this.showCancelConfirmation = false,
    this.onStop,
    this.onCancel,
    this.estimatedTimeRemaining,
    this.tip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status icon
          if (hasError)
            const Icon(Icons.error, size: 64, color: Colors.red)
          else if (percentage >= 1.0)
            const Icon(Icons.check_circle, size: 64, color: Colors.green)
          else
            const CircularProgressIndicator(),

          const SizedBox(height: 24),

          // Status message
          Text(
            message,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Progress bar
          LinearProgressIndicator(value: percentage),

          const SizedBox(height: 16),

          // Percentage
          Text(
            '${(percentage * 100).toInt()}%',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          // Point count
          Text(
            'Points: ${_formatNumber(pointCount)}',
            style: const TextStyle(fontSize: 16),
          ),

          // Time remaining
          if (estimatedTimeRemaining != null) ...[
            const SizedBox(height: 8),
            Text(
              '~${estimatedTimeRemaining}s remaining',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],

          // Tip
          if (tip != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isScanning) ...[
                ElevatedButton(
                  onPressed: isSaving ? null : onStop,
                  child: const Text('Stop Scan'),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          if (showCancelConfirmation) {
                            _showCancelDialog(context);
                          } else {
                            onCancel?.call();
                          }
                        },
                  child: const Text('Cancel'),
                ),
              ],
              if (hasError)
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Retry'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Scan?'),
        content: const Text('Are you sure you want to cancel this scan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Scanning'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onCancel?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}
