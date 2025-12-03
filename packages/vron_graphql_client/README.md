# VRON GraphQL Client

A Flutter package providing GraphQL client functionality and resumable upload infrastructure for the VRON Mobile Companion app.

## Features

- **GraphQL API Integration**: Type-safe GraphQL queries and mutations
- **Authentication**: Secure token management with flutter_secure_storage
- **Resumable Uploads**: Chunked file uploads with progress persistence
- **Offline Support**: Queue uploads when offline, auto-resume when online
- **Background Sync**: Automatic upload retry and completion
- **Progress Tracking**: Real-time upload progress via Riverpod state management

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  vron_graphql_client:
    path: ../packages/vron_graphql_client
```

## Quick Start

### 1. Setup Providers

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vron_graphql_client/vron_graphql_client.dart';

void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### 2. Authentication

```dart
// Sign in
final authRepo = ref.read(authRepositoryProvider);
await authRepo.signIn(email: 'user@example.com', password: 'password');

// Check auth status
final isAuthenticated = await authRepo.isAuthenticated();

// Sign out
await authRepo.signOut();
```

### 3. Query Projects

```dart
final projectRepo = ref.read(projectRepositoryProvider);

// Get all projects
final projects = await projectRepo.getProjects();

// Get single project
final project = await projectRepo.getProject(id: 'project-123');
```

### 4. Upload Files

```dart
final uploadNotifier = ref.read(uploadNotifierProvider.notifier);

await uploadNotifier.startUpload(
  roomId: 'room-123',
  fileType: FileType.sceneGlb,
  filePath: '/path/to/scene.glb',
  fileName: 'scene.glb',
  createRoomIfNeeded: () async {
    // Create room via GraphQL
    return 'room-123';
  },
  requestUploadUrl: (roomId, fileType, fileName, fileSize) async {
    // Request presigned URL
    return (uploadUrl: 'https://...', fileKey: 'key');
  },
  uploadRoomAssets: (roomId, sceneUrl, navmeshUrl, sceneSize, navmeshSize) async {
    // Confirm upload
  },
);
```

### 5. Monitor Upload Progress

```dart
class UploadProgress extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(
      uploadStateProvider(('room-123', 'SCENE_GLB'))
    );

    if (uploadState == null) return SizedBox.shrink();

    return Column(
      children: [
        LinearProgressIndicator(value: uploadState.progress),
        Text('${(uploadState.progress * 100).toStringAsFixed(0)}%'),
      ],
    );
  }
}
```

## Architecture

```
┌─────────────────────────────────────────┐
│         Application Layer               │
│  (UI, Widgets, Screens)                 │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│      Riverpod Providers                 │
│  • uploadNotifierProvider               │
│  • uploadServiceProvider                │
│  • authRepositoryProvider               │
│  • projectRepositoryProvider            │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│       Services & Repositories           │
│  • UploadNotifier (orchestration)       │
│  • UploadService (chunked uploads)      │
│  • AuthRepository (authentication)      │
│  • ProjectRepository (GraphQL queries)  │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│      Infrastructure Layer               │
│  • UploadDatabase (Drift)               │
│  • GraphQL Client (graphql_flutter)     │
│  • HTTP Client (dio)                    │
│  • Secure Storage                       │
└─────────────────────────────────────────┘
```

## Key Components

### GraphQL Operations

Located in `graphql/`:
- `mutations/sign_in.graphql` - Authentication
- `mutations/create_room.graphql` - Create room entry
- `mutations/upload_room_assets.graphql` - Confirm upload
- `queries/request_upload_url.graphql` - Get presigned URL
- `queries/projects.graphql` - Fetch projects

### Upload Infrastructure

- **UploadService** (`lib/src/services/upload_service.dart`)
  - Chunked uploads (5MB chunks)
  - Content-Range header support
  - Exponential backoff retry (1s, 2s, 4s)
  - Progress persistence

- **UploadNotifier** (`lib/src/notifiers/upload_notifier.dart`)
  - Workflow orchestration
  - Offline queueing
  - Background sync
  - State management

- **UploadDatabase** (`lib/src/database/upload_database.dart`)
  - Drift-based persistence
  - Upload queue management
  - Progress tracking

### Repositories

- **AuthRepository** (`lib/src/repositories/auth_repository.dart`)
  - Sign in/out
  - Token management
  - Authentication state

- **ProjectRepository** (`lib/src/repositories/project_repository.dart`)
  - Project queries
  - Room queries
  - GraphQL operations

## Configuration

### GraphQL Endpoint

Set the API endpoint in your environment:

```dart
// .env
GRAPHQL_API_URL=https://api.vron.stage.motorenflug.at/graphql
```

### Upload Settings

Configure in `lib/src/services/upload_service.dart`:

```dart
const int kChunkSize = 5 * 1024 * 1024;  // 5MB chunks
const int kMaxRetries = 3;                // Max retry attempts
const int kInitialRetryDelay = 1000;      // 1 second initial delay
```

## API Reference

### UploadService

```dart
// Queue upload
final uploadId = await uploadService.queueUpload(
  roomId: 'room-123',
  fileType: FileType.sceneGlb,
  filePath: '/path/to/file.glb',
);

