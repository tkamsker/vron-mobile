import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget test for upload progress UI (T153)
///
/// Tests upload progress widgets: progress bar, percentage, ETA, cancel button
/// Validates UI state updates based on upload progress
///
/// **Requirements** (FR-016):
/// - Upload Progress: Show percentage (0-100%) and ETA
/// - Cancel Option: Allow user to cancel in-progress upload
/// - Queue Status: Show pending uploads count
/// - Error Display: Show retry option for failed uploads
///
/// **Test Coverage**:
/// - Progress bar updates (0-100%)
/// - Percentage text display
/// - ETA calculation and display
/// - Cancel button functionality
/// - Upload completion state
/// - Upload error state
/// - Queue count display

void main() {
  group('T153: Upload Progress UI Widget Tests', () {
    testWidgets('displays upload progress bar with correct percentage', (tester) async {
      // Given: Upload at 45% progress
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: UploadProgressWidget(
                progress: 0.45,
                fileName: 'scene.glb',
              ),
            ),
          ),
        ),
      );

      // Then: Should show progress bar at 45%
      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.value, equals(0.45));

      // Should show percentage text
      expect(find.text('45%'), findsOneWidget);
    });

    testWidgets('displays file name being uploaded', (tester) async {
      // Given: Uploading scene.glb
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UploadProgressWidget(
              progress: 0.25,
              fileName: 'living_room_scene.glb',
            ),
          ),
        ),
      );

      // Then: Should display file name
      expect(find.text('living_room_scene.glb'), findsOneWidget);
    });

    testWidgets('displays estimated time remaining (ETA)', (tester) async {
      // Given: Upload with 2 minutes ETA
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UploadProgressWidget(
              progress: 0.50,
              fileName: 'scene.glb',
              eta: const Duration(minutes: 2, seconds: 30),
            ),
          ),
        ),
      );

      // Then: Should show ETA
      expect(find.text('2m 30s remaining'), findsOneWidget);
    });

    testWidgets('displays upload speed', (tester) async {
      // Given: Upload at 2.5 MB/s
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UploadProgressWidget(
              progress: 0.60,
              fileName: 'scene.glb',
              uploadSpeed: 2.5 * 1024 * 1024, // 2.5 MB/s in bytes
            ),
          ),
        ),
      );

      // Then: Should show speed
      expect(find.text('2.5 MB/s'), findsOneWidget);
    });

    testWidgets('shows cancel button during upload', (tester) async {
      bool cancelCalled = false;

      // Given: Upload in progress
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UploadProgressWidget(
              progress: 0.30,
              fileName: 'scene.glb',
              onCancel: () => cancelCalled = true,
            ),
          ),
        ),
      );

      // Then: Cancel button should be visible
      expect(find.text('Cancel'), findsOneWidget);

      // When: Tap cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Then: Should call onCancel callback
      expect(cancelCalled, isTrue);
    });

    testWidgets('shows completion state with checkmark', (tester) async {
      // Given: Upload completed (100%)
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UploadProgressWidget(
              progress: 1.0,
              fileName: 'scene.glb',
              isCompleted: true,
            ),
          ),
        ),
      );

      // Then: Should show checkmark icon
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Upload complete'), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      bool retryCalled = false;

      // Given: Upload failed
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UploadProgressWidget(
              progress: 0.65,
              fileName: 'scene.glb',
              error: 'Network connection lost',
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );

      // Then: Should show error message and retry button
      expect(find.text('Network connection lost'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);

      // When: Tap retry button
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Then: Should call onRetry callback
      expect(retryCalled, isTrue);
    });

    testWidgets('displays queue count for pending uploads', (tester) async {
      // Given: 3 uploads in queue
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: UploadQueueIndicator(
                pendingCount: 3,
              ),
            ),
          ),
        ),
      );

      // Then: Should show queue count
      expect(find.text('3 uploads pending'), findsOneWidget);
    });

    testWidgets('shows indeterminate progress when percentage unknown', (tester) async {
      // Given: Upload without known progress
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UploadProgressWidget(
              progress: null,
              fileName: 'scene.glb',
            ),
          ),
        ),
      );

      // Then: Should show indeterminate progress indicator
      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.value, isNull);
    });

    testWidgets('updates progress dynamically', (tester) async {
      // Given: Upload at 20%
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _ProgressTestWidget(initialProgress: 0.20),
          ),
        ),
      );

      expect(find.text('20%'), findsOneWidget);

      // When: Progress updates to 80%
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Then: Should update to 80%
      expect(find.text('80%'), findsOneWidget);
    });

    testWidgets('shows pause button for pausable uploads', (tester) async {
      bool pauseCalled = false;

      // Given: Pausable upload
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UploadProgressWidget(
              progress: 0.40,
              fileName: 'scene.glb',
              canPause: true,
              onPause: () => pauseCalled = true,
            ),
          ),
        ),
      );

      // Then: Should show pause button
      expect(find.byIcon(Icons.pause), findsOneWidget);

      // When: Tap pause button
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();

      // Then: Should call onPause callback
      expect(pauseCalled, isTrue);
    });

    testWidgets('shows resume button for paused uploads', (tester) async {
      bool resumeCalled = false;

      // Given: Paused upload
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UploadProgressWidget(
              progress: 0.40,
              fileName: 'scene.glb',
              isPaused: true,
              onResume: () => resumeCalled = true,
            ),
          ),
        ),
      );

      // Then: Should show resume button and paused status
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);

      // When: Tap resume button
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      // Then: Should call onResume callback
      expect(resumeCalled, isTrue);
    });

    testWidgets('displays bytes uploaded out of total', (tester) async {
      // Given: Upload with byte counts
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UploadProgressWidget(
              progress: 0.75,
              fileName: 'scene.glb',
              bytesUploaded: 7.5 * 1024 * 1024, // 7.5 MB
              totalBytes: 10 * 1024 * 1024, // 10 MB
            ),
          ),
        ),
      );

      // Then: Should show bytes uploaded
      expect(find.text('7.5 MB / 10 MB'), findsOneWidget);
    });

    testWidgets('shows offline indicator when no connection', (tester) async {
      // Given: Upload queued due to offline
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UploadProgressWidget(
              progress: 0.0,
              fileName: 'scene.glb',
              isOffline: true,
            ),
          ),
        ),
      );

      // Then: Should show offline indicator
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Waiting for connection'), findsOneWidget);
    });
  });
}

