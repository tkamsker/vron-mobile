<!--
Sync Impact Report
==================
Version: 0.0.0 → 1.0.0 (MAJOR - Initial constitution ratification)
Ratification Date: 2025-11-30
Last Amended: 2025-11-30

Principles Defined:
- I. Native-First Performance (NEW)
- II. Offline-First with Real-Time Sync (NEW)
- III. Test-Driven Development (TDD) (NEW)
- IV. Platform Integration via Channels (NEW)
- V. Modular Architecture (NEW)
- VI. 3D Asset Fidelity (NEW)
- VII. CI/CD & Deployment Readiness (NEW)

Sections Added:
- Core Principles (7 principles)
- Technical Constraints
- Flutter-Specific Standards
- Governance

Templates Status:
✅ .specify/templates/plan-template.md - Updated with constitution gates
✅ .specify/templates/spec-template.md - Aligned with requirements structure
✅ .specify/templates/tasks-template.md - Updated with TDD and platform-specific task patterns
⚠ .specify/templates/agent-file-template.md - Review pending
⚠ .specify/templates/checklist-template.md - Review pending

Deferred Items:
- None - all placeholders resolved

Notes:
- This is the initial ratification establishing governance for vron-mobile Flutter app
- Focuses on native iOS/Android performance with vron.one GraphQL SaaS integration
- LiDAR room scanning with USDZ→GLB conversion and navmesh generation
- Offline-first architecture with role-based auth
-->

# VRON Mobile Constitution

## Core Principles

### I. Native-First Performance

Flutter MUST deliver native iOS/Android performance through:
- Platform channels for performance-critical operations (LiDAR scanning, 3D processing)
- Native Swift/Kotlin plugins for Apple Model I/O and Android ARCore integrations
- Frame rate MUST maintain 60fps minimum for UI, 30fps minimum for 3D preview
- Memory footprint MUST stay under 300MB for typical usage, 500MB peak during scanning

**Rationale**: Immersive commerce and VR asset manipulation require seamless UX.
Flutter's declarative UI handles reactive state well, but compute-intensive operations
(USDZ parsing, navmesh generation) MUST leverage native performance.

### II. Offline-First with Real-Time Sync

Data architecture MUST support offline operation with eventual consistency:
- Local SQLite/Hive cache for GraphQL responses and 3D asset metadata
- Optimistic UI updates with conflict resolution on reconnection
- Real-time sync via GraphQL subscriptions when online
- Queue-based upload for scanned rooms and generated assets

**Rationale**: Field scanning environments (construction sites, retail spaces) often
have unreliable connectivity. Users MUST capture and preview scans offline, with
background sync when network available.

### III. Test-Driven Development (TDD)

TDD is NON-NEGOTIABLE for all feature work:
1. Write widget/unit tests covering acceptance criteria
2. User approves test scenarios
3. Verify tests FAIL (red phase)
4. Implement feature to pass tests (green phase)
5. Refactor with tests as safety net

**Test Coverage Requirements**:
- Unit tests for business logic and data models (80%+ coverage)
- Widget tests for all UI components
- Integration tests for platform channel communication
- Golden tests for critical UI flows (room stitching preview, 3D viewer)

**Rationale**: Platform channel bugs and 3D processing edge cases are expensive to
debug in production. TDD ensures contracts are validated before implementation.

### IV. Platform Integration via Channels

Native functionality MUST be exposed via method channels following strict contracts:
- **iOS LiDAR Scanning**: Swift plugin wrapping RoomPlan API (iOS 16+)
- **iOS 3D Conversion**: Swift plugin using Model I/O for USDZ→GLB with textures
- **Android Scanning**: Kotlin plugin for ARCore depth API equivalent
- **Android 3D Conversion**: Kotlin plugin for GLB processing
- **Navmesh Generation**: Native C++ library exposed via FFI or channels

**Channel Contract Requirements**:
- Versioned method names (e.g., `scanRoom_v1`)
- Typed arguments with JSON schema validation
- Error codes covering all failure modes (permissions, hardware unavailable, etc.)
- Unit tests on both Dart and native sides

**Rationale**: Platform channels are the highest-risk integration points. Strict
contracts prevent runtime failures and enable independent testing of Dart/native layers.

### V. Modular Architecture

Features MUST be structured as independent, composable modules:
- **Packages**: Standalone pub packages for reusable logic (e.g., `vron_graphql_client`,
  `vron_3d_viewer`, `room_scanner`)
- **Feature Modules**: Self-contained feature directories with local state management
- **Dependency Injection**: Use `provider` or `riverpod` for testable service injection
- **Clear Boundaries**: GraphQL client, auth, offline cache, 3D processing, UI layers
  must not leak implementation details

