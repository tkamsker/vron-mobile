# Changelog

All notable changes to the VRON GraphQL Client package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-02

### Added

#### Upload Infrastructure
- **Resumable Upload System**: Complete implementation of chunked file uploads with progress persistence
  - `UploadService` for managing chunked uploads (5MB chunks)
  - Content-Range header support for resumable uploads
  - Exponential backoff retry strategy (1s, 2s, 4s delays, max 3 attempts)
  - Upload offset restoration on connectivity changes
  - Progress persistence to Drift database after each chunk

#### Database Layer
- **Drift Integration**: SQLite database with Drift ORM
  - `UploadQueue` table for persistent upload tracking
  - `UploadDatabase` with comprehensive query and mutation methods
  - Automatic schema migrations
  - Upload state management (pending, uploading, completed, failed)
  - Retry count and error message tracking

#### State Management
- **UploadNotifier**: StateNotifier-based orchestration
  - Complete workflow: createRoom → requestUploadUrl → upload → uploadRoomAssets
  - Offline queueing capability
  - Background sync for pending uploads
  - Real-time progress tracking for UI binding
  - Manual retry and cancel operations

#### GraphQL Operations
- `createRoom.graphql` - Create room entry mutation
- `requestUploadUrl.graphql` - Get presigned S3 URL query
- `uploadRoomAssets.graphql` - Confirm upload mutation
- Consolidated GraphQL schema with single root types (Query, Mutation, Subscription)

#### Providers
- `uploadDatabaseProvider` - Database singleton with auto-dispose
- `uploadServiceProvider` - Upload service with dependency injection
- `uploadNotifierProvider` - State notifier for upload workflows
- `uploadStateProvider` - Family provider for monitoring specific uploads

#### Dependencies
- Added `dio: ^5.4.0` for HTTP uploads with Content-Range support
- Added `drift: ^2.14.0` for database ORM
- Added `drift_dev: ^2.14.0` for code generation
- Added `sqlite3_flutter_libs: ^0.5.0` for SQLite support
- Added `path_provider: ^2.1.0` for file path resolution
- Added `path: ^1.8.3` for path utilities

#### Documentation
- Comprehensive `README.md` with quick start guide
- Detailed `UPLOAD_INFRASTRUCTURE.md` with:
  - Architecture overview
  - Complete API reference
  - Usage examples
  - Configuration guide
  - Error handling
  - Troubleshooting
  - Testing guidelines
- `CHANGELOG.md` for version tracking

### Changed
- Updated package exports in `lib/vron_graphql_client.dart` to include upload infrastructure
- Enhanced package description to include resumable upload capabilities

### Fixed
- Consolidated duplicate GraphQL root type declarations in `schema.graphql`
  - Removed multiple `type Query`, `type Mutation`, `type Subscription` declarations
  - Single root type section at end of schema file
  - Resolves artemis code generator validation errors

## [0.1.0] - 2025-11-30

### Added
- Initial GraphQL client setup
- Authentication with Base64-encoded tokens
- Project and Room repositories
- Hive-based offline caching
- WebSocket subscription support
- X-VRon-Platform header injection
- Sign in/out mutations
- Project queries (paginated)

[1.0.0]: https://github.com/vron-project/vron-mobile/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/vron-project/vron-mobile/releases/tag/v0.1.0
