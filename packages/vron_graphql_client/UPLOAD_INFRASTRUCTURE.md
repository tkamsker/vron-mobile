# Upload Infrastructure Documentation

## Overview

This document describes the resumable upload infrastructure implemented for the VRON Mobile Companion app. The system supports chunked file uploads with progress persistence, automatic retry, and offline queueing.

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                        Application Layer                      │
│  (UI, Buttons, Progress Indicators, Notifications)           │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                    UploadNotifier                            │
│  • Workflow orchestration                                    │
│  • State management (StateNotifier)                          │
│  • Background sync monitoring                                │
│  • createRoom → requestUploadUrl → upload → confirm         │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                    UploadService                             │
│  • Chunked uploads (5MB chunks)                              │
│  • Content-Range header support                              │
│  • Exponential backoff retry (1s, 2s, 4s)                   │
│  • Progress persistence                                       │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                  UploadDatabase (Drift)                      │
│  • Persistent upload queue                                   │
│  • Progress tracking                                          │
│  • Retry state management                                    │
└─────────────────────────────────────────────────────────────┘
```

### Database Schema

**UploadQueue Table**:
```dart
class UploadQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get roomId => text()();
  TextColumn get fileType => text()();  // 'SCENE_GLB' | 'NAVMESH_GLB'
  TextColumn get filePath => text()();
  IntColumn get fileSize => integer()();
  IntColumn get uploadedBytes => integer().withDefault(const Constant(0))();
  TextColumn get uploadUrl => text().nullable()();
  TextColumn get fileKey => text().nullable()();
  TextColumn get cdnUrl => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastRetryAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
```

**Status Values**:
- `pending` - Queued for upload
- `uploading` - Currently uploading
- `completed` - Upload successful
- `failed` - Upload failed (after max retries)

## Upload Workflow

### Complete Upload Flow

```
1. Queue Upload
   └─> UploadService.queueUpload()
       └─> Insert into UploadQueue with status='pending'

2. Request Upload URL
   └─> GraphQL: requestUploadUrl(roomId, fileType, fileName, fileSize)
       └─> Returns { uploadUrl, fileKey, expiresAt }
       └─> Save uploadUrl and fileKey to database

3. Chunked Upload
   └─> UploadService.uploadFile()
       └─> Read file in 5MB chunks
       └─> For each chunk:
           ├─> PUT to uploadUrl with Content-Range header
           ├─> Update uploadedBytes in database
           └─> Call onProgress callback
       └─> On error: Retry with exponential backoff (max 3 attempts)

4. Confirm Upload
   └─> GraphQL: uploadRoomAssets(roomId, sceneGlbUrl, navmeshGlbUrl, fileSizes)
       └─> Mark upload as completed in database
```

### Resumable Upload Protocol

The upload service uses HTTP Content-Range headers to support resumable uploads:

```http
PUT /upload-url
Content-Range: bytes 0-5242879/10485760
Content-Type: application/octet-stream
Content-Length: 5242880

[5MB chunk data]
```

**Server Responses**:
- `200 OK` - Chunk accepted (partial upload)
- `201 Created` - Final chunk accepted (upload complete)
- `308 Resume Incomplete` - Chunk accepted, more chunks expected
- `4xx/5xx` - Error, retry with exponential backoff

### Offline Support

**Queueing**:
- Uploads are queued immediately in local database
- No network required to queue uploads
- Status set to `pending` until upload URL is obtained

**Background Sync**:
- `UploadNotifier` watches for pending uploads
- Automatically resumes uploads when connectivity is restored
- Processes uploads in order of creation (FIFO)

**Connectivity Handling**:
```dart
// Pending uploads are watched via Stream
_database.watchPendingUploads().listen((uploads) {
  _processPendingUploads();
});

// Resume from last uploaded byte
await _uploadService.uploadFile(
  uploadId: upload.id,
  uploadUrl: upload.uploadUrl!,
  // Starts from upload.uploadedBytes
);
```

## API Reference

### UploadService

#### queueUpload()
Queue a file for upload.

```dart
Future<int> queueUpload({
  required String roomId,
  required FileType fileType,
  required String filePath,
})
```

**Parameters**:
- `roomId` - Room ID this upload belongs to
- `fileType` - `FileType.sceneGlb` or `FileType.navmeshGlb`
- `filePath` - Absolute path to local file

**Returns**: Upload ID (database primary key)

**Throws**: `FileSystemException` if file doesn't exist

**Example**:
```dart
final uploadService = ref.read(uploadServiceProvider);

