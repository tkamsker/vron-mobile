import 'dart:async';
import 'package:flutter/services.dart';

/// Platform channel contract for room scanning with LiDAR
///
/// Provides interface for:
/// - Checking LiDAR availability
/// - Starting/stopping room scanning
/// - Receiving scan progress updates
/// - Getting scan results (USDZ file path)
///
/// Platform-specific implementations:
/// - iOS: Uses ARKit + RoomPlan framework (iOS 16+)
/// - Android: Uses ARCore depth API (Android 10+, device-dependent)
class RoomScannerChannel {
  /// Channel name for method calls
  static const String _channelName = 'one.vron.mobile/room_scanner';

  /// Event channel for scan progress updates
  static const String _eventChannelName = 'one.vron.mobile/room_scanner_events';

  /// Method channel for platform calls
  final MethodChannel _methodChannel = const MethodChannel(_channelName);

  /// Event channel for receiving scan progress
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);

  Stream<ScanProgress>? _progressStream;

  /// Check if LiDAR scanning is available on this device
  ///
  /// Returns true if:
  /// - iOS: Device has LiDAR sensor (iPhone 12 Pro+, iPad Pro 2020+)
  /// - Android: Device supports ARCore depth API
  ///
  /// Throws [PlatformException] if check fails
  Future<bool> isLidarAvailable() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isLidarAvailable');
      return result ?? false;
    } on PlatformException catch (e) {
      throw RoomScannerException(
        'Failed to check LiDAR availability: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Get device capabilities for room scanning
  ///
  /// Returns map with:
  /// - hasLidar: bool
  /// - hasDepthAPI: bool (Android only)
  /// - minIOSVersion: String (iOS only)
  /// - arCoreVersion: String (Android only)
  Future<Map<String, dynamic>> getDeviceCapabilities() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getDeviceCapabilities',
      );
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw RoomScannerException(
        'Failed to get device capabilities: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Start room scanning session
  ///
  /// Parameters:
  /// - [roomId]: Unique identifier for this scan
  /// - [roomName]: User-friendly name for the room
  /// - [outputPath]: Directory path where USDZ file will be saved
  ///
  /// Returns: Session ID for this scan
  ///
  /// Throws:
  /// - [LidarNotAvailableException] if LiDAR is not available
  /// - [PermissionDeniedException] if camera permission not granted
  /// - [RoomScannerException] for other errors
  Future<String> startScanning({
    required String roomId,
    required String roomName,
    required String outputPath,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<String>(
        'startScanning',
        {
          'roomId': roomId,
          'roomName': roomName,
          'outputPath': outputPath,
        },
      );

      if (result == null) {
        throw RoomScannerException('Failed to start scanning: null session ID');
      }

      return result;
    } on PlatformException catch (e) {
      if (e.code == 'LIDAR_NOT_AVAILABLE') {
        throw LidarNotAvailableException(e.message ?? 'LiDAR not available');
      } else if (e.code == 'PERMISSION_DENIED') {
        throw PermissionDeniedException(
          'Camera',
          e.message ?? 'Camera permission denied',
        );
      }
      throw RoomScannerException(
        'Failed to start scanning: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Stop current scanning session
  ///
  /// Returns path to the generated USDZ file
  ///
  /// Throws [RoomScannerException] if stop fails
  Future<String> stopScanning() async {
    try {
      final result = await _methodChannel.invokeMethod<String>('stopScanning');

      if (result == null) {
        throw RoomScannerException('Failed to stop scanning: null result path');
      }

      return result;
    } on PlatformException catch (e) {
      throw RoomScannerException(
        'Failed to stop scanning: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Cancel current scanning session without saving
  ///
  /// Throws [RoomScannerException] if cancel fails
  Future<void> cancelScanning() async {
    try {
      await _methodChannel.invokeMethod<void>('cancelScanning');
    } on PlatformException catch (e) {
      throw RoomScannerException(
        'Failed to cancel scanning: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Request camera permission
  ///
  /// Returns true if permission granted
  Future<bool> requestCameraPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'requestCameraPermission',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw RoomScannerException(
        'Failed to request camera permission: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Stream of scan progress updates
  ///
  /// Emits [ScanProgress] objects with:
  /// - percentage: 0.0 to 1.0
  /// - message: User-friendly status message
  /// - pointCount: Number of points captured (optional)
  Stream<ScanProgress> get scanProgress {
    _progressStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => ScanProgress.fromMap(Map<String, dynamic>.from(event as Map)));

    return _progressStream!;
  }
}

/// Scan progress data
class ScanProgress {
  /// Progress percentage (0.0 to 1.0)
  final double percentage;

  /// Status message
  final String message;

  /// Number of points captured (optional)
  final int? pointCount;

  /// Estimated time remaining in seconds (optional)
  final int? estimatedTimeRemaining;

  const ScanProgress({
    required this.percentage,
    required this.message,
    this.pointCount,
    this.estimatedTimeRemaining,
  });

  factory ScanProgress.fromMap(Map<String, dynamic> map) {
    return ScanProgress(
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
      message: map['message'] as String? ?? '',
      pointCount: map['pointCount'] as int?,
      estimatedTimeRemaining: map['estimatedTimeRemaining'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'percentage': percentage,
      'message': message,
      if (pointCount != null) 'pointCount': pointCount,
      if (estimatedTimeRemaining != null)
        'estimatedTimeRemaining': estimatedTimeRemaining,
    };
  }
}

/// Base exception for room scanner errors
class RoomScannerException implements Exception {
  final String message;
  final String? code;

  const RoomScannerException(this.message, {this.code});

  @override
  String toString() {
    if (code != null) {
      return 'RoomScannerException [$code]: $message';
    }
    return 'RoomScannerException: $message';
  }
}

/// LiDAR not available on device
class LidarNotAvailableException extends RoomScannerException {
  const LidarNotAvailableException(String message)
      : super(message, code: 'LIDAR_NOT_AVAILABLE');
}

/// Permission denied exception
class PermissionDeniedException extends RoomScannerException {
  final String permission;

  const PermissionDeniedException(this.permission, String message)
      : super(message, code: 'PERMISSION_DENIED');

  @override
  String toString() {
    return 'PermissionDeniedException: Permission "$permission" denied - $message';
  }
}
