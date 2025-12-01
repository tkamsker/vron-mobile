import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_scanner/src/room_scanner_channel.dart';

/// Test suite for device capability detection
///
/// Tests the RoomScannerChannel's ability to detect:
/// - LiDAR availability on iOS and Android
/// - Device capabilities (hasLiDAR, depth API, versions)
/// - Proper error handling for unsupported devices
///
/// **TDD Requirement**: These tests must pass before implementing the feature
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device Capability Detection', () {
    late RoomScannerChannel channel;
    late List<MethodCall> methodCallLog;

    setUp(() {
      channel = RoomScannerChannel();
      methodCallLog = [];

      // Reset method call handler before each test
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        null,
      );
    });

    tearDown(() {
      // Clean up after each test
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        null,
      );
    });

    // =========================================================================
    // Test: isLidarAvailable() on supported iOS device
    // =========================================================================

    test('isLidarAvailable returns true on iPhone 12 Pro or newer', () async {
      // Given: Device with LiDAR support (iPhone 12 Pro+, iPad Pro 2020+)
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        (MethodCall methodCall) async {
          methodCallLog.add(methodCall);

          if (methodCall.method == 'isLidarAvailable') {
            return true; // iOS device with LiDAR
          }
          return null;
        },
      );

      // When: Checking LiDAR availability
      final result = await channel.isLidarAvailable();

      // Then: Should return true
      expect(result, isTrue);
      expect(methodCallLog.length, 1);
      expect(methodCallLog[0].method, 'isLidarAvailable');
    });

    // =========================================================================
    // Test: isLidarAvailable() on unsupported iOS device
    // =========================================================================

    test('isLidarAvailable returns false on iPhone SE or older models',
        () async {
      // Given: iOS device without LiDAR (iPhone SE, iPhone 11, etc.)
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        (MethodCall methodCall) async {
          methodCallLog.add(methodCall);

          if (methodCall.method == 'isLidarAvailable') {
            return false; // No LiDAR on device
          }
          return null;
        },
      );

      // When: Checking LiDAR availability
      final result = await channel.isLidarAvailable();

      // Then: Should return false
      expect(result, isFalse);
    });

    // =========================================================================
    // Test: isLidarAvailable() on Android with depth API
    // =========================================================================

    test('isLidarAvailable returns true on Android with depth API support',
        () async {
      // Given: Android device with ARCore depth API
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        (MethodCall methodCall) async {
          methodCallLog.add(methodCall);

          if (methodCall.method == 'isLidarAvailable') {
            return true; // Depth API available
          }
          return null;
        },
      );

      // When: Checking LiDAR availability
      final result = await channel.isLidarAvailable();

      // Then: Should return true
      expect(result, isTrue);
    });

    // =========================================================================
    // Test: isLidarAvailable() on Android without depth API
    // =========================================================================

    test('isLidarAvailable returns false on Android without depth API',
        () async {
      // Given: Android device without depth API support
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        (MethodCall methodCall) async {
          methodCallLog.add(methodCall);

          if (methodCall.method == 'isLidarAvailable') {
            return false; // No depth API
          }
          return null;
        },
      );

      // When: Checking LiDAR availability
      final result = await channel.isLidarAvailable();

      // Then: Should return false
      expect(result, isFalse);
    });

    // =========================================================================
    // Test: isLidarAvailable() handles null response
    // =========================================================================

    test('isLidarAvailable handles null response as false', () async {
      // Given: Platform returns null (edge case)
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        (MethodCall methodCall) async {
          methodCallLog.add(methodCall);

          if (methodCall.method == 'isLidarAvailable') {
            return null; // Null response
          }
          return null;
        },
      );

      // When: Checking LiDAR availability
      final result = await channel.isLidarAvailable();

      // Then: Should default to false
      expect(result, isFalse);
    });

    // =========================================================================
    // Test: isLidarAvailable() throws RoomScannerException on platform error
    // =========================================================================

    test('isLidarAvailable throws RoomScannerException on platform error',
        () async {
      // Given: Platform throws an error
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        (MethodCall methodCall) async {
          methodCallLog.add(methodCall);

          if (methodCall.method == 'isLidarAvailable') {
            throw PlatformException(
              code: 'PLATFORM_ERROR',
              message: 'Failed to check hardware capabilities',
            );
          }
          return null;
        },
      );

      // When/Then: Should throw RoomScannerException
      expect(
        () => channel.isLidarAvailable(),
        throwsA(
          isA<RoomScannerException>().having(
            (e) => e.message,
            'message',
            contains('Failed to check LiDAR availability'),
          ),
        ),
      );
    });

    // =========================================================================
    // Test: getDeviceCapabilities() on iOS with LiDAR
    // =========================================================================

    test('getDeviceCapabilities returns iOS device info with LiDAR', () async {
      // Given: iPhone 12 Pro with LiDAR
      final expectedCapabilities = {
        'hasLidar': true,
        'platform': 'iOS',
        'minIOSVersion': '16.0',
        'deviceModel': 'iPhone 12 Pro',
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        (MethodCall methodCall) async {
          methodCallLog.add(methodCall);

          if (methodCall.method == 'getDeviceCapabilities') {
            return expectedCapabilities;
          }
          return null;
        },
      );

      // When: Getting device capabilities
      final result = await channel.getDeviceCapabilities();

      // Then: Should return iOS device info
      expect(result['hasLidar'], isTrue);
      expect(result['platform'], 'iOS');
      expect(result['minIOSVersion'], '16.0');
      expect(methodCallLog.length, 1);
      expect(methodCallLog[0].method, 'getDeviceCapabilities');
    });

    // =========================================================================
    // Test: getDeviceCapabilities() on Android with depth API
    // =========================================================================

    test('getDeviceCapabilities returns Android device info with depth API',
        () async {
      // Given: Android device with ARCore depth support
      final expectedCapabilities = {
        'hasLidar': false,
        'hasDepthAPI': true,
        'platform': 'Android',
        'arCoreVersion': '1.41.0',
        'minAndroidVersion': '10',
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        (MethodCall methodCall) async {
          methodCallLog.add(methodCall);

          if (methodCall.method == 'getDeviceCapabilities') {
            return expectedCapabilities;
          }
          return null;
        },
      );

      // When: Getting device capabilities
      final result = await channel.getDeviceCapabilities();

      // Then: Should return Android device info
      expect(result['hasLidar'], isFalse);
      expect(result['hasDepthAPI'], isTrue);
      expect(result['platform'], 'Android');
      expect(result['arCoreVersion'], '1.41.0');
    });

    // =========================================================================
    // Test: getDeviceCapabilities() on unsupported device
    // =========================================================================

    test('getDeviceCapabilities returns empty capabilities for unsupported device',
        () async {
      // Given: Device without LiDAR or depth API
      final expectedCapabilities = {
        'hasLidar': false,
        'hasDepthAPI': false,
        'platform': 'iOS',
        'errorMessage': 'Device does not support room scanning',
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        (MethodCall methodCall) async {
          methodCallLog.add(methodCall);

          if (methodCall.method == 'getDeviceCapabilities') {
            return expectedCapabilities;
          }
          return null;
        },
      );

      // When: Getting device capabilities
      final result = await channel.getDeviceCapabilities();

      // Then: Should indicate no scanning support
      expect(result['hasLidar'], isFalse);
      expect(result['hasDepthAPI'], isFalse);
      expect(result['errorMessage'], isNotNull);
    });

    // =========================================================================
    // Test: getDeviceCapabilities() handles null response
    // =========================================================================

    test('getDeviceCapabilities returns empty map on null response', () async {
      // Given: Platform returns null
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        (MethodCall methodCall) async {
          methodCallLog.add(methodCall);

          if (methodCall.method == 'getDeviceCapabilities') {
            return null; // Null response
          }
          return null;
        },
      );

      // When: Getting device capabilities
      final result = await channel.getDeviceCapabilities();

      // Then: Should return empty map
      expect(result, isEmpty);
    });

    // =========================================================================
    // Test: getDeviceCapabilities() throws exception on platform error
    // =========================================================================

    test('getDeviceCapabilities throws RoomScannerException on platform error',
        () async {
      // Given: Platform throws error
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/room_scanner'),
        (MethodCall methodCall) async {
          methodCallLog.add(methodCall);

          if (methodCall.method == 'getDeviceCapabilities') {
            throw PlatformException(
              code: 'HARDWARE_ERROR',
              message: 'Failed to query hardware',
            );
          }
          return null;
        },
      );

      // When/Then: Should throw RoomScannerException
      expect(
        () => channel.getDeviceCapabilities(),
        throwsA(
          isA<RoomScannerException>().having(
            (e) => e.message,
            'message',
            contains('Failed to get device capabilities'),
          ),
        ),
      );
    });
  });
}