final uploadId = await uploadService.queueUpload(
  roomId: 'room-123',
  fileType: FileType.sceneGlb,
  filePath: '/path/to/scene.glb',
);
```

---

#### uploadFile()
Upload a queued file with resumable chunks.

```dart
Future<void> uploadFile({
  required int uploadId,
  required String uploadUrl,
  void Function(int sent, int total)? onProgress,
})
```

**Parameters**:
- `uploadId` - Upload queue entry ID
- `uploadUrl` - Presigned S3 upload URL
- `onProgress` - Progress callback (bytes sent, total bytes)

**Behavior**:
- Uploads in 5MB chunks with Content-Range headers
- Resumes from last uploaded byte if interrupted
- Retries failed chunks up to 3 times with exponential backoff
- Saves progress to database after each chunk

**Example**:
```dart
await uploadService.uploadFile(
  uploadId: uploadId,
  uploadUrl: presignedUrl,
  onProgress: (sent, total) {
    final progress = sent / total;
    print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
  },
);
```

---

#### resumePendingUploads()
Resume all pending uploads for a room (called on connectivity restoration).

```dart
Future<void> resumePendingUploads(String roomId)
```

**Example**:
```dart
// On network reconnection
await uploadService.resumePendingUploads('room-123');
```

---

#### retryUpload()
Retry a failed upload.

```dart
Future<void> retryUpload(int uploadId)
```

---

#### cancelUpload()
Cancel an upload.

```dart
Future<void> cancelUpload(int uploadId)
```

---

#### cleanupOldUploads()
Delete completed uploads older than specified duration.

```dart
Future<int> cleanupOldUploads({Duration age = const Duration(days: 7)})
```

**Returns**: Number of uploads deleted

---

### UploadNotifier

#### startUpload()
Start complete upload workflow (create room → request URL → upload → confirm).

```dart
Future<void> startUpload({
  required String roomId,
  required FileType fileType,
  required String filePath,
  required String fileName,
  required Future<String> Function() createRoomIfNeeded,
  required Future<({String uploadUrl, String fileKey})> Function(
    String roomId,
    String fileType,
    String fileName,
    int fileSize,
  ) requestUploadUrl,
  required Future<void> Function(
    String roomId,
    String? sceneUrl,
    String? navmeshUrl,
    int? sceneSize,
    int? navmeshSize,
  ) uploadRoomAssets,
})
```

**Parameters**:
- `roomId` - Room ID for this upload
- `fileType` - File type enum
- `filePath` - Local file path
- `fileName` - File name for upload
- `createRoomIfNeeded` - Callback to create room if needed
- `requestUploadUrl` - Callback to request presigned URL
- `uploadRoomAssets` - Callback to confirm upload with backend

**Example**:
```dart
final notifier = ref.read(uploadNotifierProvider.notifier);

await notifier.startUpload(
  roomId: 'room-123',
  fileType: FileType.sceneGlb,
  filePath: '/path/to/scene.glb',
  fileName: 'scene.glb',
  createRoomIfNeeded: () async {
    // GraphQL createRoom mutation
    return roomId;
  },
  requestUploadUrl: (roomId, fileType, fileName, fileSize) async {
    // GraphQL requestUploadUrl query
    final result = await client.query(...);
    return (
      uploadUrl: result.data.requestUploadUrl.uploadUrl,
      fileKey: result.data.requestUploadUrl.fileKey,
    );
  },
  uploadRoomAssets: (roomId, sceneUrl, navmeshUrl, sceneSize, navmeshSize) async {
    // GraphQL uploadRoomAssets mutation
    await client.mutate(...);
  },
);
```

---

#### retryUpload()
Retry a failed upload.

```dart
Future<void> retryUpload(String roomId, FileType fileType)
```

---

#### cancelUpload()
Cancel an upload.

```dart
Future<void> cancelUpload(String roomId, FileType fileType)
```

---

### UploadDatabase

#### getPendingUploads()
Get all pending/uploading entries for a room.

```dart
Future<List<UploadQueueEntry>> getPendingUploads(String roomId)
```

---

#### getUpload()
Get upload by ID.

```dart
Future<UploadQueueEntry?> getUpload(int id)
```

---

#### getUploadByRoomAndType()
Get upload by room ID and file type.

```dart
Future<UploadQueueEntry?> getUploadByRoomAndType(String roomId, String fileType)
```

---

#### watchPendingUploads()
Watch pending uploads (reactive stream for UI).

```dart
Stream<List<UploadQueueEntry>> watchPendingUploads()
```

---

#### updateUploadProgress()
Update upload progress.

```dart
Future<void> updateUploadProgress(int id, int uploadedBytes)
```

---

#### markUploadCompleted()
Mark upload as completed.

```dart
Future<void> markUploadCompleted(int id, String cdnUrl)
```

---

#### markUploadFailed()
Mark upload as failed.

```dart
Future<void> markUploadFailed(int id, String errorMessage)
```

---

## Usage Examples

### Basic Upload Flow

```dart
import 'package:vron_graphql_client/vron_graphql_client.dart';

