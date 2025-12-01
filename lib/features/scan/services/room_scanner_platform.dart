import 'dart:async';
import 'package:flutter/services.dart';

/// Platform channel service for RoomPlan scanning
///
/// Communicates with native iOS RoomPlan API for LiDAR-based room scanning
class RoomScannerPlatform {
  static const MethodChannel _channel = MethodChannel('com.vron.mobile/room_scanner');
  static const EventChannel _eventChannel = EventChannel('com.vron.mobile/room_scanner_events');

  Stream<RoomScanEvent>? _eventStream;

  /// Check if RoomPlan is available on this device
  ///
  /// RoomPlan requires:
  /// - iOS 16.0+
  /// - LiDAR sensor (iPhone 12 Pro and later, iPad Pro with LiDAR)
  Future<bool> isRoomPlanAvailable() async {
    try {
      final bool available = await _channel.invokeMethod('isRoomPlanAvailable');
      return available;
    } on PlatformException catch (e) {
      print('Error checking RoomPlan availability: ${e.message}');
      return false;
    }
  }

  /// Start room scanning session
  ///
  /// Returns true if scanning started successfully
  Future<bool> startScanning() async {
    try {
      final bool started = await _channel.invokeMethod('startScanning');
      return started;
    } on PlatformException catch (e) {
      print('Error starting scan: ${e.message}');
      return false;
    }
  }

  /// Stop room scanning session
  ///
  /// Returns scan result data including file paths
  Future<RoomScanResult?> stopScanning() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('stopScanning');
      return RoomScanResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      print('Error stopping scan: ${e.message}');
      return null;
    }
  }

  /// Cancel ongoing scan without saving
  Future<void> cancelScanning() async {
    try {
      await _channel.invokeMethod('cancelScanning');
    } on PlatformException catch (e) {
      print('Error canceling scan: ${e.message}');
    }
  }

  /// Get stream of scanning events
  ///
  /// Events include:
  /// - Progress updates
  /// - Point count updates
  /// - Error notifications
  Stream<RoomScanEvent> getScanEventStream() {
    _eventStream ??= _eventChannel.receiveBroadcastStream().map((dynamic event) {
      final map = Map<String, dynamic>.from(event as Map);
      return RoomScanEvent.fromMap(map);
    });
    return _eventStream!;
  }

  /// Export scan result to various formats
  ///
  /// Formats supported:
  /// - USD (Universal Scene Description)
  /// - USDZ (compressed USD)
  /// - OBJ (Wavefront)
  Future<String?> exportScan({
    required String scanId,
    required String format,
    required String outputPath,
  }) async {
    try {
      final String? path = await _channel.invokeMethod('exportScan', {
        'scanId': scanId,
        'format': format,
        'outputPath': outputPath,
      });
      return path;
    } on PlatformException catch (e) {
      print('Error exporting scan: ${e.message}');
      return null;
    }
  }
}

/// Room scan result data
class RoomScanResult {
  /// Unique identifier for this scan
  final String scanId;

  /// Path to the exported USDZ file
  final String usdzPath;

  /// Path to the exported USD file (uncompressed)
  final String? usdPath;

  /// Number of data points collected
  final int pointCount;

  /// Scan duration in seconds
  final double duration;

  /// Floor plan dimensions
  final RoomDimensions? dimensions;

  /// Detected room objects (furniture, fixtures)
  final List<DetectedObject> detectedObjects;

  const RoomScanResult({
    required this.scanId,
    required this.usdzPath,
    this.usdPath,
    required this.pointCount,
    required this.duration,
    this.dimensions,
    this.detectedObjects = const [],
  });

  factory RoomScanResult.fromMap(Map<String, dynamic> map) {
    return RoomScanResult(
      scanId: map['scanId'] as String,
      usdzPath: map['usdzPath'] as String,
      usdPath: map['usdPath'] as String?,
      pointCount: map['pointCount'] as int? ?? 0,
      duration: (map['duration'] as num?)?.toDouble() ?? 0.0,
      dimensions: map['dimensions'] != null
          ? RoomDimensions.fromMap(Map<String, dynamic>.from(map['dimensions'] as Map))
          : null,
      detectedObjects: (map['detectedObjects'] as List<dynamic>?)
              ?.map((obj) => DetectedObject.fromMap(Map<String, dynamic>.from(obj as Map)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scanId': scanId,
      'usdzPath': usdzPath,
      'usdPath': usdPath,
      'pointCount': pointCount,
      'duration': duration,
      'dimensions': dimensions?.toMap(),
      'detectedObjects': detectedObjects.map((obj) => obj.toMap()).toList(),
    };
  }
}

/// Room dimensions
class RoomDimensions {
  final double width;
  final double length;
  final double height;
  final double area;

  const RoomDimensions({
    required this.width,
    required this.length,
    required this.height,
    required this.area,
  });

  factory RoomDimensions.fromMap(Map<String, dynamic> map) {
    return RoomDimensions(
      width: (map['width'] as num).toDouble(),
      length: (map['length'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      area: (map['area'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'width': width,
      'length': length,
      'height': height,
      'area': area,
    };
  }
}

/// Detected object in the room
class DetectedObject {
  final String category;
  final String identifier;
  final Map<String, double> dimensions;
  final Map<String, double> position;

  const DetectedObject({
    required this.category,
    required this.identifier,
    required this.dimensions,
    required this.position,
  });

  factory DetectedObject.fromMap(Map<String, dynamic> map) {
    return DetectedObject(
      category: map['category'] as String,
      identifier: map['identifier'] as String,
      dimensions: Map<String, double>.from(map['dimensions'] as Map),
      position: Map<String, double>.from(map['position'] as Map),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'identifier': identifier,
      'dimensions': dimensions,
      'position': position,
    };
  }
}

/// Room scan event
class RoomScanEvent {
  final RoomScanEventType type;
  final Map<String, dynamic> data;

  const RoomScanEvent({
    required this.type,
    required this.data,
  });

  factory RoomScanEvent.fromMap(Map<String, dynamic> map) {
    return RoomScanEvent(
      type: RoomScanEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => RoomScanEventType.unknown,
      ),
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
    );
  }

  int get pointCount => data['pointCount'] as int? ?? 0;
  double get progress => (data['progress'] as num?)?.toDouble() ?? 0.0;
  String? get error => data['error'] as String?;
}

/// Room scan event types
enum RoomScanEventType {
  /// Scanning started
  started,

  /// Progress update
  progress,

  /// Point count updated
  pointsUpdated,

  /// Scanning completed
  completed,

  /// Scanning failed
  error,

  /// Scanning canceled
  canceled,

  /// Unknown event type
  unknown,
}
