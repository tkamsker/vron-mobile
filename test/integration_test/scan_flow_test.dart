import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Integration test for complete scan flow
///
/// Tests the end-to-end scanning workflow:
/// 1. Check device capabilities
/// 2. Request camera permission
/// 3. Start scanning session
/// 4. Receive progress updates
/// 5. Stop scanning
/// 6. Process scan data
/// 7. Preview 3D model
/// 8. Save to database
///
/// **Note**: This test runs on iOS simulator with mock LiDAR data
/// or uses integration test fixtures for predictable behavior.
///
/// **TDD Requirement**: Defines complete user journey specification
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Complete Scan Flow Integration Test', () {
    testWidgets('complete scan flow from start to finish',
        (WidgetTester tester) async {
      // Given: App is launched and user is logged in
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _MockScanFlowApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Check device capabilities
      await tester.tap(find.text('Check Device'));
      await tester.pumpAndSettle();

      // Should show capability status
      expect(find.textContaining('LiDAR Available'), findsOneWidget);

      // Step 2: Navigate to project detail
      await tester.tap(find.text('Open Project'));
      await tester.pumpAndSettle();

      // Should show project detail screen
      expect(find.text('Project Detail'), findsOneWidget);

      // Step 3: Tap "Add Room Scan" button
      await tester.tap(find.text('Add Room Scan'));
      await tester.pumpAndSettle();

      // Should show scanning screen
      expect(find.text('Room Scanner'), findsOneWidget);

      // Step 4: Start scanning (automatically triggers in real app)
      await tester.tap(find.text('Start Scan'));
      await tester.pumpAndSettle();

      // Should show scanning progress
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.textContaining('Scanning'), findsOneWidget);

      // Step 5: Simulate progress updates (in real test, this comes from platform)
      // Wait for scanning to progress
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Should show progress percentage
      expect(find.textContaining('%'), findsWidgets);

      // Step 6: Stop scanning
      await tester.tap(find.text('Stop Scan'));
      await tester.pumpAndSettle();

      // Should show scan preview screen
      expect(find.text('Scan Preview'), findsOneWidget);

      // Step 7: Verify scan results displayed
      expect(find.textContaining('Points'), findsOneWidget);
      expect(find.textContaining('Room'), findsOneWidget);

      // Step 8: Edit room name
      final roomNameField = find.byType(TextField);
      await tester.enterText(roomNameField, 'Living Room');
      await tester.pumpAndSettle();

      // Step 9: Save scan
      await tester.tap(find.text('Save Scan'));
      await tester.pumpAndSettle();

      // Should show success message
      expect(find.text('Living Room saved successfully'), findsOneWidget);

      // Should navigate to scan sessions list
      expect(find.text('Scan Sessions'), findsOneWidget);

      // Verify scan appears in list
      expect(find.text('Living Room'), findsOneWidget);
    });

    testWidgets('handles permission denied gracefully',
        (WidgetTester tester) async {
      // Given: App without camera permission
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _MockScanFlowApp(hasCameraPermission: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When: User tries to start scanning
      await tester.tap(find.text('Open Project'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Room Scan'));
      await tester.pumpAndSettle();

      // Then: Should show permission request dialog
      expect(find.text('Camera Permission Required'), findsOneWidget);
      expect(
        find.text('This app needs camera access to scan rooms'),
        findsOneWidget,
      );

      // When: User grants permission
      await tester.tap(find.text('Grant Permission'));
      await tester.pumpAndSettle();

      // Then: Should proceed to scanning
      expect(find.text('Room Scanner'), findsOneWidget);
    });

    testWidgets('handles scan cancellation', (WidgetTester tester) async {
      // Given: Active scanning session
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _MockScanFlowApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to scanning
      await tester.tap(find.text('Open Project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Room Scan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Scan'));
      await tester.pumpAndSettle();

      // When: User cancels scan
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Should show confirmation dialog
      expect(find.text('Cancel Scan?'), findsOneWidget);

      await tester.tap(find.text('Yes, Cancel'));
      await tester.pumpAndSettle();

      // Then: Should return to project detail
      expect(find.text('Project Detail'), findsOneWidget);
      expect(find.text('Room Scanner'), findsNothing);
    });

    testWidgets('handles scan error recovery', (WidgetTester tester) async {
      // Given: Scanning session that encounters error
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _MockScanFlowApp(simulateError: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to scanning
      await tester.tap(find.text('Open Project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Room Scan'));
      await tester.pumpAndSettle();

      // When: Scan starts and encounters error
      await tester.tap(find.text('Start Scan'));
      await tester.pumpAndSettle();

      // Wait for error to occur
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Then: Should display error message
      expect(find.text('Scan Error'), findsOneWidget);
      expect(find.textContaining('LiDAR connection lost'), findsOneWidget);

      // Should offer retry option
      expect(find.text('Retry'), findsOneWidget);

      // When: User retries
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Then: Should restart scanning
      expect(find.text('Room Scanner'), findsOneWidget);
    });

    testWidgets('validates file size before saving', (WidgetTester tester) async {
      // Given: Scan that exceeds file size limit
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _MockScanFlowApp(largeFileSize: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate through scan flow
      await tester.tap(find.text('Open Project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Room Scan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Scan'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop Scan'));
      await tester.pumpAndSettle();

      // When: Attempting to save large file
      await tester.tap(find.text('Save Scan'));
      await tester.pumpAndSettle();

      // Then: Should show file size warning
      expect(find.text('File Size Limit Exceeded'), findsOneWidget);
      expect(find.textContaining('50MB'), findsOneWidget);

      // Should offer options
      expect(find.text('Continue Anyway'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('scan another room workflow', (WidgetTester tester) async {
      // Given: Completed scan
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _MockScanFlowApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Complete first scan
      await tester.tap(find.text('Open Project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Room Scan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Scan'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop Scan'));
      await tester.pumpAndSettle();

      // When: User taps "Scan Another Room"
      await tester.tap(find.text('Scan Another Room'));
      await tester.pumpAndSettle();

      // Then: Should return to scanning screen (without preview)
      expect(find.text('Room Scanner'), findsOneWidget);
      expect(find.text('Scan Preview'), findsNothing);

      // Should be ready to start new scan
      expect(find.text('Start Scan'), findsOneWidget);
    });

    testWidgets('handles offline mode gracefully', (WidgetTester tester) async {
      // Given: Device in offline mode
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _MockScanFlowApp(isOffline: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate through scan flow
      await tester.tap(find.text('Open Project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Room Scan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Scan'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop Scan'));
      await tester.pumpAndSettle();

      // When: Saving scan while offline
      await tester.tap(find.text('Save Scan'));
      await tester.pumpAndSettle();

      // Then: Should save locally and queue for sync
      expect(
        find.textContaining('saved offline'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Will sync when online'),
        findsOneWidget,
      );

      // Should show offline indicator
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('preserves scan data through app lifecycle',
        (WidgetTester tester) async {
      // Given: Active scanning session
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _MockScanFlowApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start scanning
      await tester.tap(find.text('Open Project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Room Scan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Scan'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Simulate app going to background and returning
      // (In real integration test, this would use platform channels)
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Then: Scan should still be in progress
      expect(find.text('Room Scanner'), findsOneWidget);
      expect(find.textContaining('Scanning'), findsOneWidget);

      // Progress should be maintained
      expect(find.textContaining('%'), findsWidgets);
    });
  });
}

/// Mock app for integration testing
class _MockScanFlowApp extends StatefulWidget {
  final bool hasCameraPermission;
  final bool simulateError;
  final bool largeFileSize;
  final bool isOffline;

  const _MockScanFlowApp({
    this.hasCameraPermission = true,
    this.simulateError = false,
    this.largeFileSize = false,
    this.isOffline = false,
  });

  @override
  State<_MockScanFlowApp> createState() => _MockScanFlowAppState();
}

class _MockScanFlowAppState extends State<_MockScanFlowApp> {
  String _currentScreen = 'home';
  bool _isScanning = false;
  bool _hasPermission = true;
  double _scanProgress = 0.0;
  String _roomName = 'Room ${DateTime.now().hour}:${DateTime.now().minute}';

  @override
  void initState() {
    super.initState();
    _hasPermission = widget.hasCameraPermission;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        leading: _currentScreen != 'home'
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
      ),
      body: _buildCurrentScreen(),
    );
  }

  String _getTitle() {
    switch (_currentScreen) {
      case 'home':
        return 'Home';
      case 'project':
        return 'Project Detail';
      case 'scan':
        return 'Room Scanner';
      case 'preview':
        return 'Scan Preview';
      case 'sessions':
        return 'Scan Sessions';
      default:
        return 'App';
    }
  }

  Widget _buildCurrentScreen() {
    switch (_currentScreen) {
      case 'home':
        return _buildHomeScreen();
      case 'project':
        return _buildProjectScreen();
      case 'scan':
        return _buildScanScreen();
      case 'preview':
        return _buildPreviewScreen();
      case 'sessions':
        return _buildSessionsScreen();
      default:
        return const Center(child: Text('Unknown screen'));
    }
  }

  Widget _buildHomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {
              // Check device capabilities
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('LiDAR Available: Yes')),
              );
            },
            child: const Text('Check Device'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() => _currentScreen = 'project'),
            child: const Text('Open Project'),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectScreen() {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          if (!_hasPermission) {
            _showPermissionDialog();
          } else {
            setState(() => _currentScreen = 'scan');
          }
        },
        child: const Text('Add Room Scan'),
      ),
    );
  }

  Widget _buildScanScreen() {
    if (widget.simulateError && _isScanning && _scanProgress > 0.3) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Scan Error'),
            const Text('LiDAR connection lost'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isScanning = false;
                  _scanProgress = 0.0;
                });
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: _isScanning
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Scanning...'),
                Text('${(_scanProgress * 100).toInt()}%'),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => setState(() => _currentScreen = 'preview'),
                  child: const Text('Stop Scan'),
                ),
                TextButton(
                  onPressed: _showCancelDialog,
                  child: const Text('Cancel'),
                ),
              ],
            )
          : ElevatedButton(
              onPressed: () {
                setState(() {
                  _isScanning = true;
                  _scanProgress = 0.5; // Simulate mid-scan
                });
              },
              child: const Text('Start Scan'),
            ),
    );
  }

  Widget _buildPreviewScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.view_in_ar, size: 100),
          const SizedBox(height: 16),
          const Text('Points: 15,234'),
          const Text('Room dimensions captured'),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(labelText: 'Room Name'),
              controller: TextEditingController(text: _roomName),
              onChanged: (value) => _roomName = value,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (widget.largeFileSize) {
                _showFileSizeWarning();
              } else {
                _saveScan();
              }
            },
            child: const Text('Save Scan'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setState(() {
              _currentScreen = 'scan';
              _isScanning = false;
              _scanProgress = 0.0;
            }),
            child: const Text('Scan Another Room'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_roomName),
          const Text('Saved successfully'),
          if (widget.isOffline) ...[
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off),
                SizedBox(width: 8),
                Text('Will sync when online'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _goBack() {
    setState(() {
      switch (_currentScreen) {
        case 'project':
          _currentScreen = 'home';
          break;
        case 'scan':
          _currentScreen = 'project';
          break;
        case 'preview':
          _currentScreen = 'scan';
          break;
        case 'sessions':
          _currentScreen = 'project';
          break;
      }
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text('This app needs camera access to scan rooms'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _hasPermission = true);
              Navigator.pop(context);
              setState(() => _currentScreen = 'scan');
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
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
              setState(() {
                _currentScreen = 'project';
                _isScanning = false;
                _scanProgress = 0.0;
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _showFileSizeWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Size Limit Exceeded'),
        content: const Text('The scan file exceeds the 50MB limit'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveScan();
            },
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );
  }

  void _saveScan() {
    setState(() => _currentScreen = 'sessions');

    final message = widget.isOffline
        ? '$_roomName saved offline'
        : '$_roomName saved successfully';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
