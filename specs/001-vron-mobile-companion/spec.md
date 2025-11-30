# Feature Specification: VRON Mobile Companion

**Feature Branch**: `001-vron-mobile-companion`
**Created**: 2025-11-30
**Status**: Draft
**Input**: User description: "Build a Flutter mobile companion for vron.one SaaS per attached MD spec in Req directory in md format and layout screenshots. Enable GraphQL mutations/queries for VR/3D assets, real-time 3D previews, LiDAR scanning to GLB export (preserving textures), offline sync, user auth via SaaS tokens, and immersive navigation matching web layouts. Support sailing/aviation-themed asset demos."

## Clarifications

### Session 2025-11-30

- Q: What happens when a user loses internet connection mid-upload during a large GLB file transfer? → A: Resume upload from last successful chunk when connectivity restored
- Q: How does the system handle a room scan that produces a 3D model exceeding the 50MB file size limit? → A: Warn user during scan when approaching limit; offer compression or re-scan with reduced detail
- Q: How does the system handle multiple rooms scanned for the same project with naming conflicts? → A: Auto-generate name with timestamp, allow user to edit afterward
- Q: How does the app behave when GraphQL API returns errors or times out? → A: Exponential backoff with max 3 retries, then fall back to cached data and queue mutations
- Q: How long does cached GraphQL data remain valid before requiring refresh? → A: Expire after 24 hours, with manual pull-to-refresh option

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Secure Authentication and Project Access (Priority: P1)

A realtor logs into the VRON mobile app using their vron.one account credentials to access their real estate projects. The app authenticates with the vron.one GraphQL API and maintains the session securely for offline and online operations.

**Why this priority**: Authentication is the foundation for all other features. Without secure login and session management, users cannot access projects or upload scans. This is the critical path for any user interaction.

**Independent Test**: Can be fully tested by creating an account, logging in, viewing the auth token is properly stored, and verifying session persists across app restarts. Delivers immediate value by enabling project access.

**Acceptance Scenarios**:

1. **Given** a user has vron.one account credentials, **When** they enter valid email and password, **Then** the app authenticates successfully and displays the projects list
2. **Given** a user enters invalid credentials, **When** they attempt to log in, **Then** the app displays a clear error message and remains on the login screen
3. **Given** a user is authenticated, **When** they close and reopen the app, **Then** they remain logged in without re-entering credentials
4. **Given** a user is authenticated, **When** they choose to log out, **Then** the session is terminated and they return to the login screen
5. **Given** the device has no internet connection, **When** a user with valid cached credentials opens the app, **Then** they can access previously synced project data

---

### User Story 2 - Browse and Manage Real Estate Projects (Priority: P2)

A realtor views their list of real estate projects and can access detailed information about each project. They can update project metadata (name, description, status) but cannot create new projects or permanently delete existing ones - only mark them as inactive.

**Why this priority**: Project browsing is the primary entry point to the app's core value. Users need to see their projects before they can scan rooms or manage assets. This creates the context for all scanning activities.

**Independent Test**: Log in with test credentials, verify projects list displays correctly with project names and thumbnails, tap a project to view details, edit project metadata, and verify changes sync back to the API.

**Acceptance Scenarios**:

1. **Given** a user is authenticated, **When** they view the projects tab, **Then** they see a scrollable list of all their real estate projects with names and preview images
2. **Given** a user taps a project, **When** the project detail screen loads, **Then** they see comprehensive project information including rooms, assets, and metadata
3. **Given** a user views project details, **When** they edit the project name or description, **Then** the changes are saved locally and synced to the API when online
4. **Given** a user wants to archive a project, **When** they toggle the project to inactive status, **Then** the project is marked inactive but not deleted from the system
5. **Given** a user is offline, **When** they view their projects, **Then** they see all previously synced projects with cached data

---

### User Story 3 - LiDAR Room Scanning with 3D Preview (Priority: P3)

A realtor with a LiDAR-equipped iOS device scans a room in a real estate property to create a 3D model. The app captures spatial data using the device's LiDAR scanner, processes the scan on-device to generate a textured 3D model (GLB format), and provides an immersive 3D preview of the captured space.

**Why this priority**: This is the unique value proposition of the mobile app - enabling field capture of real estate spaces. While critical for the product vision, it depends on the foundation of authentication and project management (P1, P2).