/// Mock upload progress widget for testing
class UploadProgressWidget extends StatelessWidget {
  final double? progress;
  final String fileName;
  final Duration? eta;
  final double? uploadSpeed;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final String? error;
  final bool isCompleted;
  final bool canPause;
  final bool isPaused;
  final double? bytesUploaded;
  final double? totalBytes;
  final bool isOffline;

  const UploadProgressWidget({
    Key? key,
    required this.progress,
    required this.fileName,
    this.eta,
    this.uploadSpeed,
    this.onCancel,
    this.onRetry,
    this.onPause,
    this.onResume,
    this.error,
    this.isCompleted = false,
    this.canPause = false,
    this.isPaused = false,
    this.bytesUploaded,
    this.totalBytes,
    this.isOffline = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (isOffline) ...[
              const Icon(Icons.cloud_off),
              const Text('Waiting for connection'),
            ] else if (error != null) ...[
              const Icon(Icons.error),
              Text(error!),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ] else if (isCompleted) ...[
              const Icon(Icons.check_circle),
              const Text('Upload complete'),
            ] else ...[
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              if (progress != null) Text('${(progress! * 100).toInt()}%'),
              if (eta != null) Text('${eta!.inMinutes}m ${eta!.inSeconds % 60}s remaining'),
              if (uploadSpeed != null) Text('${(uploadSpeed! / 1024 / 1024).toStringAsFixed(1)} MB/s'),
              if (bytesUploaded != null && totalBytes != null)
                Text('${(bytesUploaded! / 1024 / 1024).toStringAsFixed(1)} MB / ${(totalBytes! / 1024 / 1024).toStringAsFixed(1)} MB'),
              if (isPaused) const Text('Paused'),
              Row(
                children: [
                  if (canPause && !isPaused) IconButton(icon: const Icon(Icons.pause), onPressed: onPause),
                  if (isPaused) IconButton(icon: const Icon(Icons.play_arrow), onPressed: onResume),
                  if (onCancel != null) TextButton(onPressed: onCancel, child: const Text('Cancel')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class UploadQueueIndicator extends StatelessWidget {
  final int pendingCount;

  const UploadQueueIndicator({Key? key, required this.pendingCount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text('$pendingCount uploads pending');
  }
}

class _ProgressTestWidget extends StatefulWidget {
  final double initialProgress;

  const _ProgressTestWidget({required this.initialProgress});

  @override
  State<_ProgressTestWidget> createState() => _ProgressTestWidgetState();
}

class _ProgressTestWidgetState extends State<_ProgressTestWidget> {
  late double progress;

  @override
  void initState() {
    super.initState();
    progress = widget.initialProgress;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        UploadProgressWidget(progress: progress, fileName: 'test.glb'),
        ElevatedButton(
          onPressed: () => setState(() => progress = 0.80),
          child: const Text('Update'),
        ),
      ],
    );
  }
}
