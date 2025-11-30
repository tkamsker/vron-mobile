# Data Model: VRON Mobile Companion

**Feature**: 001-vron-mobile-companion
**Date**: 2025-11-30
**Purpose**: Entity definitions, relationships, state transitions, and validation rules for local storage and GraphQL sync

## Overview

The VRON Mobile data model consists of **7 primary entities** managed through Drift SQLite (local) and synchronized with vron.one Postgres (remote via GraphQL). The model supports offline-first operation with 24-hour cache expiration and last-write-wins conflict resolution.

## Entity Definitions

### 1. User

**Purpose**: Authenticated realtor or merchant with vron.one account

**Attributes**:
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | String (UUID) | PRIMARY KEY, NOT NULL | Unique user identifier from GraphQL |
| `email` | String | NOT NULL, UNIQUE | User's email address |
| `access_token` | String | NOT NULL | JWT access token (stored encrypted in flutter_secure_storage, not in DB) |
| `active_roles` | JSON | NOT NULL | Role mapping: `{merchants: "MERCHANT"}` |
| `merchant_role` | String | NOT NULL, CHECK IN ('MERCHANT', 'ADMIN') | Primary role for this user |
| `created_at` | DateTime | NOT NULL | Account creation timestamp |
| `last_login_at` | DateTime | NOT NULL | Last successful authentication |
| `synced_at` | DateTime | NULLABLE | Last sync with remote API |

**Relationships**:
- One User → Many Projects (owner)

**Validation Rules**:
- Email must match RFC 5322 format
- Access token must not be empty
- `last_login_at` updated on every successful signIn mutation

**State Transitions**:
```
[Unauthenticated] --signIn--> [Authenticated] --signOut--> [Unauthenticated]
[Authenticated] --tokenExpired--> [RefreshingToken] --success--> [Authenticated]
[Authenticated] --tokenExpired--> [RefreshingToken] --failure--> [Unauthenticated]
```

**Storage**: User profile cached in Hive (24-hour TTL), access token in `flutter_secure_storage`

---

### 2. Project

**Purpose**: Real estate property or commercial space managed by a user