**Independent Test**: Log in, select a project, initiate room scan on LiDAR-capable iOS device, complete the scan, verify 3D preview displays the captured room with textures, and confirm GLB file is generated locally.

**Acceptance Scenarios**:

1. **Given** a user has a LiDAR-equipped iOS device (iOS 16+), **When** they navigate to a project detail, **Then** they see an "Add Room Scan" button
2. **Given** a user initiates a room scan, **When** the LiDAR scanning interface launches, **Then** they can move around the room to capture spatial data with real-time visual feedback
3. **Given** a user completes a room scan, **When** the processing finishes, **Then** they see a 3D preview of the scanned room with preserved textures and spatial accuracy within 5cm
4. **Given** a user views a completed scan, **When** they interact with the 3D preview, **Then** they can rotate, zoom, and pan to inspect the captured geometry from all angles
5. **Given** a user has an older iOS device or Android device, **When** they access project details, **Then** the room scanning features are hidden with a message explaining hardware requirements

---

### User Story 4 - Navigation Mesh Generation and Upload (Priority: P4)

After scanning a room, the realtor generates a navigation mesh (navmesh) from the 3D model to enable VR navigation in the vron.one web platform. The navmesh is processed on-device and uploaded alongside the room's 3D model (scene GLB) to the selected project via GraphQL mutations.

**Why this priority**: Navmesh generation extends the scanning feature to enable VR walkthrough experiences. This is valuable but not blocking for basic room visualization, making it lower priority than core scanning (P3).

**Independent Test**: Complete a room scan (P3), trigger navmesh generation, verify processing completes successfully, upload both scene and navmesh GLB files to a project, and confirm upload success via API response.

**Acceptance Scenarios**:

1. **Given** a user has completed a room scan with 3D model, **When** they choose to generate navmesh, **Then** the app processes the geometry on-device and produces a navmesh GLB file
2. **Given** a user has both scene and navmesh GLB files, **When** they upload to a project, **Then** the app uses GraphQL mutations to attach both files to the correct project with proper metadata
3. **Given** a user initiates upload while online, **When** the upload completes, **Then** they receive confirmation and the project reflects the new room data
4. **Given** a user initiates upload while offline, **When** connectivity is restored, **Then** the queued upload executes automatically in the background
5. **Given** a navmesh generation process is running, **When** the user views progress, **Then** they see clear status indicators and estimated completion time

---

### User Story 5 - Guest Mode Room Scanning (Priority: P5)

A prospective user without a vron.one account can try the room scanning feature in guest mode. They can scan a single room, view the 3D preview, and experience the core value proposition before committing to account creation.

**Why this priority**: Guest mode is valuable for user acquisition and demonstrating capabilities but is not essential for core users (realtors) who already have accounts. This is a marketing/onboarding feature rather than core functionality.

**Independent Test**: Open app without logging in, select guest mode, complete a room scan, view 3D preview, and verify the scan is not uploaded (local-only experience).

**Acceptance Scenarios**:

1. **Given** a user opens the app, **When** they choose "Try Guest Mode" on the login screen, **Then** they can access limited scanning features without authentication
2. **Given** a user is in guest mode, **When** they scan a room, **Then** they can preview the 3D result but cannot upload to projects or sync data
3. **Given** a user completes a guest scan, **When** they attempt to save or upload, **Then** they see a prompt to create an account to access full features
4. **Given** a user has scanned a room in guest mode, **When** they create an account and log in, **Then** the guest scan is preserved and can be uploaded to a project

---

### User Story 6 - Immersive Asset Demos with Themed Content (Priority: P6)

Users can view curated demo content showcasing sailing and aviation-themed 3D assets within immersive navigation experiences. This demonstrates the platform's VR commerce capabilities and provides sample content for new users or presentations.

**Why this priority**: Demo content is valuable for marketing and user education but doesn't affect core workflow for active realtors managing real properties. This is a nice-to-have enhancement for showcasing platform capabilities.

**Independent Test**: Navigate to demo section, select sailing or aviation theme, view 3D assets with immersive navigation, verify navigation controls work smoothly at 30fps minimum.

**Acceptance Scenarios**:

