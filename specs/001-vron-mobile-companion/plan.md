# Implementation Plan: VRON Mobile Companion

**Branch**: `001-vron-mobile-companion` | **Date**: 2025-11-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/001-vron-mobile-companion/spec.md`

**Note**: This plan defines the technical architecture for the VRON Mobile Flutter app with LiDAR scanning, GraphQL integration, and offline-first data sync.

## Summary

Build a Flutter 3.24+ mobile companion app for vron.one SaaS that enables realtors to authenticate via GraphQL, browse/manage real estate projects, scan rooms using LiDAR (iOS 16+) with on-device USDZ→GLB conversion, generate navigation meshes, and upload 3D assets with resumable chunked uploads. The app operates offline-first with 24-hour cache expiration, uses Riverpod for state management, Drift for local SQLite persistence syncing to vron.one Postgres via GraphQL, and integrates with existing GitHub Actions CI/CD for dev/stage/TestFlight builds. Guest mode allows unauthenticated room scanning trials, and curated sailing/aviation demos showcase VR commerce capabilities.

## Technical Context

**Language/Version**: Flutter 3.24+, Dart 3.5+, Swift 5.9 (iOS plugin), Kotlin 1.9 (Android plugin)

**Primary Dependencies**:
- `graphql_flutter` ^5.1.0 or `ferry` ^0.15.0 (GraphQL client with code generation)
- `riverpod` ^2.4.0 (state management)
- `drift` ^2.14.0 (local SQLite ORM for offline sync)
- `hive` ^2.2.3 (fast key-value cache for GraphQL responses)
- `flutter_secure_storage` ^9.0.0 (encrypted token storage)
- `three_dart` ^0.0.16 (GLB 3D rendering)
- Platform channels: RoomPlan (iOS 16+), Model I/O (iOS 16+), ARCore (Android API 29+)

**Storage**:
- Local: Drift SQLite database for structured data (projects, rooms, upload queue)
- Local: Hive for GraphQL response cache (24-hour TTL)
- Local: File system for temporary USDZ/GLB files during scanning/conversion
- Remote: vron.one Postgres via GraphQL mutations (dev: api.vron.stage.motorenflug.at/graphql)

**Testing**:
- `flutter_test` for unit and widget tests (80%+ coverage target)
- `integration_test` for platform channel contracts and E2E flows
- `golden_toolkit` for visual regression tests (login, projects list, 3D preview)
- `mockito` for GraphQL client and repository mocking
- iOS: XCTest for Swift plugin unit tests, Android: JUnit for Kotlin plugin tests

**Target Platform**: iOS 16+ (iPhone 12 Pro+ for LiDAR), Android API 29+ (graceful degradation: no scanning)

**Project Type**: Mobile (Flutter modular architecture with standalone packages)

**Performance Goals**:
- UI navigation: 60fps minimum on target devices (iPhone 12+, Android flagship 2021+)
- 3D preview rendering: 30fps minimum during scan playback
- App launch to projects list: <3 seconds with cached credentials
- USDZ→GLB conversion: <10 seconds for typical room (1000 vertices, 5 textures)
- GraphQL query perceived latency: <500ms (cache-first strategy)
- Navmesh generation: <15 seconds for typical geometry (1000-5000 vertices)

**Constraints**:
- Memory footprint: <300MB typical usage, <500MB peak during active scanning
- GLB file size: <50MB per room (enforced with proactive warnings + compression options)
- Device storage: Minimum 2GB free space required for scan processing and offline cache
- Offline-capable: Full project browsing and scanning without connectivity
- Spatial accuracy: 5cm tolerance for USDZ→GLB conversion
- Cache expiration: 24 hours with manual pull-to-refresh
- Upload retry: Exponential backoff (1s, 2s, 4s) max 3 attempts before queue

**Scale/Scope**:
- ~15-20 screens (login, projects list, project detail, scan flow, 3D viewer, settings, demos)
- ~10k-50k users (realtors) expected at launch
- ~50-100 projects per user average
- ~5-20 rooms per project average
- ~10-50MB per room scan (scene + navmesh GLB files)
- Real-time sync via GraphQL subscriptions for multi-device updates

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Verify compliance with VRON Mobile Constitution (v1.0.0):

- [x] **I. Native-First Performance**: ✅ **PASS**
  - Platform channels: RoomPlan (iOS), Model I/O (iOS), ARCore (Android), navmesh generation (native C++/Swift)
  - 60fps UI target specified in performance goals
  - 30fps 3D preview target specified for scan playback
  - Memory constraints defined: <300MB typical, <500MB peak

- [x] **II. Offline-First**: ✅ **PASS**
  - Full offline capability for project browsing and scanning
  - Drift SQLite for structured data persistence
  - Hive for GraphQL response cache (24-hour TTL)
  - Conflict resolution: last-write-wins with timestamp comparison
  - Upload queue with resumable chunks and exponential backoff retry

- [x] **III. TDD**: ✅ **PASS**
  - All 30 functional requirements have testable acceptance criteria
  - Testing framework specified: flutter_test, integration_test, golden_toolkit
  - 80%+ coverage target defined
  - Platform channel contracts will be tested on both Dart and native sides

- [x] **IV. Platform Integration**: ✅ **PASS**
  - Channel contracts will be versioned (scanRoom_v1, convertToGlb_v1, generateNavmesh_v1)
  - iOS implementation: RoomPlan, Model I/O (Swift plugins)
  - Android implementation: ARCore, GLB processing (Kotlin plugins)
  - Error codes defined: UNSUPPORTED_PLATFORM, LIDAR_UNAVAILABLE, PERMISSION_DENIED, SCAN_FAILED, CONVERSION_FAILED, NAVMESH_GENERATION_FAILED
  - Graceful degradation on Android (no scanning, project management only)

- [x] **V. Modular Architecture**: ✅ **PASS**
  - Standalone packages: `vron_graphql_client`, `room_scanner`, `asset_converter`, `vron_3d_viewer`
  - Feature modules: auth, scanning, asset_sync, commerce
  - Clean dependency injection via Riverpod providers
  - Clear boundaries between GraphQL client, auth, offline cache, 3D processing, UI layers

- [x] **VI. 3D Asset Fidelity**: ✅ **PASS**
  - USDZ→GLB conversion preserves PBR textures (albedo, normal, metallic, roughness)
  - Spatial accuracy: 5cm tolerance requirement
  - Automated tests will compare input USDZ texture count to output GLB texture count
  - Golden tests for 3D preview visual regression
  - File size validation: <50MB with proactive warnings and compression options

- [x] **VII. CI/CD**: ✅ **PASS**
  - Integration with existing GitHub Actions CI/CD
  - Dev/stage/TestFlight build automation with embedded build IDs
  - Automated gates: Dart analyzer (zero warnings), all tests passing, 80%+ coverage
  - iOS build verification, Android debug APK build
  - Fastlane for iOS signing and TestFlight upload

**Complexity Justifications**: None - all principles satisfied

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., packages/vron_graphql_client, lib/features/scanning).
-->

```text
# Flutter Mobile App Structure (VRON Mobile Constitution - Principle V: Modular Architecture)