class RoomScanUploader {
  final UploadNotifier notifier;
  final GraphQLClient client;

  Future<void> uploadSceneGlb({
    required String roomId,
    required String filePath,
  }) async {
    await notifier.startUpload(
      roomId: roomId,
      fileType: FileType.sceneGlb,
      filePath: filePath,
      fileName: 'scene.glb',
      createRoomIfNeeded: () async {
        final result = await client.mutate(
          MutationOptions(
            document: gql(createRoomMutation),
            variables: {
              'input': {
                'projectId': projectId,
                'name': 'Room $roomId',
                'scanDate': DateTime.now().toIso8601String(),
              }
            },
          ),
        );
        return result.data['createRoom']['id'];
      },
      requestUploadUrl: (roomId, fileType, fileName, fileSize) async {
        final result = await client.query(
          QueryOptions(
            document: gql(requestUploadUrlQuery),
            variables: {
              'input': {
                'roomId': roomId,
                'fileType': fileType,
                'fileName': fileName,
                'fileSize': fileSize,
              }
            },
          ),
        );
        final data = result.data['requestUploadUrl'];
        return (
          uploadUrl: data['uploadUrl'] as String,
          fileKey: data['fileKey'] as String,
        );
      },
      uploadRoomAssets: (roomId, sceneUrl, navmeshUrl, sceneSize, navmeshSize) async {
        await client.mutate(
          MutationOptions(
            document: gql(uploadRoomAssetsMutation),
            variables: {
              'input': {
                'roomId': roomId,
                'sceneGlbUrl': sceneUrl,
                'navmeshGlbUrl': navmeshUrl,
                'sceneFileSize': sceneSize,
                'navmeshFileSize': navmeshSize,
              }
            },
          ),
        );
      },
    );
  }
}
```

---

### Monitoring Upload Progress

```dart
class UploadProgressWidget extends ConsumerWidget {
  final String roomId;
  final FileType fileType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(
      uploadStateProvider((roomId, fileType.graphqlValue))
    );

    if (uploadState == null) {
      return Text('No upload in progress');
    }

    return Column(
      children: [
        Text('Status: ${uploadState.status}'),
        LinearProgressIndicator(value: uploadState.progress),
        Text('${(uploadState.progress * 100).toStringAsFixed(1)}%'),
        if (uploadState.error != null)
          Text('Error: ${uploadState.error}', style: TextStyle(color: Colors.red)),
      ],
    );
  }
}
```

---

### Handling Network Changes

```dart
class UploadManager {
  final UploadService uploadService;
  StreamSubscription? _connectivitySubscription;

