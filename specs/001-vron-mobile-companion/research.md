# Research: VRON Mobile Companion

**Feature**: 001-vron-mobile-companion
**Date**: 2025-11-30
**Purpose**: Technology choices, best practices, and architectural patterns for Flutter LiDAR scanning app with GraphQL integration

## Executive Summary

This research validates the feasibility of building a Flutter 3.24+ mobile app with LiDAR room scanning, on-device USDZ→GLB conversion, and GraphQL offline-first sync. Key findings:

- ✅ **FEASIBLE**: RoomPlan iOS plugin integration via platform channels
- ⚠️ **HIGH-RISK**: Apple Model I/O USDZ→GLB conversion (recommend POC sprint 0)
- ✅ **FEASIBLE**: Navmesh generation using Recast library via FFI
- ✅ **PROVEN**: GraphQL + Drift offline sync pattern well-established in Flutter
- ✅ **MATURE**: Riverpod state management production-ready
- ✅ **FEASIBLE**: Resumable chunked uploads using multipart/form-data

## Technology Stack Decisions

### 1. GraphQL Client

**Decision**: Use `graphql_flutter` ^5.1.0 with `graphql_codegen` for type-safe operations

**Rationale**:
- `graphql_flutter` is the most mature and widely-adopted GraphQL client for Flutter (14k+ stars)
- Built-in cache-first strategy with `GraphQLCache` policy
- Supports GraphQL subscriptions over WebSocket for real-time sync
- Code generation via `graphql_codegen` ensures type safety (catches schema mismatches at compile time)
- Well-documented patterns for offline-first architecture

**Alternatives Considered**:
- `ferry` ^0.15.0: More modern with stronger typing via `built_value`, but smaller ecosystem and steeper learning curve
- `artemis` ^7.0.0: Deprecated in favor of `graphql_flutter` code generation

**Implementation Pattern**:
```dart
// graphql_client_provider.dart
final graphqlClientProvider = Provider<GraphQLClient>((ref) {
  final httpLink = HttpLink('https://api.vron.stage.motorenflug.at/graphql');
  final authLink = AuthLink(getToken: () async => 'Bearer ${await getAuthCode()}');
  final wsLink = WebSocketLink('wss://api.vron.stage.motorenflug.at/graphql');

  return GraphQLClient(
    cache: GraphQLCache(store: HiveStore()),
    link: Link.split(
      (request) => request.isSubscription,
      wsLink,
      authLink.concat(httpLink),
    ),
    defaultPolicies: DefaultPolicies(
      query: Policies(fetch: FetchPolicy.cacheFirst),
      mutate: Policies(fetch: FetchPolicy.networkOnly),
    ),
  );
});
```

### 2. State Management

**Decision**: Use `riverpod` ^2.4.0 (specifically `flutter_riverpod`)

**Rationale**:
- Compile-time safety with provider type checking (catches errors before runtime)
- Excellent for GraphQL integration via `FutureProvider` and `StreamProvider` for subscriptions
- Supports dependency injection out-of-the-box (testable architecture)
- `StateNotifierProvider` pattern ideal for complex feature state (scan progress, upload queue)
- No `BuildContext` required for accessing providers (cleaner than `Provider` package)
- Well-suited for offline-first with cache invalidation strategies

**Alternatives Considered**:
- `bloc` ^8.1.0: More boilerplate, overkill for this app's complexity
- `provider` ^6.1.0: Lacks compile-time safety of Riverpod
- `get_it` + `flutter_bloc`: Too much ceremony for dependency injection

**Implementation Pattern**:
```dart
// auth_provider.dart
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(graphqlClientProvider), ref.read(secureStorageProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._client, this._storage) : super(AuthState.initial());

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _client.mutate(SignInMutation(...));
      final token = result.data?.signIn.accessToken;
      await _storage.write(key: 'auth_token', value: token);
      state = AuthState.authenticated(token);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }
}
```

### 3. Local Storage

**Decision**: Use `drift` ^2.14.0 for structured data + `hive` ^2.2.3 for GraphQL cache

**Rationale**:
- **Drift** (formerly Moor): Type-safe SQL ORM with compile-time query validation
  - Excellent for structured relational data (projects, rooms, upload queue)
  - Built-in support for complex queries, joins, and migrations
  - Generates Dart classes from SQL schema (reduces boilerplate)
  - Supports stream queries for reactive UI updates
- **Hive**: Fast NoSQL key-value store for GraphQL response cache
  - ~10x faster than SQLite for simple key-value operations
  - Perfect for caching JSON responses with TTL (24-hour expiration)
  - Lazy box loading for memory efficiency