1. **Given** a user accesses the demo section, **When** they view available themes, **Then** they see sailing and aviation categories with preview thumbnails
2. **Given** a user selects a sailing demo, **When** the 3D scene loads, **Then** they see high-quality marine assets (boats, docks, nautical equipment) in an immersive environment
3. **Given** a user selects an aviation demo, **When** the 3D scene loads, **Then** they see aircraft and aviation facility assets with realistic textures and lighting
4. **Given** a user views a demo scene, **When** they interact with navigation, **Then** they can move through the space using intuitive touch controls at 30fps or better
5. **Given** a user views demo assets, **When** they inspect textures and materials, **Then** all PBR textures (albedo, normal, metallic, roughness) are preserved and rendered correctly

---

### Edge Cases

- **Interrupted Upload**: When a user loses internet connection mid-upload during a large GLB file transfer, the app resumes upload from the last successful chunk when connectivity is restored. Upload progress is preserved locally to prevent redundant data transfer.
- **Oversized Scan**: When a room scan approaches or exceeds the 50MB file size limit, the app warns the user during the scan with real-time file size feedback. The user is offered options to either compress the GLB file (with transparency about potential quality trade-offs) or re-scan the room with reduced detail settings to stay within limits.
- **Insufficient Scan Data**: What happens when the LiDAR scanner fails to capture sufficient spatial data (insufficient lighting, reflective surfaces)?
- **API Failures**: When GraphQL API requests fail (timeout, 5xx errors, network issues), the app retries using exponential backoff (1s, 2s, 4s) for a maximum of 3 attempts. After retry exhaustion, the app falls back to cached data for queries and queues mutations for later sync. Users see a subtle notification about offline mode without blocking their workflow.
- **Expired Session**: When GraphQL API returns authentication errors for a previously valid token (expired session), the app attempts automatic token refresh using the refresh token flow. If refresh fails, the user is prompted to re-authenticate without losing local state or queued operations.
- **Low Resources**: What happens when a user attempts to scan a room while the device is low on battery (<20%) or storage (<500MB available)?
- **Room Naming Conflicts**: Rooms are automatically named with timestamp-based identifiers (e.g., "Room - 2025-11-30 14:23") to ensure uniqueness within a project. Users can edit room names after scan completion. The system prevents duplicate names by appending numeric suffixes if a user manually creates a conflict (e.g., "Living Room (2)").
- **Invalid Navmesh Geometry**: What happens when a navmesh generation process fails due to invalid geometry (non-manifold meshes, holes)?
- **Offline Edit Conflicts**: How does offline sync handle conflicts when project metadata is edited both offline on mobile and online on web platform?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST authenticate users via vron.one GraphQL API using email/password credentials
- **FR-002**: System MUST construct and securely store authentication tokens in base64-encoded format containing accessToken and activeRoles
- **FR-003**: System MUST include required headers (Authorization: Bearer <AUTH_CODE>, X-VRon-Platform: "merchants") in all GraphQL requests
- **FR-004**: System MUST fetch and display user's real estate projects from GraphQL API with pagination support
- **FR-005**: System MUST allow users to view project details including name, description, status, and associated rooms
- **FR-006**: System MUST allow users to edit project metadata (name, description) and sync changes via GraphQL mutations
- **FR-007**: System MUST allow users to mark projects as inactive (but not delete) via GraphQL mutations
- **FR-008**: System MUST detect device platform and LiDAR hardware availability before displaying scan features
- **FR-009**: System MUST integrate with RoomPlan framework on iOS 16+ devices for LiDAR scanning
- **FR-010**: System MUST convert captured USDZ scan data to GLB format with preserved PBR textures (albedo, normal, metallic, roughness)
- **FR-011**: System MUST maintain spatial accuracy within 5cm tolerance during USDZ to GLB conversion
- **FR-012**: System MUST display real-time 3D preview during room scanning at minimum 30fps
- **FR-013**: System MUST generate navigation mesh (navmesh) from GLB scene geometry using on-device processing
- **FR-014**: System MUST provide 3D viewer for inspecting completed scans with rotation, zoom, and pan controls
- **FR-015**: System MUST upload scene GLB and navmesh GLB files to projects via GraphQL mutations with proper metadata
- **FR-016**: System MUST implement offline-first caching for GraphQL responses (projects, project details, user profile) with 24-hour expiration and manual pull-to-refresh capability
- **FR-017**: System MUST queue uploads for background sync when device is offline and support resumable uploads with chunk-based progress preservation
- **FR-018**: System MUST handle optimistic UI updates with rollback on GraphQL mutation errors and retry failed requests using exponential backoff (1s, 2s, 4s) for maximum 3 attempts before queuing for later sync
- **FR-019**: System MUST monitor GLB file size during scanning and warn users when approaching 50MB limit, offering compression or reduced detail re-scan options
- **FR-020**: System MUST provide guest mode allowing single room scan and preview without authentication
- **FR-021**: System MUST display curated sailing-themed and aviation-themed 3D asset demos
- **FR-022**: System MUST implement immersive navigation controls for demo scenes matching web platform UX patterns
- **FR-023**: System MUST handle GraphQL authentication token refresh transparently when tokens expire
- **FR-024**: System MUST provide clear error messages for unsupported devices (no LiDAR, old iOS versions)
- **FR-025**: System MUST persist user session across app restarts using secure device storage
- **FR-026**: System MUST support GraphQL subscriptions for real-time asset sync notifications
- **FR-027**: System MUST handle conflict resolution when offline edits conflict with server state
- **FR-028**: System MUST display upload progress indicators with percentage and estimated time remaining
- **FR-029**: System MUST allow manual retry of failed uploads with preserved queue ordering
- **FR-030**: System MUST implement graceful degradation on Android devices (hide scanning, show projects only)