packages/
├── vron_graphql_client/  # GraphQL operations, subscriptions, offline cache
│   ├── lib/
│   ├── test/
│   └── pubspec.yaml
├── room_scanner/         # Platform channels for LiDAR/ARCore
│   ├── lib/
│   ├── ios/             # Swift RoomPlan plugin
│   ├── android/         # Kotlin ARCore plugin
│   ├── test/
│   └── pubspec.yaml
├── asset_converter/      # USDZ→GLB, navmesh generation
│   ├── lib/
│   ├── ios/             # Swift Model I/O plugin
│   ├── android/         # Kotlin GLB processing
│   ├── test/
│   └── pubspec.yaml
└── vron_3d_viewer/       # 3D preview widget
    ├── lib/
    ├── test/
    └── pubspec.yaml

lib/
├── features/
│   ├── auth/            # Role-based auth matching SaaS
│   ├── scanning/        # Room scanning UI and stitching
│   ├── asset_sync/      # Real-time VR asset sync
│   └── commerce/        # Immersive product placement
├── shared/              # Common widgets, utilities
└── main.dart

test/
├── widget_test/         # Widget tests (TDD requirement)
├── integration_test/    # Platform channel integration tests
└── golden_test/         # Visual regression tests

ios/
└── Runner/              # iOS-specific native code

android/
└── app/                 # Android-specific native code
```

**Structure Decision**: This follows Principle V (Modular Architecture) with standalone
packages for reusable logic and feature-based organization in lib/. Platform channels
are isolated in dedicated packages with native code in ios/android subdirectories.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