**Alternatives Considered**:
- `sqflite` ^2.3.0: Lower-level, requires manual SQL string construction (error-prone)
- `isar` ^3.1.0: Fast but lacks SQL familiarity, smaller ecosystem
- `objectbox` ^2.3.0: Commercial license for advanced features

**Implementation Pattern**:
```dart
// database.drift
CREATE TABLE projects (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL CHECK(status IN ('active', 'inactive')),
  thumbnail_url TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  synced_at INTEGER
);

CREATE TABLE rooms (
  id TEXT NOT NULL PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(id),
  name TEXT NOT NULL,
  scan_date INTEGER NOT NULL,
  scene_glb_path TEXT,
  navmesh_glb_path TEXT,
  scene_file_size INTEGER,
  navmesh_file_size INTEGER,
  processing_status TEXT NOT NULL,
  UNIQUE(project_id, name)
);

// database.dart
@DriftDatabase(tables: [Projects, Rooms, UploadQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  Stream<List<Project>> watchProjectsByUser() {
    return select(projects)
      ..where((p) => p.status.equals('active'))
      ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]);
  }
}
```

### 4. Authentication

**Decision**: Custom base64-encoded token matching vron.one spec (no Auth0/Supabase)

**Rationale**:
- vron.one SaaS already has custom authentication format (see `req/AUTHENTICATION.md`)
- Token structure: `{MERCHANT: {accessToken}, activeRoles: {merchants: "MERCHANT"}}`
- Base64-encoded and sent as `Authorization: Bearer <AUTH_CODE>`
- No need for third-party auth providers (Auth0/Supabase) - increases complexity unnecessarily
- `flutter_secure_storage` ^9.0.0 for encrypted token persistence (iOS Keychain, Android KeyStore)

**Implementation Pattern**:
```dart
// auth_service.dart
class AuthService {
  static String encodeAuthToken(String accessToken) {
    final authJson = {
      'MERCHANT': {'accessToken': accessToken},
      'activeRoles': {'merchants': 'MERCHANT'}
    };
    return base64Encode(utf8.encode(jsonEncode(authJson)));
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final authCode = await _storage.read(key: 'auth_token');
    return {
      'Authorization': 'Bearer $authCode',
      'X-VRon-Platform': 'merchants',
    };
  }
}
```

### 5. 3D Rendering

**Decision**: Use `three_dart` ^0.0.16 for GLB rendering

**Rationale**:
- Port of Three.js to Dart/Flutter (familiar API for web developers)
- Supports GLB/GLTF 2.0 format loading
- PBR material rendering (albedo, normal, metallic, roughness textures)
- Touch gesture controls for rotation, zoom, pan
- Adequate performance for preview use case (not real-time game engine)

**Alternatives Considered**:
- `flutter_gl` ^0.0.25: Lower-level OpenGL bindings, requires more manual work
- `flame` ^1.14.0: Game engine, overkill for static model viewing
- Native platform views (SceneKit iOS, Filament Android): Platform fragmentation, harder to maintain

**Implementation Pattern**:
```dart
// glb_viewer_widget.dart
class GlbViewerWidget extends StatefulWidget {
  final String glbFilePath;

  @override
  _GlbViewerWidgetState createState() => _GlbViewerWidgetState();
}

class _GlbViewerWidgetState extends State<GlbViewerWidget> {
  late three.Scene scene;
  late three.PerspectiveCamera camera;
  late three.WebGLRenderer renderer;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    final loader = three.GLTFLoader();
    final gltf = await loader.loadAsync(widget.glbFilePath);
    scene.add(gltf.scene);
  }
}
```

### 6. Platform Channels - LiDAR Scanning

**Decision**: Custom Flutter plugin wrapping RoomPlan (iOS 16+) and ARCore Depth API (Android API 29+)