// Upload file
await uploadService.uploadFile(
  uploadId: uploadId,
  uploadUrl: presignedUrl,
  onProgress: (sent, total) => print('$sent/$total'),
);

// Resume pending uploads
await uploadService.resumePendingUploads('room-123');

// Retry failed upload
await uploadService.retryUpload(uploadId);

// Cancel upload
await uploadService.cancelUpload(uploadId);
```

### UploadNotifier

```dart
// Start complete workflow
await uploadNotifier.startUpload(
  roomId: 'room-123',
  fileType: FileType.sceneGlb,
  filePath: '/path/to/file.glb',
  fileName: 'file.glb',
  createRoomIfNeeded: () async => 'room-123',
  requestUploadUrl: (...) async => (uploadUrl: '...', fileKey: '...'),
  uploadRoomAssets: (...) async {},
);

// Retry failed upload
await uploadNotifier.retryUpload('room-123', FileType.sceneGlb);

// Cancel upload
await uploadNotifier.cancelUpload('room-123', FileType.sceneGlb);
```

### AuthRepository

```dart
// Sign in
await authRepo.signIn(
  email: 'user@example.com',
  password: 'password',
);

// Check authentication
final isAuth = await authRepo.isAuthenticated();

// Get access token
final token = await authRepo.getAccessToken();

// Sign out
await authRepo.signOut();
```

### ProjectRepository

```dart
// Get projects (paginated)
final projects = await projectRepo.getProjects(first: 20, after: cursor);

// Get single project
final project = await projectRepo.getProject(id: 'project-123');

// Get rooms for project
final rooms = await projectRepo.getRooms(projectId: 'project-123');
```

## Error Handling

```dart
try {
  await uploadService.queueUpload(...);
} on FileSystemException catch (e) {
  print('File not found: ${e.path}');
} on StateError catch (e) {
  print('Invalid state: $e');
} catch (e) {
  print('Upload failed: $e');
}
```

## Testing

Run tests:

```bash
flutter test
```

## Documentation

- [Upload Infrastructure Guide](UPLOAD_INFRASTRUCTURE.md) - Detailed documentation
- [GraphQL Schema](graphql/schema.graphql) - API schema definition

## Dependencies

Core dependencies:
- `graphql_flutter: ^5.1.0` - GraphQL client
- `dio: ^5.4.0` - HTTP client for uploads
- `drift: ^2.14.0` - Database ORM
- `flutter_riverpod: ^2.4.0` - State management
- `flutter_secure_storage: ^9.0.0` - Secure token storage

## Examples

See [UPLOAD_INFRASTRUCTURE.md](UPLOAD_INFRASTRUCTURE.md) for comprehensive examples:
- Basic upload flow
- Monitoring progress
- Handling network changes
- Retry failed uploads
- Background sync

## Troubleshooting

### Upload stuck at 0%

Check that:
1. Network is available
2. Upload URL was obtained successfully
3. File exists at specified path

### Upload doesn't resume after network loss

Ensure:
1. `UploadNotifier` is properly initialized via provider
2. Background sync is active
3. Drift database is initialized

### Memory issues with large files

Verify:
1. Files are read in chunks, not loaded entirely
2. Only one chunk in memory at a time
3. Chunks are not accumulated

For more troubleshooting tips, see [UPLOAD_INFRASTRUCTURE.md](UPLOAD_INFRASTRUCTURE.md#troubleshooting).

## Contributing

This is an internal package for the VRON Mobile Companion app.

## License

Proprietary - VRON Project

## Support

For issues or questions, contact the development team.
