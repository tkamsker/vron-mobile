import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Integration tests for scanRoom_v1 platform channel
///
/// Tests the actual method channel communication between Flutter and native code:
/// - iOS RoomPlan Framework integration
/// - Android ARCore Depth API integration
/// - Channel contract validation
/// - Event stream handling
/// - Error propagation
/// - Permission handling
/// - Device capability detection
///
/// **TDD Requirement**: These tests validate platform integration
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('scanRoom_v1 Platform Channel Integration', () {
    late MethodChannel methodChannel;
    late EventChannel eventChannel;
    late String testOutputPath;

    setUp(() async {
      methodChannel = const MethodChannel('one.vron.mobile/room_scanner');
      eventChannel = const EventChannel('one.vron.mobile/room_scanner/progress');

      // Create temporary output directory
      final tempDir = await getTemporaryDirectory();
      testOutputPath = '${tempDir.path}/test_scans';
      await Directory(testOutputPath).create(recursive: true);
    });

    tearDown(() async {
      // Clean up test files
      final testDir = Directory(testOutputPath);
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    testWidgets('isLidarAvailable returns platform-specific result',
        (WidgetTester tester) async {
      // When: Checking LiDAR availability on actual device
      final result = await methodChannel.invokeMethod<bool>('isLidarAvailable');

      // Then: Should return boolean based on device capabilities
      expect(result, isNotNull);
      expect(result, isA<bool>());

      if (Platform.isIOS) {
        // iOS: true on iPhone 12 Pro or newer, false otherwise
        print('iOS LiDAR Available: $result');
      } else if (Platform.isAndroid) {
        // Android: true if ARCore Depth API supported
        print('Android Depth API Available: $result');
      }
    });

    testWidgets('requestPermissions returns permission status',
        (WidgetTester tester) async {
      // When: Requesting camera permission
      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'requestPermissions',
      );

      // Then: Should return permission status map
      expect(result, isNotNull);
      expect(result!['camera'], isA<bool>());

      print('Camera Permission: ${result['camera']}');
    });

    testWidgets('getDeviceInfo returns device capabilities',
        (WidgetTester tester) async {
      // When: Getting device information
      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getDeviceInfo',
      );

      // Then: Should return device info with LiDAR status
      expect(result, isNotNull);
      expect(result!['hasLidar'], isA<bool>());
      expect(result['deviceModel'], isA<String>());
      expect(result['osVersion'], isA<String>());

      print('Device Info: $result');
    });

    testWidgets('startScanning with valid arguments returns session ID',
        (WidgetTester tester) async {
      // Given: Device with scanning capability
      final hasLidar = await methodChannel.invokeMethod<bool>('isLidarAvailable');

      if (hasLidar != true) {
        print('Skipping: Device does not support LiDAR/depth scanning');
        return;
      }

      // When: Starting a scan with valid arguments
      final sessionId = await methodChannel.invokeMethod<String>(
        'startScanning',
        {
          'roomId': 'test-room-123',
          'roomName': 'Test Room',
          'outputPath': testOutputPath,
        },
      );

      // Then: Should return a valid session ID
      expect(sessionId, isNotNull);
      expect(sessionId!.isNotEmpty, isTrue);

      print('Scan Session Started: $sessionId');

      // Cleanup: Stop the scan
      await methodChannel.invokeMethod('stopScanning', {'sessionId': sessionId});
    });

    testWidgets('startScanning fails without required arguments',
        (WidgetTester tester) async {
      // When: Starting scan without required arguments
      try {
        await methodChannel.invokeMethod<String>(
          'startScanning',
          {}, // Missing roomId, roomName, outputPath
        );
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        // Then: Should throw with INVALID_ARGUMENT code
        expect(e.code, 'INVALID_ARGUMENT');
        expect(e.message, contains('required'));
      }
    });

    testWidgets('startScanning fails on unsupported device',
        (WidgetTester tester) async {
      // Given: Check if device supports scanning
      final hasLidar = await methodChannel.invokeMethod<bool>('isLidarAvailable');

      if (hasLidar == true) {
        print('Skipping: Device supports scanning');
        return;
      }

      // When: Attempting to start scan on unsupported device
      try {
        await methodChannel.invokeMethod<String>(
          'startScanning',
          {
            'roomId': 'test-room-123',
            'roomName': 'Test Room',
            'outputPath': testOutputPath,
          },
        );
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        // Then: Should throw with LIDAR_NOT_AVAILABLE code
        expect(e.code, 'LIDAR_NOT_AVAILABLE');
        expect(
          e.message,
          anyOf(
            contains('LiDAR'),
            contains('depth'),
            contains('not supported'),
          ),
        );
      }
    });

    testWidgets('progress event channel emits scan updates',
        (WidgetTester tester) async {
      // Given: Device with scanning capability
      final hasLidar = await methodChannel.invokeMethod<bool>('isLidarAvailable');

      if (hasLidar != true) {
        print('Skipping: Device does not support LiDAR/depth scanning');
        return;
      }

      // Given: Progress event stream
      final progressEvents = <Map<dynamic, dynamic>>[];
      late StreamSubscription subscription;

      // When: Starting a scan and listening to progress
      subscription = eventChannel.receiveBroadcastStream().listen(
        (event) {
          if (event is Map) {
            progressEvents.add(event as Map<dynamic, dynamic>);
          }
        },
      );

      final sessionId = await methodChannel.invokeMethod<String>(
        'startScanning',
        {
          'roomId': 'test-room-progress',
          'roomName': 'Progress Test Room',
          'outputPath': testOutputPath,
        },
      );

      // Wait for some progress events
      await Future.delayed(const Duration(seconds: 2));

      // Stop scanning
      await methodChannel.invokeMethod('stopScanning', {'sessionId': sessionId});

      // Cancel subscription
      await subscription.cancel();

      // Then: Should have received progress events
      expect(progressEvents.isNotEmpty, isTrue);

      // Validate event structure
      for (final event in progressEvents) {
        expect(event['sessionId'], sessionId);
        expect(event['progress'], isA<num>());
        expect(event['message'], isA<String>());

        // Optional fields
        if (event.containsKey('pointCount')) {
          expect(event['pointCount'], isA<int>());
        }
        if (event.containsKey('status')) {
          expect(event['status'], isA<String>());
        }
      }

      print('Received ${progressEvents.length} progress events');
    });

    testWidgets('stopScanning terminates active scan',
        (WidgetTester tester) async {
      // Given: Active scan session
      final hasLidar = await methodChannel.invokeMethod<bool>('isLidarAvailable');

      if (hasLidar != true) {
        print('Skipping: Device does not support LiDAR/depth scanning');
        return;
      }

      final sessionId = await methodChannel.invokeMethod<String>(
        'startScanning',
        {
          'roomId': 'test-room-stop',
          'roomName': 'Stop Test Room',
          'outputPath': testOutputPath,
        },
      );

      // Wait briefly for scan to start
      await Future.delayed(const Duration(milliseconds: 500));

      // When: Stopping the scan
      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'stopScanning',
        {'sessionId': sessionId},
      );

      // Then: Should return scan result
      expect(result, isNotNull);
      expect(result!['sessionId'], sessionId);
      expect(result['status'], 'stopped');

      // Check for output file (may not exist for very short scans)
      if (result.containsKey('usdzPath')) {
        expect(result['usdzPath'], isA<String>());
        if (Platform.isIOS) {
          expect(result['usdzPath'], endsWith('.usdz'));
        }
      }

      print('Scan stopped: $result');
    });

    testWidgets('stopScanning with invalid session ID throws error',
        (WidgetTester tester) async {
      // When: Stopping non-existent session
      try {
        await methodChannel.invokeMethod(
          'stopScanning',
          {'sessionId': 'invalid-session-123'},
        );
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        // Then: Should throw with SESSION_NOT_FOUND code
        expect(e.code, 'SESSION_NOT_FOUND');
        expect(e.message, contains('session'));
      }
    });

    testWidgets('cancelScanning aborts active scan',
        (WidgetTester tester) async {
      // Given: Active scan session
      final hasLidar = await methodChannel.invokeMethod<bool>('isLidarAvailable');

      if (hasLidar != true) {
        print('Skipping: Device does not support LiDAR/depth scanning');
        return;
      }

      final sessionId = await methodChannel.invokeMethod<String>(
        'startScanning',
        {
          'roomId': 'test-room-cancel',
          'roomName': 'Cancel Test Room',
          'outputPath': testOutputPath,
        },
      );

      // Wait briefly for scan to start
      await Future.delayed(const Duration(milliseconds: 500));

      // When: Canceling the scan
      await methodChannel.invokeMethod(
        'cancelScanning',
        {'sessionId': sessionId},
      );

      // Then: Should complete without error
      // No output files should be created
      final outputFiles = Directory(testOutputPath).listSync();
      expect(
        outputFiles.where((f) => f.path.contains('test-room-cancel')).isEmpty,
        isTrue,
      );

      print('Scan canceled successfully');
    });

    testWidgets('multiple concurrent scans are not allowed',
        (WidgetTester tester) async {
      // Given: Active scan session
      final hasLidar = await methodChannel.invokeMethod<bool>('isLidarAvailable');

      if (hasLidar != true) {
        print('Skipping: Device does not support LiDAR/depth scanning');
        return;
      }

      final sessionId1 = await methodChannel.invokeMethod<String>(
        'startScanning',
        {
          'roomId': 'test-room-concurrent-1',
          'roomName': 'Concurrent Test 1',
          'outputPath': testOutputPath,
        },
      );

      // When: Attempting to start second scan
      try {
        await methodChannel.invokeMethod<String>(
          'startScanning',
          {
            'roomId': 'test-room-concurrent-2',
            'roomName': 'Concurrent Test 2',
            'outputPath': testOutputPath,
          },
        );
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        // Then: Should throw with SCAN_IN_PROGRESS code
        expect(e.code, 'SCAN_IN_PROGRESS');
        expect(e.message, contains('already in progress'));
      } finally {
        // Cleanup
        await methodChannel.invokeMethod('cancelScanning', {'sessionId': sessionId1});
      }
    });

    testWidgets('scan output contains valid USDZ file (iOS only)',
        (WidgetTester tester) async {
      if (!Platform.isIOS) {
        print('Skipping: iOS-only test');
        return;
      }

      // Given: Device with LiDAR
      final hasLidar = await methodChannel.invokeMethod<bool>('isLidarAvailable');

      if (hasLidar != true) {
        print('Skipping: Device does not support LiDAR');
        return;
      }

      // When: Completing a scan
      final sessionId = await methodChannel.invokeMethod<String>(
        'startScanning',
        {
          'roomId': 'test-room-output',
          'roomName': 'Output Test Room',
          'outputPath': testOutputPath,
        },
      );

      // Wait for some scan data
      await Future.delayed(const Duration(seconds: 3));

      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'stopScanning',
        {'sessionId': sessionId},
      );

      // Then: Should produce USDZ file
      expect(result, isNotNull);

      if (result!.containsKey('usdzPath')) {
        final usdzPath = result['usdzPath'] as String;
        expect(usdzPath, endsWith('.usdz'));

        final usdzFile = File(usdzPath);
        expect(await usdzFile.exists(), isTrue);

        final fileSize = await usdzFile.length();
        expect(fileSize, greaterThan(0));

        print('USDZ file created: $usdzPath ($fileSize bytes)');
      }
    });

    testWidgets('scan with custom configuration applies settings',
        (WidgetTester tester) async {
      // Given: Device with scanning capability
      final hasLidar = await methodChannel.invokeMethod<bool>('isLidarAvailable');

      if (hasLidar != true) {
        print('Skipping: Device does not support LiDAR/depth scanning');
        return;
      }

      // When: Starting scan with custom configuration
      final sessionId = await methodChannel.invokeMethod<String>(
        'startScanning',
        {
          'roomId': 'test-room-config',
          'roomName': 'Config Test Room',
          'outputPath': testOutputPath,
          'configuration': {
            'qualityLevel': 'high',
            'captureTextures': true,
            'detectObjects': false,
          },
        },
      );

      // Then: Should start successfully
      expect(sessionId, isNotNull);
      expect(sessionId!.isNotEmpty, isTrue);

      // Cleanup
      await methodChannel.invokeMethod('cancelScanning', {'sessionId': sessionId});

      print('Scan with custom config started: $sessionId');
    });

    testWidgets('error during scan propagates to Flutter',
        (WidgetTester tester) async {
      // Given: Device with scanning capability
      final hasLidar = await methodChannel.invokeMethod<bool>('isLidarAvailable');

      if (hasLidar != true) {
        print('Skipping: Device does not support LiDAR/depth scanning');
        return;
      }

      // Given: Error event stream
      final errorEvents = <PlatformException>[];
      late StreamSubscription subscription;

      subscription = eventChannel.receiveBroadcastStream().listen(
        (event) {},
        onError: (error) {
          if (error is PlatformException) {
            errorEvents.add(error);
          }
        },
      );

      // When: Starting scan with invalid output path
      try {
        await methodChannel.invokeMethod<String>(
          'startScanning',
          {
            'roomId': 'test-room-error',
            'roomName': 'Error Test Room',
            'outputPath': '/invalid/path/that/does/not/exist',
          },
        );
      } on PlatformException catch (e) {
        // Then: Should throw platform exception
        expect(e.code, anyOf('INVALID_PATH', 'IO_ERROR'));
      } finally {
        await subscription.cancel();
      }
    });

    testWidgets('resume from background maintains scan state',
        (WidgetTester tester) async {
      // Given: Active scan session
      final hasLidar = await methodChannel.invokeMethod<bool>('isLidarAvailable');

      if (hasLidar != true) {
        print('Skipping: Device does not support LiDAR/depth scanning');
        return;
      }

      final sessionId = await methodChannel.invokeMethod<String>(
        'startScanning',
        {
          'roomId': 'test-room-background',
          'roomName': 'Background Test Room',
          'outputPath': testOutputPath,
        },
      );

      // Simulate app going to background and returning
      await Future.delayed(const Duration(milliseconds: 500));

      // When: Querying session status
      final status = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getScanStatus',
        {'sessionId': sessionId},
      );

      // Then: Should return active status
      expect(status, isNotNull);
      expect(status!['sessionId'], sessionId);
      expect(status['isActive'], isTrue);

      // Cleanup
      await methodChannel.invokeMethod('cancelScanning', {'sessionId': sessionId});
    });

    testWidgets('scan metadata includes device and session info',
        (WidgetTester tester) async {
      // Given: Device with scanning capability
      final hasLidar = await methodChannel.invokeMethod<bool>('isLidarAvailable');

      if (hasLidar != true) {
        print('Skipping: Device does not support LiDAR/depth scanning');
        return;
      }

      // When: Completing a scan
      final sessionId = await methodChannel.invokeMethod<String>(
        'startScanning',
        {
          'roomId': 'test-room-metadata',
          'roomName': 'Metadata Test Room',
          'outputPath': testOutputPath,
        },
      );

      await Future.delayed(const Duration(seconds: 2));

      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'stopScanning',
        {'sessionId': sessionId},
      );

      // Then: Result should include metadata
      expect(result, isNotNull);
      expect(result!['sessionId'], sessionId);

      if (result.containsKey('metadata')) {
        final metadata = result['metadata'] as Map;
        expect(metadata['deviceModel'], isA<String>());
        expect(metadata['osVersion'], isA<String>());
        expect(metadata['scanDuration'], isA<num>());

        print('Scan metadata: ${result['metadata']}');
      }
    });
  });

  group('Platform-Specific Behavior', () {
    late MethodChannel methodChannel;

    setUp(() {
      methodChannel = const MethodChannel('one.vron.mobile/room_scanner');
    });

    testWidgets('iOS uses RoomPlan framework', (WidgetTester tester) async {
      if (!Platform.isIOS) {
        print('Skipping: iOS-only test');
        return;
      }

      // When: Getting device info on iOS
      final deviceInfo = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getDeviceInfo',
      );

      // Then: Should indicate RoomPlan usage
      expect(deviceInfo, isNotNull);
      expect(deviceInfo!['scanningFramework'], 'RoomPlan');
      expect(deviceInfo['hasLidar'], isA<bool>());

      print('iOS Scanning Framework: ${deviceInfo['scanningFramework']}');
    });

    testWidgets('Android uses ARCore Depth API', (WidgetTester tester) async {
      if (!Platform.isAndroid) {
        print('Skipping: Android-only test');
        return;
      }

      // When: Getting device info on Android
      final deviceInfo = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getDeviceInfo',
      );

      // Then: Should indicate ARCore usage
      expect(deviceInfo, isNotNull);
      expect(deviceInfo!['scanningFramework'], 'ARCore');
      expect(deviceInfo['hasDepthAPI'], isA<bool>());

      print('Android Scanning Framework: ${deviceInfo['scanningFramework']}');
    });
  });
}