**Rationale**:
- **iOS**: RoomPlan is Apple's official API for LiDAR scanning (iOS 16+)
  - Automatically detects room boundaries, furniture, wall openings
  - Outputs USDZ file format (Universal Scene Description)
  - Built-in UI for scan guidance
  - Reference: [Apple RoomPlan Documentation](https://developer.apple.com/documentation/roomplan)
- **Android**: ARCore Depth API provides equivalent (limited) functionality
  - Requires manual depth point cloud stitching
  - No automatic room boundary detection (more manual work)
  - Output to PLY or OBJ format, requires custom conversion to GLB

**Implementation Pattern**:
```swift
// ios/Classes/RoomScannerPlugin.swift
import RoomPlan

class RoomScannerPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "vron.one/room_scanner", binaryMessenger: registrar.messenger())
    let instance = RoomScannerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(RoomCaptureSession.isSupported)
    case "scanRoom_v1":
      startRoomScan(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startRoomScan(result: @escaping FlutterResult) {
    let captureSession = RoomCaptureSession()
    let captureView = RoomCaptureView(captureSession: captureSession)
    // Present captureView and handle completion
  }
}
```

### 7. USDZ→GLB Conversion (HIGH-RISK COMPONENT)

**Decision**: Apple Model I/O framework via Swift plugin (iOS 16+)

**Rationale**:
- Model I/O is part of iOS/macOS SDK, supports USDZ input and GLTF/GLB output
- Can preserve PBR textures during conversion (albedo, normal, metallic, roughness)
- **HIGH-RISK**: Limited documentation on GLB export fidelity
- **RECOMMENDATION**: Create proof-of-concept in Sprint 0 to validate texture preservation

**Alternative Fallback**:
- Server-side conversion using Blender headless + `usdzconvert` tool
- Upload USDZ to backend, convert server-side, return GLB URL
- Requires backend service but guaranteed reliability

**POC Validation Criteria**:
- Can convert typical RoomPlan USDZ output to GLB
- Preserves all texture maps (verify texture count input == output)
- Maintains spatial accuracy within 5cm tolerance
- Completes conversion in <10 seconds for typical room

**Implementation Pattern**:
```swift
// ios/Classes/AssetConverterPlugin.swift
import ModelIO
import SceneKit.ModelIO

class AssetConverterPlugin: NSObject, FlutterPlugin {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "convertToGlb_v1":
      let args = call.arguments as! [String: Any]
      let usdzPath = args["usdzPath"] as! String
      let glbPath = args["glbPath"] as! String

      do {
        let asset = MDLAsset(url: URL(fileURLWithPath: usdzPath))
        let glbExportURL = URL(fileURLWithPath: glbPath)
        try asset.export(to: glbExportURL)

        // Validate texture preservation
        let textureCount = countTextures(asset)
        result(["success": true, "textureCount": textureCount])
      } catch {
        result(FlutterError(code: "CONVERSION_FAILED", message: error.localizedDescription, details: nil))
      }
    }
  }
}
```

### 8. Navmesh Generation

**Decision**: Use Recast Navigation library via FFI (C++ to Dart)

**Rationale**:
- Recast is industry-standard navmesh generation (used in Unity, Unreal Engine)
- Swift wrapper available: [NavMeshBuilder](https://github.com/vonture/NavMeshBuilder)
- Can process GLB vertex/triangle data to generate navigation mesh
- Outputs GLB format for upload alongside scene GLB

**Implementation Pattern**:
```dart
// packages/asset_converter/lib/navmesh_generator.dart
import 'dart:ffi' as ffi;

class NavmeshGenerator {
  late ffi.DynamicLibrary _nativeLib;

  NavmeshGenerator() {
    _nativeLib = Platform.isIOS
      ? ffi.DynamicLibrary.process()
      : ffi.DynamicLibrary.open('librecast.so');
  }

  Future<String> generateNavmesh({
    required String sceneGlbPath,
    required String outputGlbPath,
  }) async {
    // Call native Recast library via FFI
    final generateFunc = _nativeLib
      .lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>)>>('generate_navmesh')
      .asFunction<void Function(Pointer<Utf8>, Pointer<Utf8>)>();

    final scenePtr = sceneGlbPath.toNativeUtf8();
    final outputPtr = outputGlbPath.toNativeUtf8();

    generateFunc(scenePtr, outputPtr);

    return outputGlbPath;
  }
}
```

### 9. Resumable Uploads

**Decision**: Chunked multipart upload with progress tracking

**Rationale**:
- GLB files can approach 50MB (large for mobile uploads)
- `dio` ^5.4.0 package supports chunked uploads with progress callbacks
- Track uploaded byte offset in Drift UploadQueue table
- On connectivity loss, resume from last successful chunk

**Implementation Pattern**:
```dart
// upload_service.dart
class UploadService {
  final Dio _dio = Dio();

  Future<void> uploadWithResume({
    required String filePath,
    required String uploadUrl,
    required Function(int sent, int total) onProgress,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();

    // Check for existing upload session
    final resumeOffset = await _getResumeOffset(filePath);

    final options = Options(
      headers: {
        'Content-Range': 'bytes $resumeOffset-${fileSize-1}/$fileSize',
      },
    );

    await _dio.post(
      uploadUrl,
      data: file.openRead(resumeOffset),
      options: options,
      onSendProgress: (sent, total) {
        onProgress(sent + resumeOffset, fileSize);
        _saveResumeOffset(filePath, sent + resumeOffset);
      },
    );
  }
}
```

### 10. CI/CD Integration

**Decision**: Extend existing GitHub Actions with Fastlane for TestFlight

**Rationale**:
- User specified existing GitHub Actions CI/CD
- Fastlane is industry standard for iOS/Android build automation
- `fastlane-plugin-flutter_version` for embedding build IDs

**Implementation Pattern**:
```yaml
# .github/workflows/flutter-ci.yml
name: Flutter CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - run: flutter build ios --no-codesign
      - run: flutter build apk --debug

  deploy-testflight:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter build ios --release
      - run: cd ios && fastlane beta
```

```ruby
# ios/fastlane/Fastfile
default_platform(:ios)

platform :ios do
  desc "Push a new beta build to TestFlight"
  lane :beta do
    increment_build_number(build_number: ENV['GITHUB_RUN_NUMBER'])
    build_app(scheme: "Runner")
    upload_to_testflight(skip_waiting_for_build_processing: true)
  end
end
```

## Best Practices Research

### GraphQL Offline-First Pattern

**Research Findings**:
- Use `GraphQLCache` with `HiveStore` for persistent cache
- Implement optimistic updates for mutations (show success immediately, rollback on error)
- Queue failed mutations in Drift database with retry strategy
- Use cache normalization to deduplicate entities

**Reference**: [Flutter GraphQL Offline-First](https://pub.dev/packages/graphql_flutter#offline-cache)

### Flutter Performance Optimization

**Research Findings**:
- Use `const` constructors for all stateless widgets (reduces rebuilds)
- Implement `ListView.builder` for long scrollable lists (lazy loading)
- Use `RepaintBoundary` around 3D viewer to isolate expensive repaints
- Profile with DevTools Timeline to identify jank (target 60fps)
- Minimize widget tree depth (avoid nested Columns/Rows)

**Reference**: [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)

### Mobile App Storage Best Practices

**Research Findings**:
- Store auth tokens in `flutter_secure_storage` (iOS Keychain, Android KeyStore)
- Use Hive for frequently accessed cache (faster than SQL for key-value)
- Use Drift for relational queries (projects→rooms relationship)
- Implement cache eviction policy (24-hour TTL, LRU for size limits)
- Never store tokens in SharedPreferences (insecure)

**Reference**: [Flutter Secure Storage Best Practices](https://pub.dev/packages/flutter_secure_storage)

### Platform Channel Error Handling

**Research Findings**:
- Always define custom error codes (not generic PlatformException)
- Test error paths on both Dart and native sides
- Use `MethodChannel.setMockMethodCallHandler` for unit testing
- Document all error codes in channel contract
- Provide user-friendly error messages (translate LIDAR_UNAVAILABLE to "This device does not support room scanning")

**Reference**: [Flutter Platform Channels Documentation](https://docs.flutter.dev/platform-integration/platform-channels)

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| **USDZ→GLB conversion fidelity** | HIGH | POC sprint 0, fallback to server-side conversion if fails |
| **Navmesh generation performance** | MEDIUM | Profile on real devices, potentially move to isolate if >15s |
| **iOS RoomPlan API changes** | LOW | Pin iOS 16+ minimum, monitor Apple release notes |
| **GraphQL schema changes breaking app** | MEDIUM | Code generation catches at compile time, implement schema versioning |
| **File upload failures on poor connectivity** | MEDIUM | Resumable uploads with exponential backoff, queue persistence |
| **Memory pressure during scanning** | MEDIUM | Monitor memory usage, implement background warnings at 80% threshold |

## Recommendations

1. **Sprint 0 POCs**:
   - Validate USDZ→GLB conversion with Model I/O (3 days)
   - Test RoomPlan integration and USDZ output format (2 days)
   - Profile navmesh generation on target devices (2 days)

2. **Architecture**:
   - Start with `graphql_flutter` (more mature than `ferry`)
   - Use Riverpod for consistency (avoid mixing state management approaches)
   - Separate concerns: packages for reusable logic, feature modules for UI

3. **Testing Strategy**:
   - Write platform channel contracts first (before native code)
   - Use golden tests for UI consistency
   - Mock GraphQL responses for deterministic tests

4. **Performance Monitoring**:
   - Integrate Firebase Performance Monitoring for production
   - Log frame times, memory usage, conversion durations
   - Set up alerts for regressions (>5% degradation)

## References

- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)
- [Apple RoomPlan Documentation](https://developer.apple.com/documentation/roomplan)
- [Apple Model I/O Documentation](https://developer.apple.com/documentation/modelio)
- [GraphQL Flutter Package](https://pub.dev/packages/graphql_flutter)
- [Drift Database](https://drift.simonbinder.eu/)
- [Riverpod Documentation](https://riverpod.dev/)
- [Recast Navigation](https://github.com/recastnavigation/recastnavigation)
- [NavMeshBuilder Swift Wrapper](https://github.com/vonture/NavMeshBuilder)