**Module Structure**:
```
packages/
  vron_graphql_client/  # GraphQL operations, subscriptions, offline cache
  room_scanner/         # Platform channels for LiDAR/ARCore
  asset_converter/      # USDZ→GLB, navmesh generation
  vron_3d_viewer/       # 3D preview widget

lib/
  features/
    auth/               # Role-based auth matching SaaS
    scanning/           # Room scanning UI and stitching
    asset_sync/         # Real-time VR asset sync
    commerce/           # Immersive product placement
```

**Rationale**: Modular structure enables parallel development, independent testing,
and potential extraction of packages for other vron.one mobile clients.

### VI. 3D Asset Fidelity

Texture-preserving workflows are MANDATORY for all 3D operations:
- USDZ→GLB conversion MUST retain PBR textures (albedo, normal, metallic, roughness)
- Navmesh generation MUST preserve spatial accuracy within 5cm tolerance
- Preview rendering MUST display textures, not just wireframes
- Upload format MUST be GLB with embedded textures (not external references)

**Quality Gates**:
- Automated tests comparing input USDZ texture count to output GLB
- Visual regression tests for 3D preview (golden image comparison)
- File size validation (GLB MUST be <50MB per room for reasonable upload times)

**Rationale**: VR commerce depends on realistic asset representation. Lossy conversions
or missing textures break immersion and degrade product visualization quality.

### VII. CI/CD & Deployment Readiness

Every commit MUST pass automated gates; TestFlight deployment MUST be one-click:
- **CI Pipeline** (GitHub Actions or Codemagic):
  - Dart analyzer with zero warnings
  - All tests passing (unit, widget, integration)
  - Code coverage >80%
  - iOS build verification (no signing, just compilation)
  - Android build verification (debug APK)
- **TestFlight Deployment**:
  - Fastlane scripts for iOS signing and upload
  - Automated versioning (major.minor.build+commit_count)
  - Release notes auto-generated from conventional commits
- **Consistency with Existing Pipelines**:
  - Align with vron.one's Flutter pipeline patterns (if available)
  - Share build scripts and CI configuration where applicable

**Rationale**: Manual deployment creates bottlenecks and errors. TestFlight enables
rapid iteration with stakeholders while maintaining release quality.

## Technical Constraints

### GraphQL Integration
- MUST use `graphql_flutter` or `ferry` with code generation for type safety
- Subscriptions MUST reconnect automatically with exponential backoff
- Mutations MUST support optimistic responses with rollback on error
- Auth tokens MUST refresh transparently using refresh_token flow

### Role-Based Access Control
- Auth state MUST mirror vron.one SaaS roles (admin, editor, viewer, guest)
- Permissions MUST be validated locally (cached from GraphQL) and server-side
- Offline mode MUST respect last-known permissions until re-authenticated

### Hardware Requirements
- iOS 16+ for LiDAR and Model I/O framework
- Android API 29+ for ARCore depth API
- Graceful degradation: Manual measurement input if LiDAR/ARCore unavailable

### Performance Targets
- App launch: <2 seconds to interactive
- GraphQL query response: <500ms perceived latency (use cache-first)
- Room scan: Real-time 30fps preview during capture
- USDZ→GLB conversion: <10 seconds for typical room (1000 vertices, 5 textures)

## Flutter-Specific Standards

### State Management
- Use `riverpod` for global state (auth, network status, GraphQL client)
- Use `bloc` or `riverpod` providers for feature-level state
- Avoid `setState` in large widgets; prefer granular rebuilds

### Code Style
- Follow official Dart style guide (enforced via `dart format`)
- Use `flutter_lints` or `very_good_analysis` for strict linting
- Prefer composition over inheritance for widgets

### UI/UX Consistency
- Material 3 design system for Android
- Cupertino widgets for iOS (use `Platform.isIOS` checks or adaptive widgets)
- Shared design tokens (colors, typography) in theme configuration

## Governance

This constitution supersedes all other development practices. Amendments require:
1. Documented proposal with rationale and impact analysis
2. Review by project lead and affected stakeholders
3. Migration plan for existing code violating new rules (if applicable)
4. Version bump following semantic versioning rules

**Amendment Procedure**:
- MAJOR: Removing or fundamentally changing a principle (e.g., dropping TDD requirement)
- MINOR: Adding new principle or materially expanding existing guidance
- PATCH: Clarifications, typo fixes, non-breaking updates

**Compliance Review**:
- All PRs MUST reference compliance with relevant principles in description
- Code review checklist MUST verify constitution adherence
- Quarterly audits for technical debt contradicting principles

**Complexity Justification**:
If a feature requires violating a principle (e.g., skipping TDD for throwaway prototype),
it MUST be documented in the implementation plan with:
- Why the simpler compliant approach is insufficient
- Time-boxed plan to return to compliance or sunset the exception

**Version**: 1.0.0 | **Ratified**: 2025-11-30 | **Last Amended**: 2025-11-30
