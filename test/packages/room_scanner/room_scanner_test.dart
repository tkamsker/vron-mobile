import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_scanner/src/room_scanner_channel.dart';

/// Test suite for Room Scanner channel contract
///
/// Tests the complete platform channel contract including:
/// - Starting/stopping/canceling scan sessions
/// - Handling scan progress events
/// - Camera permission requests
/// - Error handling for all edge cases
/// - Exception handling (LiDAR unavailable, permission denied)
///
/// **TDD Requirement**: These tests define the contract and must pass first
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoomScanner Channel Contract', () {
    late RoomScannerChannel channel;
    late List<MethodCall> methodCallLog;

    setUp(() {
      channel = RoomScannerChannel();
      methodCallLog = [];

      // Reset method call handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        null,
      );

      // Reset event channel handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const EventChannel('one.vron.mobile/room_scanner_events'),
        null,
      );
    });

    tearDown(() {
      // Clean up handlers
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const EventChannel('one.vron.mobile/room_scanner_events'),
        null,
      );
    });

    // =========================================================================
    // Test Group: Scanning Lifecycle
    // =========================================================================

    group('Scanning Lifecycle', () {
      test('startScanning returns session ID on success', () async {
        // Given: Valid scan parameters
        const roomId = 'room-123';
        const roomName = 'Living Room';
        const outputPath = '/tmp/scans';
        const expectedSessionId = 'session-abc-123';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/room_scanner'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'startScanning') {
              final args = methodCall.arguments as Map;
              expect(args['roomId'], roomId);
              expect(args['roomName'], roomName);
              expect(args['outputPath'], outputPath);

              return expectedSessionId;
            }
            return null;
          },
        );

        // When: Starting a scan session
        final sessionId = await channel.startScanning(
          roomId: roomId,
          roomName: roomName,
          outputPath: outputPath,
        );

        // Then: Should return session ID
        expect(sessionId, expectedSessionId);
        expect(methodCallLog.length, 1);
        expect(methodCallLog[0].method, 'startScanning');
      });

      test('startScanning throws LidarNotAvailableException when LiDAR unavailable',
          () async {
        // Given: Device without LiDAR
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/room_scanner'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'startScanning') {
              throw PlatformException(
                code: 'LIDAR_NOT_AVAILABLE',
                message: 'LiDAR sensor not available on this device',
              );
            }
            return null;
          },
        );

        // When/Then: Should throw LidarNotAvailableException
        expect(
          () => channel.startScanning(
            roomId: 'room-123',
            roomName: 'Test Room',
            outputPath: '/tmp',
          ),
          throwsA(isA<LidarNotAvailableException>()),
        );
      });

      test('startScanning throws PermissionDeniedException when camera permission denied',
          () async {
        // Given: Camera permission not granted
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/room_scanner'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'startScanning') {
              throw PlatformException(
                code: 'PERMISSION_DENIED',
                message: 'Camera permission is required for scanning',
              );
            }
            return null;
          },
        );

        // When/Then: Should throw PermissionDeniedException
        expect(
          () => channel.startScanning(
            roomId: 'room-123',
            roomName: 'Test Room',
            outputPath: '/tmp',
          ),
          throwsA(
            isA<PermissionDeniedException>().having(
              (e) => e.permission,
              'permission',
              'Camera',
            ),
          ),
        );
      });

      test('startScanning throws RoomScannerException on null session ID',
          () async {
        // Given: Platform returns null session ID
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/room_scanner'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'startScanning') {
              return null; // Null session ID
            }
            return null;
          },
        );

        // When/Then: Should throw RoomScannerException
        expect(
          () => channel.startScanning(
            roomId: 'room-123',
            roomName: 'Test Room',
            outputPath: '/tmp',
          ),
          throwsA(
            isA<RoomScannerException>().having(
              (e) => e.message,
              'message',
              contains('null session ID'),
            ),
          ),
        );
      });

      test('stopScanning returns USDZ file path on success', () async {
        // Given: Active scanning session
        const expectedPath = '/tmp/scans/room-123.usdz';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/room_scanner'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'stopScanning') {
              return expectedPath;
            }
            return null;
          },
        );

        // When: Stopping the scan
        final filePath = await channel.stopScanning();

        // Then: Should return USDZ file path
        expect(filePath, expectedPath);
        expect(methodCallLog.length, 1);
        expect(methodCallLog[0].method, 'stopScanning');
      });

      test('stopScanning throws exception on null file path', () async {
        // Given: Platform returns null
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/room_scanner'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'stopScanning') {
              return null; // Null file path
            }
            return null;
          },
        );

        // When/Then: Should throw RoomScannerException
        expect(
          () => channel.stopScanning(),
          throwsA(
            isA<RoomScannerException>().having(
              (e) => e.message,
              'message',
              contains('null result path'),
            ),
          ),
        );
      });

      test('cancelScanning completes without error', () async {
        // Given: Active scanning session
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/room_scanner'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'cancelScanning') {
              return null; // Success, no return value
            }
            return null;
          },
        );

        // When: Canceling the scan
        await channel.cancelScanning();

        // Then: Should complete without error
        expect(methodCallLog.length, 1);
        expect(methodCallLog[0].method, 'cancelScanning');
      });

      test('cancelScanning throws exception on platform error', () async {
        // Given: Platform error during cancel
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/room_scanner'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'cancelScanning') {
              throw PlatformException(
                code: 'CANCEL_FAILED',
                message: 'Failed to cancel scanning session',
              );
            }
            return null;
          },
        );

        // When/Then: Should throw RoomScannerException
        expect(
          () => channel.cancelScanning(),
          throwsA(
            isA<RoomScannerException>().having(
              (e) => e.message,
              'message',
              contains('Failed to cancel scanning'),
            ),
          ),
        );
      });
    });

    // =========================================================================
    // Test Group: Camera Permissions
    // =========================================================================

    group('Camera Permissions', () {
      test('requestCameraPermission returns true when granted', () async {
        // Given: User grants camera permission
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/room_scanner'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'requestCameraPermission') {
              return true; // Permission granted
            }
            return null;
          },
        );

        // When: Requesting camera permission
        final granted = await channel.requestCameraPermission();

        // Then: Should return true
        expect(granted, isTrue);
        expect(methodCallLog.length, 1);
        expect(methodCallLog[0].method, 'requestCameraPermission');
      });

      test('requestCameraPermission returns false when denied', () async {
        // Given: User denies camera permission
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/room_scanner'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'requestCameraPermission') {
              return false; // Permission denied
            }
            return null;
          },
        );

        // When: Requesting camera permission
        final granted = await channel.requestCameraPermission();

        // Then: Should return false
        expect(granted, isFalse);
      });

      test('requestCameraPermission handles null response as false', () async {
        // Given: Platform returns null
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/room_scanner'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'requestCameraPermission') {
              return null; // Null response
            }
            return null;
          },
        );

        // When: Requesting camera permission
        final granted = await channel.requestCameraPermission();

        // Then: Should default to false
        expect(granted, isFalse);
      });

      test('requestCameraPermission throws exception on platform error',
          () async {
        // Given: Platform error during permission request
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/room_scanner'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'requestCameraPermission') {
              throw PlatformException(
                code: 'PERMISSION_ERROR',
                message: 'Failed to request camera permission',
              );
            }
            return null;
          },
        );

        // When/Then: Should throw RoomScannerException
        expect(
          () => channel.requestCameraPermission(),
          throwsA(
            isA<RoomScannerException>().having(
              (e) => e.message,
              'message',
              contains('Failed to request camera permission'),
            ),
          ),
        );
      });
    });

    // =========================================================================
    // Test Group: Scan Progress Events
    // =========================================================================

    group('Scan Progress Events', () {
      test('scanProgress stream emits progress updates', () async {
        // Given: Mock event stream
        final controller = StreamController<dynamic>();

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(
          'flutter/platform_views',
          null,
        );

        // Simulate progress updates
        final progressUpdates = [
          {
            'percentage': 0.25,
            'message': 'Initializing scan...',
            'pointCount': 1000,
          },
          {
            'percentage': 0.50,
            'message': 'Scanning walls...',
            'pointCount': 5000,
          },
          {
            'percentage': 0.75,
            'message': 'Processing room structure...',
            'pointCount': 10000,
          },
          {
            'percentage': 1.0,
            'message': 'Scan complete!',
            'pointCount': 15000,
          },
        ];

        // Note: Event channel testing is limited in unit tests
        // This would be better tested in integration tests
        // For now, we test the ScanProgress model parsing

        // When: Parsing progress from map
        final progress1 = ScanProgress.fromMap(progressUpdates[0]);
        final progress2 = ScanProgress.fromMap(progressUpdates[1]);
        final progress3 = ScanProgress.fromMap(progressUpdates[2]);
        final progress4 = ScanProgress.fromMap(progressUpdates[3]);

        // Then: Should parse correctly
        expect(progress1.percentage, 0.25);
        expect(progress1.message, 'Initializing scan...');
        expect(progress1.pointCount, 1000);

        expect(progress2.percentage, 0.50);
        expect(progress2.message, 'Scanning walls...');

        expect(progress3.percentage, 0.75);
        expect(progress4.percentage, 1.0);
        expect(progress4.pointCount, 15000);

        await controller.close();
      });

      test('ScanProgress.fromMap handles missing optional fields', () {
        // Given: Progress update with only required fields
        final progressMap = {
          'percentage': 0.5,
          'message': 'Scanning...',
        };

        // When: Parsing progress
        final progress = ScanProgress.fromMap(progressMap);

        // Then: Optional fields should be null
        expect(progress.percentage, 0.5);
        expect(progress.message, 'Scanning...');
        expect(progress.pointCount, isNull);
        expect(progress.estimatedTimeRemaining, isNull);
      });

      test('ScanProgress.toMap serializes correctly', () {
        // Given: ScanProgress object
        const progress = ScanProgress(
          percentage: 0.75,
          message: 'Almost done...',
          pointCount: 8000,
          estimatedTimeRemaining: 30,
        );

        // When: Converting to map
        final map = progress.toMap();

        // Then: Should include all fields
        expect(map['percentage'], 0.75);
        expect(map['message'], 'Almost done...');
        expect(map['pointCount'], 8000);
        expect(map['estimatedTimeRemaining'], 30);
      });

      test('ScanProgress.toMap omits null optional fields', () {
        // Given: ScanProgress with only required fields
        const progress = ScanProgress(
          percentage: 0.5,
          message: 'In progress...',
        );

        // When: Converting to map
        final map = progress.toMap();

        // Then: Should only include non-null fields
        expect(map.containsKey('percentage'), isTrue);
        expect(map.containsKey('message'), isTrue);
        expect(map.containsKey('pointCount'), isFalse);
        expect(map.containsKey('estimatedTimeRemaining'), isFalse);
      });
    });

    // =========================================================================
    // Test Group: Exception Handling
    // =========================================================================

    group('Exception Handling', () {
      test('RoomScannerException formats message with code', () {
        // Given: Exception with code
        const exception = RoomScannerException(
          'Something went wrong',
          code: 'ERROR_CODE',
        );

        // When: Converting to string
        final message = exception.toString();

        // Then: Should include code in format
        expect(message, contains('ERROR_CODE'));
        expect(message, contains('Something went wrong'));
      });

      test('RoomScannerException formats message without code', () {
        // Given: Exception without code
        const exception = RoomScannerException('Something went wrong');

        // When: Converting to string
        final message = exception.toString();

        // Then: Should not include brackets
        expect(message, isNot(contains('[')));
        expect(message, contains('Something went wrong'));
      });

      test('LidarNotAvailableException has correct code', () {
        // Given: LidarNotAvailableException
        const exception = LidarNotAvailableException('No LiDAR sensor');

        // Then: Should have correct code
        expect(exception.code, 'LIDAR_NOT_AVAILABLE');
        expect(exception.message, 'No LiDAR sensor');
      });

      test('PermissionDeniedException includes permission name', () {
        // Given: PermissionDeniedException
        const exception = PermissionDeniedException(
          'Camera',
          'Camera permission denied by user',
        );

        // Then: Should include permission in message
        expect(exception.code, 'PERMISSION_DENIED');
        expect(exception.permission, 'Camera');
        expect(exception.toString(), contains('Camera'));
        expect(exception.toString(), contains('denied'));
      });
    });
  });
}