### Constitution Alignment *(mandatory for VRON Mobile)*

- **Offline-First (Principle II)**:
  - Projects list, project details, and user profile must be cached using SQLite/Hive with 24-hour expiration
  - GraphQL responses cached with cache-first strategy for instant perceived response
  - Manual pull-to-refresh allows users to force cache invalidation and fetch fresh data
  - Scanned GLB files and navmesh stored locally until upload completes
  - Upload queue persisted to survive app restarts and connectivity loss
  - Conflict resolution uses last-write-wins with timestamp comparison for metadata edits

- **Native Performance (Principle I)**:
  - UI navigation must maintain 60fps minimum on target devices (iPhone 12+, Android flagship 2021+)
  - 3D preview rendering must maintain 30fps minimum during scan playback
  - Platform channels required for: RoomPlan integration, Model I/O USDZ→GLB conversion, navmesh generation
  - Memory footprint must stay under 300MB typical, 500MB peak during active scanning
  - USDZ→GLB conversion must complete within 10 seconds for typical room (1000 vertices, 5 textures)

- **TDD (Principle III)**:
  - All functional requirements (FR-001 through FR-030) are testable with clear pass/fail criteria
  - Widget tests required for all UI components (login form, project list, project detail, 3D viewer)
  - Integration tests required for platform channel contracts (RoomPlan, Model I/O, navmesh generation)
  - Unit tests required for authentication logic, GraphQL client, offline cache, conflict resolution
  - Golden tests required for critical flows: login screen, project list, 3D preview, demo scenes

- **Platform Integration (Principle IV)**:
  - iOS-specific: RoomPlan framework (iOS 16+), Model I/O for USDZ→GLB conversion
  - iOS-specific: Native Swift plugin for navmesh generation using NavMeshBuilder library
  - Channel contracts must be versioned (scanRoom_v1, convertToGlb_v1, generateNavmesh_v1)
  - Error codes defined: UNSUPPORTED_PLATFORM, LIDAR_UNAVAILABLE, PERMISSION_DENIED, SCAN_FAILED, CONVERSION_FAILED, NAVMESH_GENERATION_FAILED
  - Both Dart-side and Swift-side unit tests required for all channel methods

- **3D Asset Fidelity (Principle VI)**:
  - USDZ→GLB conversion must preserve all PBR texture maps (albedo, normal, metallic, roughness)
  - Automated tests comparing input USDZ texture count to output GLB texture count
  - Spatial accuracy validation: 5cm tolerance for room dimensions
  - Visual regression tests (golden images) for 3D preview rendering
  - GLB files must embed textures (not external references) for reliable upload/download
  - File size validation: reject GLB files exceeding 50MB to ensure reasonable upload times

### Key Entities

- **User**: Represents an authenticated realtor or merchant with vron.one account. Attributes: email, accessToken, activeRoles, merchant role. Relationships: owns multiple Projects.

