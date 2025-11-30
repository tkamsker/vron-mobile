# Platform Channel Contracts

**Feature**: 001-vron-mobile-companion
**Date**: 2025-11-30
**Purpose**: Versioned method channel contracts for iOS/Android native integrations

## Overview

Platform channels expose native functionality (LiDAR scanning, 3D conversion, navmesh generation) to Flutter via method channels. All contracts follow Constitution Principle IV requirements:
- Versioned method names (e.g., `scanRoom_v1`)
- Typed arguments with JSON schema validation
- Error codes covering all failure modes
- Unit tests on both Dart and native sides

## Channel: `vron.one/room_scanner`

**Purpose**: LiDAR room scanning integration (iOS: RoomPlan, Android: ARCore)

### Method: `isSupported`

**Description**: Check if device supports LiDAR/ARCore scanning

**Arguments**: None

**Returns**:
```json
{
  "supported": true,
  "platform": "iOS",  // "iOS" | "Android" | "Unsupported"
  "minVersion": "16.0",  // iOS 16+ or Android API 29+
  "currentVersion": "17.2"
}
```

**Error Codes**: None (always succeeds, returns `supported: false` for unsupported devices)

**Example (Dart)**:
```dart
final result = await platform.invokeMethod('isSupported');
final isSupported = result['supported'] as bool;
```

---

### Method: `scanRoom_v1`

**Description**: Initiate LiDAR room scanning with RoomPlan UI (iOS) or ARCore capture (Android)

**Arguments**:
```json
{
  "projectId": "uuid-string",
  "sessionId": "uuid-string"
}
```

**Returns**:
```json
{
  "success": true,
  "usdzFilePath": "/path/to/captured/room.usdz",  // iOS only
  "plyFilePath": "/path/to/captured/points.ply",  // Android only
  "scanDuration": 45.2,  // seconds
  "vertexCount": 1234,
  "roomDimensions": {
    "length": 5.2,  // meters
    "width": 4.1,
    "height": 2.8
  }
}
```

**Error Codes**:
| Code | Reason | User Message |
|------|--------|--------------|
| `UNSUPPORTED_PLATFORM` | Device lacks LiDAR/ARCore | "This device does not support room scanning. LiDAR is required (iPhone 12 Pro or newer)." |
| `LIDAR_UNAVAILABLE` | Hardware failure or disabled | "LiDAR scanner is unavailable. Please restart your device." |
| `PERMISSION_DENIED` | Camera permission not granted | "Camera permission is required for room scanning. Please enable in Settings." |
| `SCAN_FAILED` | Scan interrupted or insufficient data | "Room scan failed. Please ensure good lighting and scan all walls." |
| `STORAGE_FULL` | Insufficient disk space | "Insufficient storage. At least 500MB free space is required." |

**Example (Dart)**:
```dart
try {
  final result = await platform.invokeMethod('scanRoom_v1', {
    'projectId': projectId,
    'sessionId': sessionId,
  });
  final usdzPath = result['usdzFilePath'] as String;
  print('Scan completed: $usdzPath');
} on PlatformException catch (e) {
  if (e.code == 'LIDAR_UNAVAILABLE') {
    showError('LiDAR scanner is unavailable');
  }
}
```

**iOS Implementation Notes**:
- Present `RoomCaptureView` modally
- Auto-dismiss on scan completion or cancellation
- Save USDZ to app Documents directory (auto-cleaned after GLB conversion)
- Return early if user cancels scan (not an error, return `{"success": false, "cancelled": true}`)

**Android Implementation Notes**:
- Launch ARCore depth capture session
- Manual bounding box selection by user
- Export point cloud to PLY format
- Requires custom mesh reconstruction before GLB conversion

---

### Method: `cancelScan_v1`

**Description**: Cancel active room scan and clean up temp files

**Arguments**:
```json
{
  "sessionId": "uuid-string"
}
```

**Returns**:
```json
{
  "success": true
}
```

**Error Codes**:
| Code | Reason |
|------|--------|
| `NO_ACTIVE_SCAN` | No scan session found with given ID |

---

## Channel: `vron.one/asset_converter`

**Purpose**: USDZ→GLB conversion and navmesh generation

### Method: `convertToGlb_v1`

**Description**: Convert USDZ file to GLB format with texture preservation (iOS only via Model I/O)

**Arguments**:
```json
{
  "usdzFilePath": "/path/to/input.usdz",
  "glbOutputPath": "/path/to/output.glb",
  "preserveTextures": true,
  "compressionLevel": "balanced"  // "none" | "balanced" | "aggressive"
}
```

**Returns**:
```json
{
  "success": true,
  "glbFilePath": "/path/to/output.glb",
  "fileSize": 25600000,  // bytes
  "textureCount": 5,
  "vertexCount": 1234,
  "conversionDuration": 8.3  // seconds
}
```

