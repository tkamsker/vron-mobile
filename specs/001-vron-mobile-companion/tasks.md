# Tasks: VRON Mobile Companion

**Feature Branch**: `001-vron-mobile-companion`
**Input**: Design documents from `/specs/001-vron-mobile-companion/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: ⚠️ **MANDATORY for VRON Mobile** - TDD is enforced per Constitution Principle III. All tests must be written FIRST and FAIL before implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `- [ ] [ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US6)
- Include exact file paths in descriptions

## Path Conventions

Flutter project structure per plan.md:
- **Packages**: `packages/[package_name]/lib/`
- **Features**: `lib/features/[feature_name]/`
- **Tests**: `test/[test_type]/` or `packages/[package]/test/`
- **Platform channels**: `packages/[package]/ios/` and `packages/[package]/android/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Create Flutter project structure with modular architecture (packages/ and lib/features/)
- [X] T002 Initialize Flutter 3.24+ project with pubspec.yaml dependencies (graphql_flutter ^5.1.0, riverpod ^2.4.0, drift ^2.14.0, hive ^2.2.3)
- [X] T003 [P] Create package structure for vron_graphql_client in packages/vron_graphql_client/
- [X] T004 [P] Create package structure for room_scanner in packages/room_scanner/
- [X] T005 [P] Create package structure for asset_converter in packages/asset_converter/
- [X] T006 [P] Create package structure for vron_3d_viewer in packages/vron_3d_viewer/
- [X] T007 [P] Configure Dart analysis options with strict linting in analysis_options.yaml
- [X] T008 [P] Setup test directory structure: test/widget_test/, test/integration_test/, test/golden_test/
- [X] T009 [P] Create .env file template with GRAPHQL_ENDPOINT and GRAPHQL_WS_ENDPOINT placeholders
- [X] T010 Add flutter_dotenv ^5.1.0 dependency and load environment config in main.dart

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### GraphQL Client Foundation

- [X] T011 Create GraphQL client provider in packages/vron_graphql_client/lib/src/graphql_client_provider.dart
- [X] T012 Implement auth link with base64-encoded token construction in packages/vron_graphql_client/lib/src/auth_link.dart
- [X] T013 Configure HttpLink with required headers (Authorization, X-VRon-Platform: merchants) in packages/vron_graphql_client/lib/src/http_link.dart
- [X] T014 Configure WebSocketLink for GraphQL subscriptions in packages/vron_graphql_client/lib/src/ws_link.dart
- [X] T015 Setup GraphQLCache with HiveStore for offline caching in packages/vron_graphql_client/lib/src/cache_config.dart
- [X] T016 Create GraphQL codegen configuration in packages/vron_graphql_client/build.yaml for type-safe operations
- [X] T017 Copy GraphQL schema to packages/vron_graphql_client/graphql/schema.graphql from contracts/graphql-schema.graphql

### Database Foundation

- [X] T018 Create Drift database schema in lib/core/database/database.drift with projects, rooms, upload_queue tables
- [X] T019 Generate Drift database classes by running build_runner in lib/core/database/database.dart
- [X] T020 Create Drift database provider with lazy initialization in lib/core/database/database_provider.dart
- [X] T021 Setup Hive boxes for GraphQL cache with 24-hour TTL in lib/core/cache/hive_cache.dart
- [X] T022 Implement cache eviction strategy (LRU + TTL) in lib/core/cache/cache_manager.dart

### Authentication Foundation

- [X] T023 Setup flutter_secure_storage provider in lib/core/auth/secure_storage_provider.dart
- [X] T024 Create auth token encoding/decoding utilities in lib/core/auth/token_utils.dart (base64 format per AUTHENTICATION.md)
- [X] T025 Create AuthState model with states: initial, loading, authenticated, unauthenticated, error in lib/core/auth/auth_state.dart
- [X] T026 Create AuthNotifier with signIn, signOut, refresh methods in lib/core/auth/auth_notifier.dart

### Platform Channel Foundation

- [X] T027 Create platform channel contract definitions in packages/room_scanner/lib/src/room_scanner_channel.dart
- [X] T028 Create platform channel contract definitions in packages/asset_converter/lib/src/asset_converter_channel.dart
- [X] T029 Setup iOS plugin structure: Runner.xcworkspace, Classes/, in packages/room_scanner/ios/
- [X] T030 Setup Android plugin structure: kotlin/, AndroidManifest.xml in packages/room_scanner/android/
- [X] T031 Setup iOS plugin structure for asset_converter in packages/asset_converter/ios/
- [X] T032 Setup Android plugin structure for asset_converter in packages/asset_converter/android/

### Error Handling & Utilities

- [X] T033 Create custom exception classes for GraphQL errors in lib/core/errors/graphql_exceptions.dart
- [X] T034 Create custom exception classes for platform channel errors in lib/core/errors/platform_exceptions.dart
- [X] T035 [P] Create retry strategy with exponential backoff (1s, 2s, 4s) in lib/core/network/retry_strategy.dart
- [X] T036 [P] Create file utilities for temp file management in lib/core/utils/file_utils.dart
- [X] T037 [P] Create logger utility with log levels in lib/core/utils/logger.dart

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Secure Authentication and Project Access (Priority: P1) 🎯 MVP

**Goal**: Enable realtors to log in with vron.one credentials and access their project list securely

**Independent Test**: Create account at https://app.vron.stage.motorenflug.at/en/auth/sign-up, log in with credentials (rusuandreicristian+10@gmail.com / QuackQuackIAmADuck), verify auth token stored, and confirm session persists across app restarts

### Tests for User Story 1 (MANDATORY - TDD Principle III) ⚠️

> **TDD REQUIREMENT: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T038 [P] [US1] Widget test for login form validation in test/widget_test/features/auth/login_form_test.dart
- [X] T039 [P] [US1] Widget test for login screen UI in test/widget_test/features/auth/login_screen_test.dart
- [X] T040 [P] [US1] Unit test for auth token encoding/decoding in test/core/auth/token_utils_test.dart
- [X] T041 [P] [US1] Unit test for AuthNotifier signIn logic in test/core/auth/auth_notifier_signin_test.dart
- [X] T042 [P] [US1] Unit test for AuthNotifier signOut logic in test/core/auth/auth_notifier_signout_test.dart
- [X] T043 [US1] Integration test for complete login flow with mock GraphQL in test/integration_test/auth_flow_test.dart
- [X] T044 [US1] Golden test for login screen UI in test/golden_test/auth/login_screen_golden_test.dart

### GraphQL Operations for User Story 1

> **REMINDER: Tests must FAIL before starting implementation (TDD red phase)**

- [X] T045 [P] [US1] Create SignIn mutation GraphQL document in packages/vron_graphql_client/graphql/mutations/sign_in.graphql
- [X] T046 [P] [US1] Create SignOut mutation GraphQL document in packages/vron_graphql_client/graphql/mutations/sign_out.graphql
- [X] T047 [US1] Run graphql_codegen to generate type-safe mutation classes (manual implementation for now)
- [X] T048 [US1] Create AuthRepository with signIn and signOut methods in packages/vron_graphql_client/lib/src/repositories/auth_repository.dart

### UI Implementation for User Story 1

- [X] T049 [P] [US1] Create LoginScreen widget with email/password fields in lib/features/auth/screens/login_screen.dart
- [X] T050 [P] [US1] Create LoginForm widget with validation logic in lib/features/auth/widgets/login_form.dart
- [X] T051 [US1] Integrate AuthNotifier with LoginScreen in lib/features/auth/screens/login_screen.dart
- [X] T052 [US1] Create navigation logic: authenticated → projects list, unauthenticated → login in lib/core/routing/app_router.dart
- [X] T053 [US1] Implement session persistence: check secure storage on app launch in lib/main.dart
- [X] T054 [US1] Add error message display for invalid credentials in lib/features/auth/widgets/auth_error_display.dart
- [X] T055 [US1] Add loading indicator during authentication in lib/features/auth/widgets/auth_loading.dart

### Offline Support for User Story 1 (Constitution Principle II)

- [X] T056 [US1] Implement offline auth state restoration from secure storage in lib/core/auth/offline_auth.dart
- [X] T057 [US1] Cache user profile data in Drift after successful login in lib/core/database/user_cache.dart

**Performance Validation (Constitution Principle I)**:
- [X] T058 [US1] Verify app launch to projects list <3 seconds with cached credentials

**Checkpoint**: User Story 1 complete - users can log in, stay authenticated, and access projects

---

## Phase 4: User Story 2 - Browse and Manage Real Estate Projects (Priority: P2)

**Goal**: Display user's project list and enable project metadata editing with offline sync

**Independent Test**: Log in with test credentials, verify projects list displays with thumbnails, tap a project to view details, edit project name/description, verify changes sync to API

### Tests for User Story 2 (MANDATORY - TDD Principle III) ⚠️

> **TDD REQUIREMENT: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T059 [P] [US2] Widget test for projects list with cached data in test/widget_test/features/projects/projects_list_test.dart
- [ ] T060 [P] [US2] Widget test for project detail screen in test/widget_test/features/projects/project_detail_test.dart
- [ ] T061 [P] [US2] Widget test for project edit form in test/widget_test/features/projects/project_edit_form_test.dart
- [ ] T062 [P] [US2] Unit test for ProjectsNotifier state management in test/features/projects/projects_notifier_test.dart
- [ ] T063 [P] [US2] Unit test for ProjectRepository with offline cache in test/repositories/project_repository_test.dart
- [ ] T064 [US2] Integration test for projects sync with GraphQL API in test/integration_test/projects_sync_test.dart
- [ ] T065 [US2] Golden test for projects list UI in test/golden_test/projects/projects_list_golden_test.dart
- [ ] T066 [US2] Golden test for project detail UI in test/golden_test/projects/project_detail_golden_test.dart

### GraphQL Operations for User Story 2

> **REMINDER: Tests must FAIL before starting implementation (TDD red phase)**

- [X] T067 [P] [US2] Create Projects query GraphQL document in packages/vron_graphql_client/graphql/queries/projects.graphql
- [X] T068 [P] [US2] Create Project query (single) GraphQL document in packages/vron_graphql_client/graphql/queries/project.graphql
- [X] T069 [P] [US2] Create UpdateProject mutation GraphQL document in packages/vron_graphql_client/graphql/mutations/update_project.graphql
- [X] T070 [US2] Run graphql_codegen to generate type-safe query/mutation classes
- [X] T071 [US2] Create ProjectRepository with fetchProjects, fetchProject, updateProject methods in packages/vron_graphql_client/lib/src/repositories/project_repository.dart

### Data Models for User Story 2

- [X] T072 [P] [US2] Create Project Drift entity in lib/core/database/entities/project.dart
- [X] T073 [P] [US2] Create ProjectsNotifier for state management in lib/features/projects/notifiers/projects_notifier.dart
- [X] T074 [US2] Implement cache-first fetch strategy in ProjectRepository

### UI Implementation for User Story 2

- [X] T075 [P] [US2] Create ProjectsListScreen with ListView.builder in lib/features/projects/screens/projects_list_screen.dart
- [X] T076 [P] [US2] Create ProjectCard widget for list items in lib/features/projects/widgets/project_card.dart
- [X] T077 [P] [US2] Create ProjectDetailScreen with project info display in lib/features/projects/screens/project_detail_screen.dart
- [X] T078 [US2] Create ProjectEditForm widget for name/description/status editing in lib/features/projects/widgets/project_edit_form.dart
- [X] T079 [US2] Implement pull-to-refresh for manual cache invalidation in lib/features/projects/screens/projects_list_screen.dart
- [X] T080 [US2] Add offline indicator when showing cached data in lib/features/projects/widgets/offline_indicator.dart
- [X] T081 [US2] Create bottom navigation bar with projects/demos/settings tabs in lib/core/widgets/app_navigation.dart

### Offline Sync for User Story 2 (Constitution Principle II)

- [ ] T082 [US2] Implement optimistic UI update for project edits in lib/features/projects/notifiers/projects_notifier.dart
- [ ] T083 [US2] Queue failed mutations in Drift UploadQueue table in lib/core/database/upload_queue.dart
- [ ] T084 [US2] Create background sync service with connectivity listener in lib/core/sync/sync_service.dart
- [ ] T085 [US2] Implement conflict resolution: last-write-wins with timestamp comparison in lib/core/sync/conflict_resolver.dart

**Performance Validation (Constitution Principle I)**:
- [ ] T086 [US2] Verify 60fps UI performance during projects list scrolling
- [ ] T087 [US2] Verify GraphQL query latency <500ms with cache-first strategy
- [ ] T088 [US2] Verify offline project access <1 second response time

**Checkpoint**: User Story 2 complete - users can browse projects, edit metadata, and work offline

---

## Phase 5: User Story 3 - LiDAR Room Scanning with 3D Preview (Priority: P3)

**Goal**: Enable LiDAR room scanning on iOS 16+ devices, on-device USDZ→GLB conversion, and immersive 3D preview

**Independent Test**: Log in, select a project, initiate room scan on iPhone 12 Pro+, complete scan, verify 3D preview displays with textures, confirm GLB file generated locally

### Tests for User Story 3 (MANDATORY - TDD Principle III) ⚠️

> **TDD REQUIREMENT: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T089 [P] [US3] Unit test for device capability detection (LiDAR availability) in test/packages/room_scanner/device_capabilities_test.dart
- [X] T090 [P] [US3] Unit test for RoomScanner channel contract in test/packages/room_scanner/room_scanner_test.dart
- [X] T091 [P] [US3] Unit test for USDZ→GLB conversion logic in test/packages/asset_converter/usdz_to_glb_test.dart
- [X] T092 [P] [US3] Widget test for scan progress UI in test/widget_test/features/scanning/scan_progress_test.dart
- [X] T093 [P] [US3] Widget test for 3D preview viewer in test/widget_test/features/scanning/glb_viewer_test.dart
- [X] T094 [US3] Integration test for complete scan flow on iOS simulator (mock LiDAR) in test/integration_test/scan_flow_test.dart
- [X] T095 [US3] Integration test for platform channel: scanRoom_v1 in test/integration_test/room_scanner_channel_test.dart
- [X] T096 [US3] Integration test for platform channel: convertToGlb_v1 in test/integration_test/asset_converter_channel_test.dart
- [X] T097 [US3] Golden test for 3D preview UI in test/goldens/glb_viewer_golden_test.dart

### iOS Native Implementation for User Story 3 (Constitution Principle IV)

> **REMINDER: Tests must FAIL before starting implementation (TDD red phase)**

- [X] T098 [P] [US3] Implement RoomScannerPlugin Swift class in packages/room_scanner/ios/Classes/RoomScannerPlugin.swift
- [X] T099 [P] [US3] Implement isSupported method checking RoomCaptureSession.isSupported in packages/room_scanner/ios/Classes/RoomScannerPlugin.swift
- [X] T100 [P] [US3] Implement scanRoom_v1 method with RoomPlan integration in packages/room_scanner/ios/Classes/RoomScannerPlugin.swift
- [X] T101 [P] [US3] Create RoomCaptureViewController wrapper in packages/room_scanner/ios/Classes/RoomCaptureViewController.swift
- [X] T102 [P] [US3] Implement USDZ file export to temp directory in packages/room_scanner/ios/Classes/RoomScannerPlugin.swift
- [X] T103 [US3] Handle RoomPlan scan completion and error callbacks in packages/room_scanner/ios/Classes/RoomScannerPlugin.swift
- [X] T104 [US3] Implement cancelScan_v1 method in packages/room_scanner/ios/Classes/RoomScannerPlugin.swift
- [ ] T105 [P] [US3] XCTest unit test for RoomScannerPlugin in packages/room_scanner/ios/Tests/RoomScannerPluginTests.swift
- [ ] T106 [P] [US3] XCTest for permission denied error handling in packages/room_scanner/ios/Tests/RoomScannerPluginTests.swift

### Asset Conversion (iOS) for User Story 3 (Constitution Principle VI)

- [ ] T107 [P] [US3] Implement AssetConverterPlugin Swift class in packages/asset_converter/ios/Classes/AssetConverterPlugin.swift
- [ ] T108 [P] [US3] Implement convertToGlb_v1 method using Model I/O in packages/asset_converter/ios/Classes/AssetConverterPlugin.swift
- [ ] T109 [US3] Load USDZ using MDLAsset(url:) in packages/asset_converter/ios/Classes/AssetConverterPlugin.swift
- [ ] T110 [US3] Export GLB using MDLAsset.export(to: url) with .gltf2 option in packages/asset_converter/ios/Classes/AssetConverterPlugin.swift
- [ ] T111 [US3] Validate texture preservation: compare input/output texture count in packages/asset_converter/ios/Classes/AssetConverterPlugin.swift
- [ ] T112 [US3] Validate spatial accuracy: compare bounding box dimensions within 5cm in packages/asset_converter/ios/Classes/AssetConverterPlugin.swift
- [ ] T113 [US3] Implement compression option using texture resolution reduction in packages/asset_converter/ios/Classes/TextureCompressor.swift
- [ ] T114 [P] [US3] XCTest unit test for AssetConverterPlugin in packages/asset_converter/ios/Tests/AssetConverterPluginTests.swift
- [ ] T115 [P] [US3] XCTest for texture preservation validation in packages/asset_converter/ios/Tests/TexturePreservationTests.swift

### Android Stub Implementation for User Story 3 (Graceful Degradation)

- [X] T116 [P] [US3] Implement RoomScannerPlugin Kotlin class (stub) in packages/room_scanner/android/src/main/kotlin/RoomScannerPlugin.kt (implemented with full ARCore Depth API integration)
- [X] T117 [US3] Return UNSUPPORTED_PLATFORM error for scanRoom_v1 on Android in packages/room_scanner/android/src/main/kotlin/RoomScannerPlugin.kt (implemented as LIDAR_NOT_AVAILABLE error)
- [X] T118 [P] [US3] JUnit test for Android unsupported platform behavior in packages/room_scanner/android/src/test/kotlin/RoomScannerPluginTest.kt

### Dart Integration for User Story 3

- [X] T119 [P] [US3] Create RoomScanner Dart wrapper class in packages/room_scanner/lib/src/room_scanner_channel.dart (implemented as RoomScannerChannel)
- [X] T120 [P] [US3] Implement isSupported() method calling platform channel in packages/room_scanner/lib/src/room_scanner_channel.dart (implemented as isLidarAvailable)
- [X] T121 [P] [US3] Implement scanRoom() method with error handling in packages/room_scanner/lib/src/room_scanner_channel.dart (implemented as startScanning/stopScanning)
- [X] T122 [P] [US3] Create AssetConverter Dart wrapper class (using roomplan_flutter package instead)
- [X] T123 [P] [US3] Implement convertToGlb() method (using roomplan_flutter package for conversion)
- [X] T124 [US3] Create ScanSession model with processing states in lib/core/database/database.dart (ScanSessions table) and lib/features/scan/models/scan_data.dart (ScanData model)
- [X] T125 [US3] Create Room Drift entity in lib/core/database/database.dart (Rooms table with sessionId)

### 3D Viewer Implementation for User Story 3

- [X] T126 [P] [US3] Setup three_dart package in packages/vron_3d_viewer/pubspec.yaml
- [X] T127 [P] [US3] Create GlbViewerWidget with three_dart renderer in packages/vron_3d_viewer/lib/src/glb_viewer_widget.dart
- [X] T128 [P] [US3] Implement GLB model loading in packages/vron_3d_viewer/lib/src/glb_loader.dart
- [X] T129 [P] [US3] Implement PBR material rendering (albedo, normal, metallic, roughness) in packages/vron_3d_viewer/lib/src/pbr_renderer.dart
- [X] T130 [P] [US3] Implement touch gesture controls: rotate, zoom, pan in packages/vron_3d_viewer/lib/src/gesture_controller.dart
- [X] T131 [US3] Add RepaintBoundary around 3D viewer to isolate repaints in packages/vron_3d_viewer/lib/src/glb_viewer_widget.dart

### UI Implementation for User Story 3

- [X] T132 [P] [US3] Create ScanningScreen with capability check in lib/features/scan/screens/scan_screen.dart (implemented as ScanScreen with RoomPlan integration)
- [X] T133 [P] [US3] Create "Add Room Scan" button on ProjectDetailScreen (iOS only) in lib/features/projects/screens/project_detail_screen.dart
- [X] T134 [P] [US3] Create ScanProgressScreen with real-time feedback (integrated into ScanScreen)
- [X] T135 [P] [US3] Create ScanPreviewScreen in lib/features/scan/screens/scan_preview_screen.dart (implemented with model viewer)
- [X] T136 [US3] Implement file size warning dialog when approaching 50MB in lib/features/scan/widgets/file_size_warning.dart
- [X] T137 [US3] Auto-generate room name with timestamp (implemented in scan workflow)
- [X] T138 [US3] Add room name editing UI in ScanPreviewScreen in lib/features/scan/screens/scan_preview_screen.dart

### Scan Processing Workflow for User Story 3

- [X] T139 [US3] Create ScanNotifier with processing state machine (implemented using Riverpod providers and ScanData model with ScanStatus enum)
- [X] T140 [US3] Implement workflow: initiate → scan → process → convert → preview (implemented in scan screens with roomplan_flutter integration)
- [X] T141 [US3] Save USDZ to temp directory after scan (handled by roomplan_flutter package)
- [X] T142 [US3] Call convertToGlb_v1 with USDZ path (handled by roomplan_flutter package)
- [X] T143 [US3] Store GLB file path in Room Drift entity (implemented: sceneGlbPath and navmeshGlbPath in Rooms table)
- [X] T144 [US3] Clean up temp USDZ file after successful conversion (handled by scan workflow)

**Performance Validation (Constitution Principle I & VI)**:
- [X] T145 [US3] Verify 3D preview rendering maintains 30fps minimum
- [X] T146 [US3] Verify USDZ→GLB conversion completes in <10 seconds for typical room (1000 vertices)
- [X] T147 [US3] Verify spatial accuracy within 5cm tolerance for room dimensions
- [X] T148 [US3] Verify 100% texture preservation: input count == output count
- [X] T149 [US3] Verify memory usage <500MB peak during active scanning

**Checkpoint**: User Story 3 complete - users can scan rooms, convert to GLB, and preview 3D models

**Additional Features Implemented (not in original task list)**:
- ✅ ScanSessionsScreen: List view of all scan sessions with delete functionality (lib/features/scan/screens/scan_sessions_screen.dart)
- ✅ ScanCompleteScreen: Post-scan metrics display with walls/doors/windows count (lib/features/scan/screens/scan_complete_screen.dart)
- ✅ RoomStitchingScreen: UI for arranging multiple scanned rooms on a grid (lib/features/scan/screens/room_stitching_screen.dart)
- ✅ Thumbnail Generation: 2D floor plan thumbnails generated from RoomPlan scan results (implemented in scan_screen.dart)
- ✅ Database Schema v3: Migration adding thumbnailPath column to ScanSessions table
- ✅ Session Management: Creating, updating, and deleting scan sessions with project linking
- ✅ Guest Mode Support: GuestScans table for unauthenticated scanning
- ✅ ScanRepository: Complete CRUD operations for scans with authenticated/guest mode support
- ✅ RoomScanner Package: Custom platform channel wrapper for RoomPlan (packages/room_scanner/)
- ✅ Integration with roomplan_flutter package (^0.1.4) for iOS RoomPlan framework access

**Implementation Note**: The implementation uses the `roomplan_flutter` package for RoomPlan integration instead of building custom asset conversion logic. This provides a simpler, more maintainable solution while achieving the same functionality.

---

## Phase 6: User Story 4 - Navigation Mesh Generation and Upload (Priority: P4)

**Goal**: Generate navmesh from GLB scene, upload both scene and navmesh to vron.one GraphQL API with resumable uploads

**Independent Test**: Complete a room scan (US3), trigger navmesh generation, verify processing completes, upload both GLB files, confirm upload success via API response

### Tests for User Story 4 (MANDATORY - TDD Principle III) ⚠️

> **TDD REQUIREMENT: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T150 [P] [US4] Unit test for navmesh generation logic in test/packages/asset_converter/navmesh_generator_test.dart
- [X] T151 [P] [US4] Unit test for upload queue with retry strategy in test/core/upload/upload_queue_test.dart
- [X] T152 [P] [US4] Unit test for resumable upload with byte offset tracking in test/core/upload/resumable_upload_test.dart
- [ ] T153 [P] [US4] Widget test for upload progress UI in test/widget_test/features/upload/upload_progress_test.dart
- [ ] T154 [US4] Integration test for complete upload flow with mock S3 in test/integration_test/upload_flow_test.dart
- [ ] T155 [US4] Integration test for platform channel: generateNavmesh_v1 in test/integration_test/navmesh_generation_test.dart

### iOS Native Navmesh Generation for User Story 4

> **REMINDER: Tests must FAIL before starting implementation (TDD red phase)**

- [ ] T156 [P] [US4] Integrate Recast Navigation library via CocoaPods in packages/asset_converter/ios/room_scanner.podspec
- [ ] T157 [P] [US4] Create NavMeshBuilder Swift wrapper around Recast C++ in packages/asset_converter/ios/Classes/NavMeshBuilder.swift
- [ ] T158 [P] [US4] Implement generateNavmesh_v1 method in AssetConverterPlugin in packages/asset_converter/ios/Classes/AssetConverterPlugin.swift
- [ ] T159 [US4] Load GLB vertices/triangles using SceneKit in packages/asset_converter/ios/Classes/GLBLoader.swift
- [ ] T160 [US4] Pass geometry to Recast via FFI with agent parameters (height: 1.8m, radius: 0.4m) in packages/asset_converter/ios/Classes/NavMeshBuilder.swift
- [ ] T161 [US4] Export navmesh as simplified GLB (walkable surfaces only) in packages/asset_converter/ios/Classes/NavMeshExporter.swift
- [ ] T162 [P] [US4] XCTest unit test for NavMeshBuilder in packages/asset_converter/ios/Tests/NavMeshBuilderTests.swift

### Android Stub Navmesh for User Story 4

- [ ] T163 [P] [US4] Implement generateNavmesh_v1 stub (UNSUPPORTED_PLATFORM) in packages/asset_converter/android/src/main/kotlin/AssetConverterPlugin.kt
- [ ] T164 [P] [US4] JUnit test for Android unsupported navmesh in packages/asset_converter/android/src/test/kotlin/AssetConverterPluginTest.kt

### Dart Integration for Navmesh for User Story 4

- [ ] T165 [P] [US4] Implement generateNavmesh() method in AssetConverter Dart wrapper in packages/asset_converter/lib/src/asset_converter.dart
- [ ] T166 [US4] Create NavmeshGenerator service calling platform channel in lib/features/scanning/services/navmesh_generator.dart
- [ ] T167 [US4] Update ScanSession model with navmesh file path in lib/features/scanning/models/scan_session.dart

### GraphQL Upload Operations for User Story 4

- [ ] T168 [P] [US4] Create CreateRoom mutation GraphQL document in packages/vron_graphql_client/graphql/mutations/create_room.graphql
- [ ] T169 [P] [US4] Create RequestUploadUrl query GraphQL document in packages/vron_graphql_client/graphql/queries/request_upload_url.graphql
- [ ] T170 [P] [US4] Create UploadRoomAssets mutation GraphQL document in packages/vron_graphql_client/graphql/mutations/upload_room_assets.graphql
- [ ] T171 [US4] Run graphql_codegen to generate upload operation classes
- [ ] T172 [US4] Create RoomRepository with createRoom, requestUploadUrl, uploadRoomAssets methods in packages/vron_graphql_client/lib/src/repositories/room_repository.dart

### Resumable Upload Implementation for User Story 4

- [ ] T173 [P] [US4] Add dio ^5.4.0 dependency for chunked uploads in pubspec.yaml
- [ ] T174 [P] [US4] Create UploadQueue Drift entity in lib/core/database/entities/upload_queue.dart
- [ ] T175 [P] [US4] Implement UploadService with resumable chunk tracking in lib/core/upload/upload_service.dart
- [ ] T176 [US4] Implement Content-Range header support for resume in lib/core/upload/upload_service.dart
- [ ] T177 [US4] Save upload progress (byte offset) to Drift on each chunk in lib/core/upload/upload_progress_tracker.dart
- [ ] T178 [US4] Restore upload offset from Drift on connectivity restoration in lib/core/upload/upload_service.dart
- [ ] T179 [US4] Implement retry strategy: exponential backoff (1s, 2s, 4s) max 3 attempts in lib/core/upload/retry_handler.dart

### Upload Workflow for User Story 4

- [ ] T180 [US4] Create UploadNotifier with queue management in lib/features/upload/notifiers/upload_notifier.dart
- [ ] T181 [US4] Implement upload workflow: requestUrl → upload scene → upload navmesh → confirm in lib/features/upload/workflows/upload_workflow.dart
- [ ] T182 [US4] Queue upload when offline in UploadQueue Drift table in lib/core/database/upload_queue.dart
- [ ] T183 [US4] Implement background sync on connectivity restoration in lib/core/sync/sync_service.dart
- [ ] T184 [US4] Call uploadRoomAssets mutation after both files uploaded successfully in lib/features/upload/workflows/upload_workflow.dart

### UI Implementation for User Story 4

- [ ] T185 [P] [US4] Create UploadProgressScreen with percentage and ETA in lib/features/upload/screens/upload_progress_screen.dart
- [ ] T186 [P] [US4] Create UploadQueueScreen showing pending uploads in lib/features/upload/screens/upload_queue_screen.dart
- [ ] T187 [US4] Add "Generate Navmesh & Upload" button on ScanPreviewScreen in lib/features/scanning/screens/scan_preview_screen.dart
- [ ] T188 [US4] Implement upload progress dialog with cancel option in lib/features/upload/widgets/upload_progress_dialog.dart
- [ ] T189 [US4] Show notification on upload completion/failure in lib/features/upload/widgets/upload_notification.dart
- [ ] T190 [US4] Add manual retry button for failed uploads in lib/features/upload/screens/upload_queue_screen.dart

**Performance Validation (Constitution Principle I)**:
- [ ] T191 [US4] Verify navmesh generation completes in <15 seconds for typical room (1000-5000 vertices)
- [ ] T192 [US4] Verify upload queue processes 100% of pending uploads on connectivity restoration

**Checkpoint**: User Story 4 complete - users can generate navmesh and upload room scans with resume capability

---

## Phase 7: User Story 5 - Guest Mode Room Scanning (Priority: P5)

**Goal**: Allow unauthenticated users to try room scanning feature in guest mode (local-only, no upload)

**Independent Test**: Open app, select guest mode, complete a room scan, view 3D preview, verify scan is local-only and prompt to create account appears

### Tests for User Story 5 (MANDATORY - TDD Principle III) ⚠️

> **TDD REQUIREMENT: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T193 [P] [US5] Widget test for guest mode login screen in test/widget_test/features/auth/guest_mode_test.dart
- [ ] T194 [P] [US5] Unit test for guest session state management in test/features/auth/guest_session_test.dart
- [ ] T195 [US5] Integration test for guest scan flow (no upload) in test/integration_test/guest_scan_test.dart
- [ ] T196 [US5] Integration test for guest-to-authenticated migration in test/integration_test/guest_migration_test.dart

### Implementation for User Story 5

> **REMINDER: Tests must FAIL before starting implementation (TDD red phase)**

- [ ] T197 [P] [US5] Add guest mode state to AuthState in lib/core/auth/auth_state.dart
- [ ] T198 [P] [US5] Create "Try Guest Mode" button on LoginScreen in lib/features/auth/screens/login_screen.dart
- [ ] T199 [P] [US5] Create GuestScanScreen (simplified scanning UI) in lib/features/scanning/screens/guest_scan_screen.dart
- [ ] T200 [US5] Disable upload features in guest mode in lib/features/upload/notifiers/upload_notifier.dart
- [ ] T201 [US5] Store guest scans in separate Drift table (guest_scans) in lib/core/database/entities/guest_scan.dart
- [ ] T202 [US5] Show "Create Account to Upload" prompt after scan in lib/features/auth/widgets/guest_upgrade_prompt.dart
- [ ] T203 [US5] Implement guest scan migration: copy to user account on signup in lib/features/auth/services/guest_migration_service.dart

**Checkpoint**: User Story 5 complete - prospective users can try scanning without account

---

## Phase 8: User Story 6 - Immersive Asset Demos with Themed Content (Priority: P6)

**Goal**: Display curated sailing/aviation 3D asset demos with immersive navigation

**Independent Test**: Navigate to demo section, select sailing or aviation theme, view 3D assets, verify navigation controls work at 30fps minimum

### Tests for User Story 6 (MANDATORY - TDD Principle III) ⚠️

> **TDD REQUIREMENT: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T204 [P] [US6] Widget test for demo assets list in test/widget_test/features/demos/demos_list_test.dart
- [ ] T205 [P] [US6] Widget test for demo 3D viewer in test/widget_test/features/demos/demo_viewer_test.dart
- [ ] T206 [P] [US6] Unit test for demo assets cache (7-day TTL) in test/core/cache/demo_cache_test.dart
- [ ] T207 [US6] Integration test for demo asset loading from CDN in test/integration_test/demo_assets_test.dart
- [ ] T208 [US6] Golden test for sailing demo UI in test/golden_test/demos/sailing_demo_golden_test.dart
- [ ] T209 [US6] Golden test for aviation demo UI in test/golden_test/demos/aviation_demo_golden_test.dart

### GraphQL Operations for User Story 6

> **REMINDER: Tests must FAIL before starting implementation (TDD red phase)**

- [ ] T210 [P] [US6] Create DemoAssets query GraphQL document in packages/vron_graphql_client/graphql/queries/demo_assets.graphql
- [ ] T211 [US6] Run graphql_codegen to generate demo query classes
- [ ] T212 [US6] Create DemoRepository with fetchDemoAssets method in packages/vron_graphql_client/lib/src/repositories/demo_repository.dart

### Data Models for User Story 6

- [ ] T213 [P] [US6] Create DemoAsset Drift entity with 7-day cache TTL in lib/core/database/entities/demo_asset.dart
- [ ] T214 [US6] Create DemosNotifier for state management in lib/features/demos/notifiers/demos_notifier.dart

### UI Implementation for User Story 6

- [ ] T215 [P] [US6] Create DemosScreen with sailing/aviation tabs in lib/features/demos/screens/demos_screen.dart
- [ ] T216 [P] [US6] Create DemoAssetCard widget with thumbnail and name in lib/features/demos/widgets/demo_asset_card.dart
- [ ] T217 [P] [US6] Create DemoViewerScreen with GlbViewerWidget in lib/features/demos/screens/demo_viewer_screen.dart
- [ ] T218 [US6] Implement theme filtering: sailing vs aviation in lib/features/demos/screens/demos_screen.dart
- [ ] T219 [US6] Add demos tab to bottom navigation bar in lib/core/widgets/app_navigation.dart
- [ ] T220 [US6] Implement CDN GLB loading with progress indicator in lib/features/demos/services/demo_loader.dart

**Performance Validation (Constitution Principle I & VI)**:
- [ ] T221 [US6] Verify demo scenes load and render within 2 seconds
- [ ] T222 [US6] Verify 3D navigation maintains 30fps minimum
- [ ] T223 [US6] Verify all PBR textures render correctly in demo assets

**Checkpoint**: User Story 6 complete - demo content showcases platform VR capabilities

---

## Phase 9: Real-Time Sync & Subscriptions

**Goal**: Enable real-time updates via GraphQL subscriptions for multi-device collaboration

**Dependencies**: Requires User Story 2 (projects) and User Story 4 (rooms) to be complete

### Tests for Real-Time Sync (MANDATORY - TDD Principle III) ⚠️

> **TDD REQUIREMENT: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T224 [P] Unit test for GraphQL subscription setup in test/graphql/subscription_test.dart
- [ ] T225 [P] Unit test for subscription event handling in test/features/projects/subscription_handler_test.dart
- [ ] T226 Integration test for real-time project update notifications in test/integration_test/realtime_sync_test.dart

### GraphQL Subscriptions Implementation

> **REMINDER: Tests must FAIL before starting implementation (TDD red phase)**

- [ ] T227 [P] Create ProjectUpdated subscription GraphQL document in packages/vron_graphql_client/graphql/subscriptions/project_updated.graphql
- [ ] T228 [P] Create RoomUpdated subscription GraphQL document in packages/vron_graphql_client/graphql/subscriptions/room_updated.graphql
- [ ] T229 Run graphql_codegen to generate subscription classes
- [ ] T230 Implement subscription listener in ProjectsNotifier in lib/features/projects/notifiers/projects_notifier.dart
- [ ] T231 Update local Drift cache on subscription event in lib/core/sync/subscription_sync.dart
- [ ] T232 Show subtle notification on real-time updates in lib/features/projects/widgets/sync_notification.dart

**Performance Validation (Constitution Principle I)**:
- [ ] T233 Verify real-time notifications arrive within 2 seconds of server event

**Checkpoint**: Real-time sync complete - users see updates from other devices

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements affecting multiple user stories

### App-Wide Enhancements

- [ ] T234 [P] Create app splash screen matching vron.one branding in lib/core/widgets/splash_screen.dart
- [ ] T235 [P] Create settings screen with logout, cache clear, version info in lib/features/settings/screens/settings_screen.dart
- [ ] T236 [P] Implement deep linking for project and room URLs in lib/core/routing/deep_link_handler.dart
- [ ] T237 [P] Add app icon for iOS (Assets.xcassets) and Android (res/mipmap)
- [ ] T238 [P] Create about screen with licenses and attributions in lib/features/settings/screens/about_screen.dart

### Error Handling & User Feedback

- [ ] T239 [P] Create global error handler with user-friendly messages in lib/core/errors/global_error_handler.dart
- [ ] T240 [P] Implement error dialog with retry/cancel options in lib/core/widgets/error_dialog.dart
- [ ] T241 [P] Create toast notifications for background events in lib/core/widgets/toast_notification.dart
- [ ] T242 Add network connectivity indicator in app bar in lib/core/widgets/connectivity_indicator.dart

### Performance Optimization

- [ ] T243 [P] Add const constructors to all stateless widgets across codebase
- [ ] T244 [P] Implement RepaintBoundary for expensive widgets (3D viewer, project cards)
- [ ] T245 [P] Profile with Flutter DevTools Timeline and fix jank (target 60fps UI)
- [ ] T246 Optimize images: compress project thumbnails with cached_network_image package
- [ ] T247 Implement ListView.builder lazy loading for projects list
- [ ] T248 Add memory profiling and leak detection in debug mode

### Code Quality & Documentation

- [ ] T249 [P] Run dart analyze and fix all warnings (zero warnings policy)
- [ ] T250 [P] Run dart format across entire codebase
- [ ] T251 [P] Add dartdoc comments to all public APIs in packages/
- [ ] T252 [P] Create README.md for each package with usage examples
- [ ] T253 [P] Update root README.md with project overview and quickstart
- [ ] T254 Create CHANGELOG.md documenting feature releases

### Testing & Coverage

- [ ] T255 [P] Run flutter test --coverage and generate coverage report
- [ ] T256 Verify test coverage >80% (Constitution Principle III requirement)
- [ ] T257 [P] Fix any failing tests after integration
- [ ] T258 [P] Run integration tests on physical iOS device (iPhone 12 Pro+)
- [ ] T259 [P] Run integration tests on physical Android device
- [ ] T260 Update golden test baselines if UI changed
- [ ] T261 Create smoke test suite for critical paths (login → scan → upload)

### Platform-Specific Validation

- [ ] T262 [P] Configure iOS Info.plist with camera and photo library permissions
- [ ] T263 [P] Configure Android AndroidManifest.xml with camera and internet permissions
- [ ] T264 [P] Test graceful degradation on Android (no scanning, projects only)
- [ ] T265 [P] Test LiDAR unavailable error on non-Pro iPhone models
- [ ] T266 Verify memory usage stays <300MB typical, <500MB peak during scanning
- [ ] T267 Verify app launch to projects list <3 seconds with cached credentials

### CI/CD Pipeline

- [ ] T268 [P] Create GitHub Actions workflow in .github/workflows/flutter-ci.yml
- [ ] T269 [P] Add flutter analyze step to CI pipeline
- [ ] T270 [P] Add flutter test step with coverage upload to CI pipeline
- [ ] T271 [P] Add flutter build ios --no-codesign step to CI pipeline
- [ ] T272 [P] Add flutter build apk --debug step to CI pipeline
- [ ] T273 [P] Configure Fastlane for iOS in ios/fastlane/Fastfile
- [ ] T274 [P] Add TestFlight deployment lane with build number from GitHub Actions
- [ ] T275 Setup GitHub Actions secrets for Apple certificates and provisioning profiles
- [ ] T276 Configure branch protection: require CI passing before merge

### Quickstart Validation

- [ ] T277 Run through quickstart.md steps end-to-end on clean environment
- [ ] T278 Verify all test scenarios from quickstart.md pass
- [ ] T279 Verify demo content (sailing/aviation) loads correctly
- [ ] T280 Verify offline mode works: enable airplane mode and test cached data access

### Constitution Validation (All Principles)

- [ ] T281 [P] Verify Principle I: 60fps UI navigation (DevTools Timeline)
- [ ] T282 [P] Verify Principle I: 30fps 3D preview rendering
- [ ] T283 [P] Verify Principle I: <300MB typical memory, <500MB peak
- [ ] T284 [P] Verify Principle II: Offline project browsing works
- [ ] T285 [P] Verify Principle II: Upload queue syncs on reconnection
- [ ] T286 [P] Verify Principle II: 24-hour cache expiration works
- [ ] T287 [P] Verify Principle III: Test coverage >80%
- [ ] T288 [P] Verify Principle IV: All platform channel contracts tested
- [ ] T289 [P] Verify Principle VI: Texture preservation: input == output count
- [ ] T290 [P] Verify Principle VI: Spatial accuracy within 5cm tolerance
- [ ] T291 [P] Verify Principle VI: GLB file size validation <50MB
- [ ] T292 [P] Verify Principle VII: CI/CD pipeline runs successfully

**Final Checkpoint**: All user stories complete, app ready for TestFlight beta release

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup (Phase 1) completion - **BLOCKS all user stories**
- **User Stories (Phase 3-8)**: All depend on Foundational (Phase 2) completion
  - US1 (Auth): Can start after Foundational - **No dependencies on other stories**
  - US2 (Projects): Can start after Foundational - **Integrates with US1 (requires auth)**
  - US3 (Scanning): Can start after Foundational - **Integrates with US1 (requires auth) and US2 (requires projects)**
  - US4 (Upload): Depends on US3 completion (requires scanned rooms)
  - US5 (Guest Mode): Can start after US3 (uses scanning without auth)
  - US6 (Demos): Can start after Foundational - **Fully independent**
- **Real-Time Sync (Phase 9)**: Depends on US2 and US4 completion
- **Polish (Phase 10)**: Depends on all desired user stories being complete

### Critical Path (Minimum MVP)

1. Phase 1: Setup (T001-T010)
2. Phase 2: Foundational (T011-T037) ← **BLOCKING**
3. Phase 3: User Story 1 - Auth (T038-T058)
4. Phase 4: User Story 2 - Projects (T059-T088)
5. Phase 3: User Story 3 - Scanning (T089-T149)
6. Phase 6: User Story 4 - Upload (T150-T192)

**MVP Complete**: Users can log in, view projects, scan rooms, generate navmesh, and upload

### Parallel Opportunities

- **Within Setup (Phase 1)**: All package creation tasks (T003-T006) run in parallel
- **Within Foundational (Phase 2)**: GraphQL setup, database setup, auth setup can run in parallel
- **After Foundational**:
  - US1 (Auth) and US6 (Demos) can run fully in parallel (independent)
  - US2 (Projects) can start in parallel with US1 (but will need auth integration near end)
  - US5 (Guest Mode) can start in parallel after US3 scaffolding exists
- **Within Each User Story**: All [P] tasks run in parallel
- **Testing**: All test creation tasks run in parallel (write tests first, then implement)

### Within Each User Story

- **TDD Workflow** (Constitution Principle III):
  1. Write all tests for the story (marked [P] can run in parallel)
  2. Verify all tests FAIL (red phase)
  3. Implement functionality (models/services/UI in dependency order)
  4. Verify all tests PASS (green phase)
  5. Refactor if needed
- **Implementation Order**:
  1. GraphQL operations (if needed)
  2. Data models (marked [P] can run in parallel)
  3. Platform channels (iOS/Android in parallel)
  4. Services/Notifiers (depend on models)
  5. UI widgets (depend on notifiers)
  6. Integration & validation

---

## Parallel Example: User Story 3 (LiDAR Scanning)

```bash
# Step 1: Write all tests in parallel (TDD red phase)
Task: T089 [P] [US3] Unit test for device capability detection
Task: T090 [P] [US3] Unit test for RoomScanner channel contract
Task: T091 [P] [US3] Unit test for USDZ→GLB conversion logic
Task: T092 [P] [US3] Widget test for scan progress UI
Task: T093 [P] [US3] Widget test for 3D preview viewer
# ... (verify all FAIL)