  void startMonitoring() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        // Network is available, resume pending uploads
        _resumeAllPendingUploads();
      }
    });
  }

  Future<void> _resumeAllPendingUploads() async {
    final database = await getUploadDatabase();
    final pending = await database.getAllUploads();

    for (final upload in pending.where((u) => u.status == 'pending')) {
      await uploadService.resumePendingUploads(upload.roomId);
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
```

---

### Retry Failed Uploads

```dart
class UploadRetryButton extends ConsumerWidget {
  final String roomId;
  final FileType fileType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(uploadNotifierProvider.notifier);
    final uploadState = ref.watch(
      uploadStateProvider((roomId, fileType.graphqlValue))
    );

    if (uploadState?.status != UploadStatus.failed) {
      return SizedBox.shrink();
    }

    return ElevatedButton(
      onPressed: () async {
        try {
          await notifier.retryUpload(roomId, fileType);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload resumed')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Retry failed: $e')),
          );
        }
      },
      child: Text('Retry Upload'),
    );
  }
}
```

---

## Configuration

### Chunk Size

The default chunk size is 5MB. To modify:

```dart
// In upload_service.dart
const int kChunkSize = 5 * 1024 * 1024; // 5MB
```

**Considerations**:
- Smaller chunks: More frequent progress updates, higher overhead
- Larger chunks: Fewer progress updates, less overhead, longer retry delays

---

### Retry Configuration

```dart
// In upload_service.dart
const int kMaxRetries = 3;
const int kInitialRetryDelay = 1000; // 1 second
```

**Backoff Formula**: `delay = kInitialRetryDelay * (2 ^ (attempt - 1))`
- Attempt 1: 1 second
- Attempt 2: 2 seconds
- Attempt 3: 4 seconds

---

### Upload URL Expiration

Presigned S3 URLs expire after 1 hour. If upload takes longer:
1. Upload fails with 403 Forbidden
2. Service marks upload as failed
3. UI prompts user to retry (which requests new URL)

---

## Error Handling

### Common Errors

**FileSystemException**:
```dart
try {
  await uploadService.queueUpload(...);
} on FileSystemException catch (e) {
  print('File not found: ${e.path}');
  // Prompt user to re-scan or check file location
}
```

**DioException** (Network errors):
```dart
// Handled automatically with exponential backoff retry
// After max retries, upload marked as failed in database
// User can retry via UI
```

**StateError** (Upload not found):
```dart
try {
  await uploadService.uploadFile(...);
} on StateError catch (e) {
  print('Upload not found in database: $e');
  // Queue upload again
}
```

---

### Error Recovery

1. **Automatic Retry**: Failed chunks retry up to 3 times with exponential backoff
2. **Manual Retry**: User can retry failed uploads via UI
3. **Resume Upload**: Picks up from last successful chunk (using `uploadedBytes`)
4. **Cleanup**: Old completed uploads auto-deleted after 7 days

---

## Performance Considerations

### Memory Usage

- Files are read in 5MB chunks (not loaded entirely into memory)
- Only one chunk in memory at a time during upload
- Suitable for large files (100MB+)

---

### Database Performance

- Index on `(roomId, fileType)` for fast lookups
- Index on `(status, createdAt)` for pending uploads query
- Automatic cleanup of old completed uploads

---

### Concurrency

- Multiple uploads can run in parallel (different rooms)
- Uploads for same room processed sequentially
- Background sync processes pending uploads in FIFO order

---

## Testing

### Unit Tests

```dart
void main() {
  late UploadService uploadService;
  late UploadDatabase database;

  setUp(() async {
    database = UploadDatabase();
    uploadService = UploadService(database: database);
  });

  test('queueUpload creates database entry', () async {
    final uploadId = await uploadService.queueUpload(
      roomId: 'test-room',
      fileType: FileType.sceneGlb,
      filePath: '/path/to/test.glb',
    );

    final upload = await database.getUpload(uploadId);
    expect(upload, isNotNull);
    expect(upload!.roomId, 'test-room');
    expect(upload.status, 'pending');
  });

  test('uploadFile saves progress after each chunk', () async {
    // Mock file and presigned URL
    final uploadId = await uploadService.queueUpload(...);

    await uploadService.uploadFile(
      uploadId: uploadId,
      uploadUrl: mockPresignedUrl,
    );

    final upload = await database.getUpload(uploadId);
    expect(upload!.uploadedBytes, upload.fileSize);
    expect(upload.status, 'uploading');
  });
}
```

---

### Integration Tests

```dart
void main() {
  testWidgets('Upload progress updates UI', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: UploadProgressWidget(
            roomId: 'test-room',
            fileType: FileType.sceneGlb,
          ),
        ),
      ),
    );

    // Start upload
    final notifier = container.read(uploadNotifierProvider.notifier);
    notifier.startUpload(...);

    await tester.pump(Duration(seconds: 1));

    // Verify progress indicator appears
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
```

---

## Troubleshooting

### Upload Stuck at 0%

**Cause**: Upload URL not obtained or invalid

**Solution**:
1. Check network connectivity
2. Verify GraphQL `requestUploadUrl` query is successful
3. Check database entry has `uploadUrl` field populated

---

### Upload Fails Immediately

**Cause**: File not found or upload URL expired

**Solution**:
1. Verify file exists at `filePath`
2. Request new upload URL (URLs expire after 1 hour)
3. Check S3 bucket permissions

---

### Upload Doesn't Resume After Network Loss

**Cause**: Background sync not initialized

**Solution**:
1. Ensure `UploadNotifier` is instantiated via provider
2. Check `_initializeBackgroundSync()` is called
3. Verify Drift database is properly initialized

---

### Memory Issues with Large Files

**Cause**: Reading entire file into memory

**Solution**:
- Verify `_readFileChunk()` uses `RandomAccessFile.read(length)`
- Ensure chunks are not accumulated in memory
- Monitor memory usage during upload

---

## Migration Guide

### From Hive to Drift

If migrating from Hive-based storage:

1. Export existing upload queue from Hive
2. Create UploadQueue entries in Drift
3. Maintain `uploadedBytes` to preserve progress
4. Delete Hive boxes after successful migration

---

## Future Enhancements

### Potential Improvements

1. **Multi-part uploads**: Use S3 multi-part upload API for files >5GB
2. **Parallel chunk uploads**: Upload multiple chunks simultaneously
3. **Compression**: Compress GLB files before upload
4. **Delta uploads**: Only upload changed portions of files
5. **Upload scheduling**: Priority queue for uploads
6. **Bandwidth throttling**: Limit upload speed to preserve battery

---

## References

- [GraphQL Schema](graphql/schema.graphql)
- [Drift Documentation](https://drift.simonbinder.eu/docs/getting-started/)
- [Dio Documentation](https://pub.dev/packages/dio)
- [HTTP Content-Range](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Range)

---

## License

This upload infrastructure is part of the VRON Mobile Companion app.

---

## Support

For issues or questions, contact the development team.