- **Project**: Represents a real estate property or commercial space. Attributes: id, name, description, status (active/inactive), thumbnail, creation date, last modified date. Relationships: contains multiple Rooms, owned by User.

- **Room**: Represents a scanned physical space within a Project. Attributes: id, name (auto-generated with timestamp, user-editable), scan date, scene GLB file path/URL, navmesh GLB file path/URL, file sizes, processing status. Relationships: belongs to Project. Name uniqueness enforced per project with automatic suffix appending for duplicates.

- **ScanSession**: Represents an active or completed room scanning operation. Attributes: session id, start time, end time, USDZ file path, GLB file path, processing status, error logs. Relationships: produces a Room when completed.

- **UploadQueue**: Represents pending uploads for offline sync. Attributes: queue id, file paths (scene, navmesh), target project id, upload status, retry count, created timestamp. Relationships: references Project and Room.

- **DemoAsset**: Represents themed 3D content for demonstrations. Attributes: asset id, theme (sailing/aviation), name, GLB file URL, preview thumbnail, metadata. Relationships: grouped by theme category.

- **GraphQLCache**: Represents cached API responses for offline access. Attributes: query key, response data, timestamp, expiration time (24 hours default). Relationships: maps to Projects, Rooms, User profile. Supports manual invalidation via pull-to-refresh user action.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can complete authentication and view their projects list within 3 seconds of app launch on devices with cached credentials
- **SC-002**: Users can complete a room scan (initiate, capture, process, preview) in under 5 minutes for a typical 20m² room
- **SC-003**: 3D preview rendering maintains 30fps minimum on iPhone 12 Pro and newer models with LiDAR
- **SC-004**: USDZ to GLB conversion preserves 100% of PBR texture maps (verified via automated testing)
- **SC-005**: Spatial accuracy of scanned rooms is within 5cm for room dimensions (length, width, height)
- **SC-006**: 95% of room scans result in successfully generated GLB files under 50MB size limit
- **SC-007**: Users can access previously synced project data offline within 1 second
- **SC-008**: Upload queue successfully syncs 100% of pending uploads when connectivity is restored
- **SC-009**: App maintains 60fps UI performance during navigation between screens (projects list, detail, settings)
- **SC-010**: Users can complete the guest mode experience (scan, preview) without authentication in under 3 minutes
- **SC-011**: GraphQL query response time is under 500ms perceived latency using cache-first strategy
- **SC-012**: Demo scenes (sailing/aviation) load and render within 2 seconds with all textures displayed
- **SC-013**: 90% of users successfully complete their first room scan on first attempt (measured via telemetry)
- **SC-014**: Conflict resolution correctly merges 100% of offline edits with server state when reconnecting
- **SC-015**: App memory usage stays under 300MB during typical usage and under 500MB during active scanning
- **SC-016**: Navigation mesh generation completes within 15 seconds for typical room geometry (1000-5000 vertices)
- **SC-017**: Users receive real-time sync notifications within 2 seconds of asset changes via GraphQL subscriptions
- **SC-018**: Authentication token refresh happens transparently without user-visible interruption or re-login prompts

### Assumptions

- Users have access to vron.one SaaS accounts via existing web platform signup flow
- The vron.one GraphQL API endpoint (https://api.vron.stage.motorenflug.at/graphql) is stable and supports all required queries/mutations
- Demo asset GLB files (sailing/aviation themes) will be provided by the vron.one content team or sourced from open libraries
- LiDAR scanning is exclusive to iOS devices with hardware support (iPhone 12 Pro and newer); Android support is limited to project management only
- Network bandwidth for uploads assumes average mobile connection (5 Mbps minimum for reasonable upload times)
- Device storage assumes users have minimum 2GB free space for temporary scan processing and offline cache
- GraphQL schema includes mutations for uploading GLB files and associating them with projects (or multipart upload endpoint exists)
- The Apple Model I/O framework can reliably convert USDZ to GLB with texture preservation on iOS 16+
- Native Swift libraries (e.g., NavMeshBuilder) can generate navmesh geometry from GLB files on-device
- The web platform's immersive navigation UX patterns are touch-friendly and translatable to mobile gestures
- Role-based access control (RBAC) for merchants is already enforced server-side; mobile app only needs to pass correct headers