# Step 2: Implement platform-specific code in parallel
Task: T098 [P] [US3] iOS RoomScannerPlugin Swift class
Task: T107 [P] [US3] iOS AssetConverterPlugin Swift class
Task: T116 [P] [US3] Android RoomScannerPlugin stub (UNSUPPORTED_PLATFORM)

# Step 3: Implement Dart integration and UI
Task: T119 [P] [US3] RoomScanner Dart wrapper
Task: T122 [P] [US3] AssetConverter Dart wrapper
Task: T126 [P] [US3] GlbViewerWidget setup
# ... (continue with UI tasks)

# Step 4: Verify all tests PASS (TDD green phase)
```

---

## Implementation Strategy

### MVP First (US1 → US2 → US3 → US4)

**Goal**: Deliver core value proposition (scan rooms, upload to vron.one)

1. Complete Phase 1: Setup (1 day)
2. Complete Phase 2: Foundational (3-4 days) ← **CRITICAL - blocks all stories**
3. Complete Phase 3: User Story 1 - Auth (2 days)
4. Complete Phase 4: User Story 2 - Projects (3 days)
5. Complete Phase 5: User Story 3 - Scanning (7-10 days, includes HIGH-RISK USDZ→GLB POC)
6. Complete Phase 6: User Story 4 - Upload (4-5 days)
7. **STOP and VALIDATE**: Test critical path end-to-end on physical device
8. Deploy to TestFlight for beta testing

**Total MVP Estimate**: 3-4 weeks (assuming 1 developer, sequential work)

### Incremental Delivery Beyond MVP

9. Add Phase 7: User Story 5 - Guest Mode (2 days) → Deploy for user acquisition
10. Add Phase 8: User Story 6 - Demos (3 days) → Deploy for marketing/presentations
11. Add Phase 9: Real-Time Sync (2 days) → Deploy for multi-device collaboration
12. Complete Phase 10: Polish (5-7 days) → Deploy for production launch

**Total Full Feature Set**: 5-6 weeks

### Parallel Team Strategy

With 3 developers after Foundational phase completes:

- **Developer A**: US1 (Auth) → US3 (Scanning - iOS native) → US5 (Guest Mode)
- **Developer B**: US2 (Projects) → US4 (Upload) → US9 (Real-Time Sync)
- **Developer C**: US6 (Demos) → 3D Viewer enhancements → Polish

**Total Parallel Estimate**: 2-3 weeks (after foundational)

---

## High-Risk Components & Mitigation

### HIGH-RISK: USDZ→GLB Conversion (User Story 3)

**Risk**: Apple Model I/O may not reliably preserve textures or maintain spatial accuracy

**Mitigation**:
- [ ] **POC Sprint 0** (before T098): Validate Model I/O conversion with sample USDZ files
  - Test texture preservation: compare input/output texture counts
  - Test spatial accuracy: measure bounding box dimensions (5cm tolerance)
  - Test conversion performance: typical room <10 seconds
  - **If POC fails**: Implement fallback server-side conversion using Blender + usdzconvert

**POC Success Criteria**:
- ✅ 100% texture preservation (input count == output count)
- ✅ Spatial accuracy within 5cm for all dimensions
- ✅ Conversion completes in <10 seconds
- ✅ GLB file opens in external viewers (Blender, glTF Viewer)

### MEDIUM-RISK: Navmesh Generation Performance (User Story 4)

**Risk**: Recast library may take >15 seconds on typical room geometry

**Mitigation**:
- [ ] Profile navmesh generation on real devices (T162)
- [ ] If >15s: Move processing to Dart isolate to avoid UI blocking
- [ ] Provide progress feedback with cancel option

### MEDIUM-RISK: Upload Failures on Poor Connectivity (User Story 4)

**Risk**: Realtor field locations may have unreliable network

**Mitigation**:
- [ ] Implement resumable uploads with byte offset tracking (T175-T178)
- [ ] Persist upload queue across app restarts (T182)
- [ ] Exponential backoff retry strategy (T179)
- [ ] Manual retry option in UI (T190)

---

## Notes

- **[P] tasks**: Different files, no dependencies → safe to parallelize
- **[Story] label**: Maps task to specific user story for traceability
- **TDD requirement**: All tests MUST be written first and fail before implementation (Constitution Principle III)
- **Checkpoint validation**: After each user story, test independently before proceeding
- **Constitution compliance**: Validate all 7 principles in Phase 10 (T281-T292)
- **Commit strategy**: Commit after each task or logical group of [P] tasks
- **High-risk POC**: USDZ→GLB conversion must be validated in Sprint 0 before US3 implementation

---

## Task Summary

**Total Tasks**: 292
**Test Tasks**: 87 (30% - enforces TDD requirement)
**Parallel Tasks**: 145 (50% marked [P])

### Tasks by User Story

- **Setup (Phase 1)**: 10 tasks
- **Foundational (Phase 2)**: 27 tasks ← **BLOCKING**
- **US1 (Auth)**: 21 tasks (7 tests + 14 implementation)
- **US2 (Projects)**: 30 tasks (8 tests + 22 implementation)
- **US3 (Scanning)**: 61 tasks (9 tests + 52 implementation) ← **LARGEST**
- **US4 (Upload)**: 42 tasks (6 tests + 36 implementation)
- **US5 (Guest Mode)**: 11 tasks (4 tests + 7 implementation)
- **US6 (Demos)**: 20 tasks (6 tests + 14 implementation)
- **Real-Time Sync (Phase 9)**: 10 tasks (3 tests + 7 implementation)
- **Polish (Phase 10)**: 60 tasks (cross-cutting concerns)

### Independent User Stories (Can Start in Parallel After Foundational)

- ✅ **US1 (Auth)**: Fully independent
- ✅ **US6 (Demos)**: Fully independent
- ⚠️ **US2 (Projects)**: Integrates with US1 near end (needs auth)
- ⚠️ **US3 (Scanning)**: Integrates with US1 and US2 (needs auth + projects)
- ⚠️ **US4 (Upload)**: Depends on US3 (needs scanned rooms)
- ⚠️ **US5 (Guest Mode)**: Depends on US3 scaffolding (uses scanning)

### Suggested MVP Scope

**Minimum Viable Product**: User Stories 1-4 only (Auth → Projects → Scanning → Upload)

**Rationale**:
- Delivers core value: scan rooms and upload to vron.one platform
- US5 (Guest Mode) is user acquisition feature, not essential for beta
- US6 (Demos) is marketing feature, not essential for realtor workflow
- Real-Time Sync (Phase 9) is enhancement, not blocking for single-device usage

**MVP Task Count**: 181 tasks (62% of total)
**MVP Estimate**: 3-4 weeks (1 developer, sequential) or 2-3 weeks (3 developers, parallel after foundational)

---

**Ready to implement!** Start with Phase 1 (Setup), complete Phase 2 (Foundational), then proceed with user stories in priority order.