**Error Codes**:
| Code | Reason | User Message |
|------|--------|--------------|
| `UNSUPPORTED_PLATFORM` | Model I/O only available on iOS 16+ | "3D conversion is only supported on iOS devices." |
| `CONVERSION_FAILED` | Model I/O export error | "Failed to convert 3D model. The scan data may be corrupted." |
| `FILE_NOT_FOUND` | Input USDZ file missing | "Scan file not found. Please try scanning again." |
| `OUTPUT_TOO_LARGE` | GLB exceeds 50MB after conversion | "3D model is too large (>50MB). Please use compression or re-scan with reduced detail." |
| `TEXTURE_LOSS` | Texture count mismatch (input vs output) | "Warning: Some textures were not preserved during conversion." |

**Example (Dart)**:
```dart
try {
  final result = await platform.invokeMethod('convertToGlb_v1', {
    'usdzFilePath': usdzPath,
    'glbOutputPath': glbPath,
    'preserveTextures': true,
    'compressionLevel': 'balanced',
  });
  final fileSize = result['fileSize'] as int;
  if (fileSize > 52428800) {  // 50MB
    showWarning('File is large, consider compression');
  }
} on PlatformException catch (e) {
  if (e.code == 'TEXTURE_LOSS') {
    showWarning('Some textures were not preserved');
  }
}
```

**iOS Implementation Notes**:
- Use `MDLAsset(url:)` to load USDZ
- Export via `MDLAsset.export(to: url)` with `.gltf2` option
- Validate texture preservation by comparing `asset.count` before/after
- Implement compression by reducing texture resolution or mesh decimation

**Validation Requirements** (Constitution Principle VI):
- Input texture count must equal output texture count (automated test)
- Spatial accuracy must be within 5cm tolerance (compare bounding box dimensions)
- PBR material properties must be preserved (albedo, normal, metallic, roughness)

---

### Method: `generateNavmesh_v1`

**Description**: Generate navigation mesh from GLB scene geometry for VR navigation

**Arguments**:
```json
{
  "sceneGlbPath": "/path/to/scene.glb",
  "navmeshOutputPath": "/path/to/navmesh.glb",
  "agentHeight": 1.8,  // meters (humanoid VR avatar height)
  "agentRadius": 0.4,  // meters
  "maxSlope": 45.0,  // degrees
  "cellSize": 0.3  // meters (resolution)
}
```

**Returns**:
```json
{
  "success": true,
  "navmeshFilePath": "/path/to/navmesh.glb",
  "fileSize": 2100000,  // bytes
  "triangleCount": 456,
  "generationDuration": 12.4  // seconds
}
```

**Error Codes**:
| Code | Reason | User Message |
|------|--------|--------------|
| `NAVMESH_GENERATION_FAILED` | Recast library error or invalid geometry | "Failed to generate navigation mesh. The 3D model may have invalid geometry." |
| `INVALID_GEOMETRY` | Non-manifold mesh, holes, or self-intersections | "Navigation mesh generation failed due to invalid geometry. Please re-scan the room." |
| `FILE_NOT_FOUND` | Input GLB file missing | "Scene file not found." |

**Example (Dart)**:
```dart
try {
  final result = await platform.invokeMethod('generateNavmesh_v1', {
    'sceneGlbPath': sceneGlbPath,
    'navmeshOutputPath': navmeshPath,
    'agentHeight': 1.8,
    'agentRadius': 0.4,
    'maxSlope': 45.0,
    'cellSize': 0.3,
  });
  print('Navmesh generated: ${result["navmeshFilePath"]}');
} on PlatformException catch (e) {
  if (e.code == 'INVALID_GEOMETRY') {
    showError('Invalid room geometry, please re-scan');
  }
}
```

**iOS Implementation Notes**:
- Use NavMeshBuilder Swift wrapper around Recast C++ library
- Load GLB vertices/triangles via SceneKit
- Pass geometry to Recast via FFI
- Export navmesh as GLB (simplified mesh with walkable surfaces only)

**Android Implementation Notes**:
- Use JNI bindings to Recast C++ library
- Load GLB via Filament SceneLoader
- Same Recast parameters as iOS for cross-platform consistency

**Performance Target** (Constitution Principle I):
- Must complete within 15 seconds for typical room (1000-5000 vertices)
- If exceeding 15s, run in Dart isolate to avoid UI blocking

---

## Channel: `vron.one/platform_info`

**Purpose**: Device capability detection and platform-specific information

### Method: `getDeviceCapabilities`

**Description**: Query device hardware capabilities for feature gating

**Arguments**: None