**Drift Table Definition**:
```dart
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active')).check(status.isIn(['active', 'inactive']))();
  TextColumn get thumbnailUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Attributes**:
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | String (UUID) | PRIMARY KEY, NOT NULL | Unique project identifier |
| `user_id` | String (UUID) | FOREIGN KEY (users.id), NOT NULL | Owning user |
| `name` | String | NOT NULL, LENGTH 1-255 | Project display name |
| `description` | String | NULLABLE | Optional project description |
| `status` | Enum | NOT NULL, CHECK IN ('active', 'inactive'), DEFAULT 'active' | Project visibility status |
| `thumbnail_url` | String (URL) | NULLABLE | Preview image URL from GraphQL |
| `created_at` | DateTime | NOT NULL | Project creation timestamp |
| `updated_at` | DateTime | NOT NULL | Last modification timestamp |
| `synced_at` | DateTime | NULLABLE | Last successful sync with remote |

**Relationships**:
- Many Projects → One User (belongs to)
- One Project → Many Rooms (contains)

**Validation Rules**:
- Name must not be empty
- `updated_at` must be >= `created_at`
- Status transitions: `active` ↔ `inactive` (no deletion allowed per spec FR-007)
- Thumbnail URL must be valid HTTP/HTTPS if present

**State Transitions**:
```
[New] --create--> [Draft] --sync--> [Synced]
[Synced] --edit--> [Modified] --sync--> [Synced]
[Synced] --markInactive--> [Inactive] --sync--> [Synced]
[Modified] --offline--> [PendingSync] --online--> [Syncing] --success--> [Synced]
```

**Conflict Resolution**: Last-write-wins based on `updated_at` timestamp comparison

---

### 3. Room

**Purpose**: Scanned physical space within a project

**Drift Table Definition**:
```dart
class Rooms extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  DateTimeColumn get scanDate => dateTime()();
  TextColumn get sceneGlbPath => text().nullable()();
  TextColumn get navmeshGlbPath => text().nullable()();
  IntColumn get sceneFileSize => integer().nullable()();
  IntColumn get navmeshFileSize => integer().nullable()();
  TextColumn get processingStatus => text().withDefault(const Constant('pending')).check(processingStatus.isIn(['pending', 'processing', 'completed', 'failed']))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {projectId, name}, // Enforce unique room names per project
  ];
}
```

**Attributes**:
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | String (UUID) | PRIMARY KEY, NOT NULL | Unique room identifier |
| `project_id` | String (UUID) | FOREIGN KEY (projects.id) ON DELETE CASCADE, NOT NULL | Parent project |
| `name` | String | NOT NULL, LENGTH 1-255, UNIQUE per project | Room display name (auto-generated with timestamp, user-editable) |
| `scan_date` | DateTime | NOT NULL | When the room was scanned |
| `scene_glb_path` | String (path) | NULLABLE | Local file path to scene GLB |
| `navmesh_glb_path` | String (path) | NULLABLE | Local file path to navmesh GLB |
| `scene_file_size` | Integer (bytes) | NULLABLE, CHECK <= 52428800 (50MB) | Scene GLB file size |
| `navmesh_file_size` | Integer (bytes) | NULLABLE, CHECK <= 52428800 (50MB) | Navmesh GLB file size |
| `processing_status` | Enum | NOT NULL, CHECK IN ('pending', 'processing', 'completed', 'failed'), DEFAULT 'pending' | Scan/conversion status |
| `created_at` | DateTime | NOT NULL | Room creation timestamp |
| `updated_at` | DateTime | NOT NULL | Last modification timestamp |
| `synced_at` | DateTime | NULLABLE | Last successful upload to remote |

**Relationships**:
- Many Rooms → One Project (belongs to)
- One Room → One ScanSession (produced by)
- One Room → Many UploadQueue entries (referenced in)

**Validation Rules**:
- Name must be unique within project (enforced by composite unique constraint)
- If name conflict during user edit, append numeric suffix: "Living Room (2)"
- File sizes must not exceed 50MB (52428800 bytes)
- `scene_glb_path` required if `processing_status` = 'completed'
- Auto-generate name format: "Room - YYYY-MM-DD HH:mm" (spec clarification)

**State Transitions**:
```
[New Scan] --initiate--> [Pending] --startProcessing--> [Processing]
[Processing] --usdzToGlb--> [GlbGenerated] --generateNavmesh--> [NavmeshGenerated]
[NavmeshGenerated] --validate--> [Completed]
[Processing] --error--> [Failed]
[Completed] --queueUpload--> [UploadPending] --uploaded--> [Synced]
```

---

### 4. ScanSession

**Purpose**: Tracks an active or completed room scanning operation

**Attributes**:
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | String (UUID) | PRIMARY KEY, NOT NULL | Unique session identifier |
| `room_id` | String (UUID) | FOREIGN KEY (rooms.id) ON DELETE CASCADE, NULLABLE | Associated room (set after completion) |
| `project_id` | String (UUID) | FOREIGN KEY (projects.id), NOT NULL | Target project |
| `start_time` | DateTime | NOT NULL | Scan start timestamp |
| `end_time` | DateTime | NULLABLE | Scan completion timestamp |
| `usdz_file_path` | String (path) | NULLABLE | Temporary USDZ file from RoomPlan |
| `glb_file_path` | String (path) | NULLABLE | Converted GLB file path |
| `processing_status` | Enum | NOT NULL, CHECK IN ('scanning', 'converting', 'generating_navmesh', 'completed', 'failed') | Current processing step |
| `error_log` | Text | NULLABLE | Error details if failed |
| `vertex_count` | Integer | NULLABLE | Scene geometry complexity |
| `texture_count` | Integer | NULLABLE | Number of textures preserved |

**Relationships**:
- One ScanSession → One Room (produces)
- One ScanSession → One Project (belongs to)

**Validation Rules**:
- `end_time` must be > `start_time` if set
- `glb_file_path` required if `processing_status` = 'completed'
- `error_log` required if `processing_status` = 'failed'

**State Transitions**:
```
[Start] --scanRoom--> [Scanning] --complete--> [Converting]
[Converting] --convertToGlb--> [GeneratingNavmesh]
[GeneratingNavmesh] --generateNavmesh--> [Completed]
[Any] --error--> [Failed]
```

**Lifecycle**: Temporary entity, cleaned up after successful room creation (retain for 7 days for debugging)

---

### 5. UploadQueue

**Purpose**: Persistent queue for offline-capable file uploads

**Drift Table Definition**:
```dart
class UploadQueue extends Table {
  TextColumn get id => text()();
  TextColumn get roomId => text().references(Rooms, #id, onDelete: KeyAction.cascade)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get sceneGlbPath => text().nullable()();
  TextColumn get navmeshGlbPath => text().nullable()();
  TextColumn get uploadStatus => text().withDefault(const Constant('pending')).check(uploadStatus.isIn(['pending', 'uploading', 'completed', 'failed']))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get uploadedBytes => integer().withDefault(const Constant(0))(); // For resumable uploads
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Attributes**:
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | String (UUID) | PRIMARY KEY, NOT NULL | Unique queue entry identifier |
| `room_id` | String (UUID) | FOREIGN KEY (rooms.id) ON DELETE CASCADE, NOT NULL | Associated room |
| `project_id` | String (UUID) | FOREIGN KEY (projects.id), NOT NULL | Target project for upload |
| `scene_glb_path` | String (path) | NULLABLE | Local scene GLB file path |
| `navmesh_glb_path` | String (path) | NULLABLE | Local navmesh GLB file path |
| `upload_status` | Enum | NOT NULL, CHECK IN ('pending', 'uploading', 'completed', 'failed'), DEFAULT 'pending' | Current upload state |
| `retry_count` | Integer | NOT NULL, DEFAULT 0, CHECK <= 3 | Number of retry attempts |
| `uploaded_bytes` | Integer | NOT NULL, DEFAULT 0 | Bytes successfully uploaded (for resumable uploads) |
| `created_at` | DateTime | NOT NULL | Queue entry creation timestamp |
| `last_attempt_at` | DateTime | NULLABLE | Last upload attempt timestamp |
| `completed_at` | DateTime | NULLABLE | Successful upload completion timestamp |
| `error_message` | String | NULLABLE | Last error message if failed |

**Relationships**:
- Many UploadQueue → One Room (references)
- Many UploadQueue → One Project (references)

**Validation Rules**:
- At least one of `scene_glb_path` or `navmesh_glb_path` must be set
- `retry_count` must not exceed 3 (after 3 failures, requires manual retry per spec FR-029)
- `uploaded_bytes` must be <= file size
- Exponential backoff delays: 1s, 2s, 4s between retries (spec clarification)

**State Transitions**:
```
[New] --queue--> [Pending] --online--> [Uploading]
[Uploading] --chunk--> [Uploading] (update uploaded_bytes)
[Uploading] --success--> [Completed]
[Uploading] --networkError--> [Pending] (retry_count++)
[Pending] --retryCount==3--> [Failed] (requires manual retry)
[Failed] --manualRetry--> [Pending] (reset retry_count)
```

**Lifecycle**: Completed entries cleaned up after 30 days; failed entries retained until manual retry or explicit deletion

---

### 6. DemoAsset

**Purpose**: Curated 3D content for sailing/aviation-themed demos

**Attributes**:
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | String (UUID) | PRIMARY KEY, NOT NULL | Unique asset identifier |
| `theme` | Enum | NOT NULL, CHECK IN ('sailing', 'aviation') | Demo category |
| `name` | String | NOT NULL, LENGTH 1-255 | Asset display name |
| `glb_url` | String (URL) | NOT NULL | Remote GLB file URL (hosted on vron.one CDN) |
| `preview_thumbnail_url` | String (URL) | NOT NULL | Preview image URL |
| `description` | Text | NULLABLE | Asset description |
| `metadata` | JSON | NULLABLE | Additional properties (vertex count, texture count, etc.) |
| `display_order` | Integer | NOT NULL, DEFAULT 0 | Sort order within theme |

**Relationships**:
- Many DemoAssets → One Theme (grouped by)

**Validation Rules**:
- `glb_url` must be valid HTTPS URL
- `preview_thumbnail_url` must be valid HTTPS URL
- Theme must be 'sailing' or 'aviation' only

**Storage**: Fetched from GraphQL on app launch, cached in Hive for offline access (7-day TTL)

---

### 7. GraphQLCache

**Purpose**: Key-value cache for GraphQL responses (24-hour TTL)

**Hive Box Schema**:
```dart
@HiveType(typeId: 1)
class GraphQLCacheEntry {
  @HiveField(0)
  String queryKey; // Hash of query + variables

  @HiveField(1)
  String responseData; // JSON-serialized response

  @HiveField(2)
  DateTime timestamp; // Cache creation time

  @HiveField(3)
  DateTime expirationTime; // timestamp + 24 hours

  bool get isExpired => DateTime.now().isAfter(expirationTime);
}
```

**Attributes**:
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `query_key` | String | PRIMARY KEY (Hive key), NOT NULL | Hash of GraphQL query + variables |
| `response_data` | String (JSON) | NOT NULL | Serialized GraphQL response |
| `timestamp` | DateTime | NOT NULL | Cache entry creation time |
| `expiration_time` | DateTime | NOT NULL | Calculated as timestamp + 24 hours |

**Relationships**: None (flat key-value store)

**Validation Rules**:
- `expiration_time` = `timestamp` + 24 hours (spec clarification)
- Expired entries automatically evicted on access (lazy deletion)
- Manual invalidation via pull-to-refresh triggers cache clear for affected queries

**Storage**: Hive lazy box for memory efficiency

---

## Relationships Diagram

```
User (1) ──────< Projects (M)
                   │
                   │ (1)
                   │
                   └──────< Rooms (M) ──────< UploadQueue (M)
                                │
                                │ (1)
                                │
                            ScanSession (1)

DemoAsset (M) ────grouped by───> Theme (sailing/aviation)

GraphQLCache ───(no relationships)───
```

## Database Migration Strategy

**Initial Schema (v1)**:
```dart
// database.dart
@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (Migrator m) async {
    await m.createAll(); // Creates all tables defined in @DriftDatabase
  },
  onUpgrade: (Migrator m, int from, int to) async {
    // Future migrations handled here
    if (from < 2) {
      // Example: Add new column in v2
      // await m.addColumn(rooms, rooms.newColumn);
    }
  },
);
```

**Migration Guidelines**:
1. Never delete columns (mark deprecated, hide in UI)
2. Always provide default values for new columns
3. Test migrations on cloned production database before release
4. Document breaking changes in CHANGELOG.md

## Sync Strategy

**Pull (Remote → Local)**:
```
1. On app launch: Fetch user profile + projects list
2. On project detail view: Fetch rooms for selected project
3. On connectivity restored: Pull updates for all entities where synced_at < remote updated_at
4. On manual refresh: Invalidate cache, fetch fresh data
```

**Push (Local → Remote)**:
```
1. On mutation: Optimistic UI update + queue GraphQL mutation
2. On success: Update synced_at timestamp
3. On failure: Retry with exponential backoff (1s, 2s, 4s)
4. On retry exhaustion: Queue for later sync, show user notification
```

**Conflict Resolution**:
- **Last-write-wins**: Compare `updated_at` timestamps
- **Local takes precedence** if timestamps equal (favor user's recent changes)
- **User notification** for conflicts: "Your changes have been synced. Project updated by [other user] on [date]."

## Indexes

**Performance Optimization**:
```sql
-- Projects
CREATE INDEX idx_projects_user_status ON projects(user_id, status);
CREATE INDEX idx_projects_updated_at ON projects(updated_at DESC);

-- Rooms
CREATE INDEX idx_rooms_project_id ON rooms(project_id);
CREATE INDEX idx_rooms_processing_status ON rooms(processing_status);

-- UploadQueue
CREATE INDEX idx_upload_queue_status ON upload_queue(upload_status);
CREATE INDEX idx_upload_queue_created_at ON upload_queue(created_at DESC);
```

## Storage Estimates

**Per User**:
- User profile: ~1 KB
- 50 projects × 1 KB = 50 KB
- 250 rooms (50 projects × 5 rooms avg) × 2 KB = 500 KB
- Upload queue (10 pending) × 1 KB = 10 KB
- **Total structured data: ~561 KB per user**

**GLB Files**:
- Scene GLB: 10-50 MB per room (avg 25 MB)
- Navmesh GLB: 1-5 MB per room (avg 2 MB)
- **Total GLB storage: ~27 MB per room × 250 rooms = 6.75 GB**

**Cache**:
- GraphQL cache: ~5-10 MB (responses for 50 projects + rooms)
- Hive overhead: ~1 MB

**Total Storage Requirement**: ~7 GB (assumes all rooms downloaded locally)
**Realistic Usage**: ~500 MB (user typically works on 5-10 active projects)

## Data Retention Policy

| Entity | Retention | Cleanup Strategy |
|--------|-----------|------------------|
| User | Indefinite | Delete on signOut |
| Project | Indefinite | Soft delete (mark inactive) |
| Room | Indefinite | Cascade delete with project |
| ScanSession | 7 days | Auto-cleanup completed sessions |
| UploadQueue | 30 days (completed), Indefinite (failed) | Manual retry or explicit deletion |
| DemoAsset | Indefinite | Managed by GraphQL API |
| GraphQLCache | 24 hours | Lazy eviction on access |

## Validation Summary

All entities satisfy Constitution Principle II (Offline-First):
- ✅ Drift SQLite for structured data persistence
- ✅ Hive for GraphQL response cache
- ✅ 24-hour cache expiration with manual refresh
- ✅ Upload queue with resumable chunks
- ✅ Last-write-wins conflict resolution
- ✅ Optimistic UI updates with rollback

All entities designed for testability (Constitution Principle III):
- ✅ Clear state transitions enable unit tests
- ✅ Validation rules testable with constraint violations
- ✅ Mock repositories for GraphQL client isolation