**Returns**:
```json
{
  "platform": "iOS",
  "osVersion": "17.2",
  "hasLidar": true,
  "hasArCore": false,
  "supportsModelIO": true,
  "availableStorage": 2147483648,  // bytes
  "totalStorage": 68719476736,  // bytes
  "freeMemory": 2147483648,  // bytes
  "totalMemory": 4294967296  // bytes
}
```

**Error Codes**: None (always succeeds)

**Example (Dart)**:
```dart
final caps = await platform.invokeMethod('getDeviceCapabilities');
if (!caps['hasLidar']) {
  showMessage('Room scanning is not available on this device');
}
```

---

## Testing Requirements (Constitution Principle III)

### Dart-Side Tests

**Example: `room_scanner_test.dart`**
```dart
void main() {
  late MockMethodChannel mockChannel;

  setUp(() {
    mockChannel = MockMethodChannel('vron.one/room_scanner');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(mockChannel, (call) async {
        if (call.method == 'isSupported') {
          return {'supported': true, 'platform': 'iOS'};
        }
        if (call.method == 'scanRoom_v1') {
          return {
            'success': true,
            'usdzFilePath': '/tmp/room.usdz',
            'vertexCount': 1000,
          };
        }
        return null;
      });
  });

  test('isSupported returns correct platform info', () async {
    final result = await RoomScanner.isSupported();
    expect(result.supported, isTrue);
    expect(result.platform, equals('iOS'));
  });

  test('scanRoom_v1 throws PERMISSION_DENIED error', () async {
    mockChannel.setMockMethodCallHandler((call) async {
      throw PlatformException(code: 'PERMISSION_DENIED', message: 'Camera permission denied');
    });
    expect(
      () => RoomScanner.scanRoom(projectId: 'test', sessionId: 'test'),
      throwsA(isA<PlatformException>()),
    );
  });
}
```

### iOS-Side Tests

**Example: `RoomScannerPluginTests.swift`**
```swift
import XCTest
@testable import room_scanner

class RoomScannerPluginTests: XCTestCase {
  func testIsSupportedReturnsTrueOnLidarDevice() {
    let plugin = RoomScannerPlugin()
    let call = FlutterMethodCall(methodName: "isSupported", arguments: nil)
    var result: FlutterResult?

    plugin.handle(call) { res in
      result = res
    }

    let response = result as! [String: Any]
    XCTAssertEqual(response["supported"] as! Bool, true)
    XCTAssertEqual(response["platform"] as! String, "iOS")
  }

  func testScanRoomReturnsErrorWhenPermissionDenied() {
    // Mock AVCaptureDevice.authorizationStatus to return .denied
    // Assert PlatformException with code PERMISSION_DENIED is thrown
  }
}
```

### Android-Side Tests

**Example: `RoomScannerPluginTest.kt`**
```kotlin
@RunWith(AndroidJUnit4::class)
class RoomScannerPluginTest {
  @Test
  fun isSupported_returnsTrue_onArCoreDevice() {
    val plugin = RoomScannerPlugin()
    val call = MethodCall("isSupported", null)
    var result: Result? = null

    plugin.onMethodCall(call) { res -> result = res }

    assertNotNull(result)
    assertTrue(result!!["supported"] as Boolean)
  }
}
```

---

## Error Handling Best Practices

1. **Always provide user-friendly error messages** (not raw exceptions)
2. **Log detailed errors** for debugging (include stack traces)
3. **Implement retry logic** for transient errors (e.g., LIDAR_UNAVAILABLE)
4. **Fallback gracefully** for unsupported platforms (hide features on Android)
5. **Test all error paths** (use method call mocking)

---

## Versioning Strategy

**Current Version**: v1 (all methods suffixed with `_v1`)

**Future Versions**:
- Add new methods as `methodName_v2` (never break existing `_v1` contracts)
- Deprecate old versions with 6-month transition period
- Document breaking changes in CHANGELOG.md

**Example Migration**:
```dart
// Old code (deprecated)
final result = await platform.invokeMethod('scanRoom_v1', args);

// New code (enhanced API)
final result = await platform.invokeMethod('scanRoom_v2', {
  ...args,
  'enhancedModeEnabled': true,
});
```

---

## Performance Monitoring

**Constitution Principle I Requirements**:
- Log method call durations for performance regression detection
- Alert if `convertToGlb_v1` exceeds 10s average
- Alert if `generateNavmesh_v1` exceeds 15s average
- Track memory usage during scanning (must stay under 500MB peak)

**Example Monitoring**:
```dart
final stopwatch = Stopwatch()..start();
try {
  final result = await platform.invokeMethod('convertToGlb_v1', args);
  stopwatch.stop();
  analytics.logEvent('glb_conversion_duration', parameters: {
    'duration_ms': stopwatch.elapsedMilliseconds,
    'file_size_mb': result['fileSize'] / 1048576,
  });
} catch (e) {
  analytics.logError('glb_conversion_failed', error: e);
}
```
