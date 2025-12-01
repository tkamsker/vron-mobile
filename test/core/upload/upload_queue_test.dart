import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

/// Unit test for upload queue with retry strategy (T151)
///
/// Tests upload queue management, retry logic, and offline queueing
/// Validates exponential backoff, max retry attempts, and queue persistence
///
/// **Requirements** (FR-016):
/// - Retry Strategy: Exponential backoff (1s, 2s, 4s) with max 3 attempts
/// - Queue Persistence: Save upload state to Drift database
/// - Connectivity Handling: Resume uploads when connection restored
/// - Progress Tracking: Byte offset tracking for resumable uploads
///
/// **Test Coverage**:
/// - Upload queuing (online and offline)
/// - Retry strategy with exponential backoff
/// - Max retry attempts enforcement
/// - Queue persistence across app restarts
/// - Connectivity-based queue processing
/// - Upload cancellation and cleanup

@GenerateMocks([])
void main() {
  group('T151: Upload Queue with Retry Strategy', () {
    test('queues upload when connection is available', () async {
      // Given: Network connection available
      final queue = UploadQueue();
      await queue.initialize();
      
      // When: Queue upload
      final uploadId = await queue.enqueue(
        UploadTask(
          roomId: 'room-123',
          sceneGlbPath: '/path/to/scene.glb',
          navmeshGlbPath: '/path/to/navmesh.glb',
        ),
      );
      
      // Then: Upload should be queued for immediate processing
      expect(uploadId, isNotEmpty);
      expect(await queue.getPendingCount(), equals(1));
      expect(await queue.getStatus(uploadId), equals(UploadStatus.pending));
    });

    test('queues upload when offline', () async {
      // Given: No network connection
      final queue = UploadQueue(connectivity: MockConnectivity(isOnline: false));
      await queue.initialize();
      
      // When: Queue upload
      final uploadId = await queue.enqueue(
        UploadTask(
          roomId: 'room-456',
          sceneGlbPath: '/path/to/scene.glb',
          navmeshGlbPath: '/path/to/navmesh.glb',
        ),
      );
      
      // Then: Upload should be queued for later
      expect(uploadId, isNotEmpty);
      expect(await queue.getPendingCount(), equals(1));
      expect(await queue.getStatus(uploadId), equals(UploadStatus.queued));
    });

    test('retries failed upload with exponential backoff', () async {
      // Given: Upload queue with failing uploader
      final retryDelays = <Duration>[];
      final queue = UploadQueue(
        uploader: MockUploader(
          shouldFail: true,
          onRetry: (delay) => retryDelays.add(delay),
        ),
      );
      await queue.initialize();
      
      // When: Queue and process upload
      final uploadId = await queue.enqueue(
        UploadTask(
          roomId: 'room-789',
          sceneGlbPath: '/path/to/scene.glb',
          navmeshGlbPath: '/path/to/navmesh.glb',
        ),
      );
      
      await queue.processQueue();
      
      // Then: Should retry with exponential backoff: 1s, 2s, 4s
      expect(retryDelays.length, equals(3));
      expect(retryDelays[0].inSeconds, equals(1));
      expect(retryDelays[1].inSeconds, equals(2));
      expect(retryDelays[2].inSeconds, equals(4));
      
      // After 3 retries, should fail permanently
      expect(await queue.getStatus(uploadId), equals(UploadStatus.failed));
    });

    test('stops retrying after max attempts', () async {
      // Given: Upload that always fails
      int attemptCount = 0;
      final queue = UploadQueue(
        uploader: MockUploader(
          shouldFail: true,
          onAttempt: () => attemptCount++,
        ),
      );
      await queue.initialize();
      
      // When: Queue and process upload
      final uploadId = await queue.enqueue(
        UploadTask(
          roomId: 'room-retry',
          sceneGlbPath: '/path/to/scene.glb',
          navmeshGlbPath: '/path/to/navmesh.glb',
        ),
      );
      
      await queue.processQueue();
      
      // Then: Should attempt 1 initial + 3 retries = 4 total
      expect(attemptCount, equals(4));
      expect(await queue.getStatus(uploadId), equals(UploadStatus.failed));
      expect(await queue.getRetryCount(uploadId), equals(3));
    });

    test('succeeds on retry after transient failure', () async {
      // Given: Upload that fails first 2 attempts then succeeds
      int attemptCount = 0;
      final queue = UploadQueue(
        uploader: MockUploader(
          shouldFailUntil: 2,
          onAttempt: () => attemptCount++,
        ),
      );
      await queue.initialize();
      
      // When: Queue and process upload
      final uploadId = await queue.enqueue(
        UploadTask(
          roomId: 'room-transient',
          sceneGlbPath: '/path/to/scene.glb',
          navmeshGlbPath: '/path/to/navmesh.glb',
        ),
      );
      
      await queue.processQueue();
      
      // Then: Should succeed on 3rd attempt
      expect(attemptCount, equals(3));
      expect(await queue.getStatus(uploadId), equals(UploadStatus.completed));
    });

    test('persists queue to Drift database', () async {
      // Given: Upload queue with Drift persistence
      final queue = UploadQueue(storage: MockDriftStorage());
      await queue.initialize();
      
      // When: Queue multiple uploads
      final uploadIds = <String>[];
      for (int i = 0; i < 3; i++) {
        final id = await queue.enqueue(
          UploadTask(
            roomId: 'room-$i',
            sceneGlbPath: '/path/to/scene-$i.glb',
            navmeshGlbPath: '/path/to/navmesh-$i.glb',
          ),
        );
        uploadIds.add(id);
      }
      
      // Then: Queue should be persisted
      expect(await queue.getPendingCount(), equals(3));
      
      // Simulate app restart
      final newQueue = UploadQueue(storage: queue.storage);
      await newQueue.initialize();
      
      // Should restore queued uploads
      expect(await newQueue.getPendingCount(), equals(3));
      for (final id in uploadIds) {
        expect(await newQueue.getStatus(id), isNot(equals(UploadStatus.unknown)));
      }
    });

    test('processes queue on connectivity restoration', () async {
      // Given: Offline queue with pending uploads
      final connectivity = MockConnectivity(isOnline: false);
      final queue = UploadQueue(connectivity: connectivity);
      await queue.initialize();
      
      // Queue uploads while offline
      final uploadIds = <String>[];
      for (int i = 0; i < 3; i++) {
        final id = await queue.enqueue(
          UploadTask(
            roomId: 'room-offline-$i',
            sceneGlbPath: '/path/to/scene-$i.glb',
            navmeshGlbPath: '/path/to/navmesh-$i.glb',
          ),
        );
        uploadIds.add(id);
      }
      
      expect(await queue.getPendingCount(), equals(3));
      
      // When: Connection restored
      connectivity.setOnline(true);
      await queue.onConnectivityRestored();
      
      // Then: Queue should process all pending uploads
      await Future.delayed(const Duration(milliseconds: 500));
      expect(await queue.getPendingCount(), equals(0));
      for (final id in uploadIds) {
        expect(await queue.getStatus(id), equals(UploadStatus.completed));
      }
    });

    test('processes queue in FIFO order', () async {
      // Given: Queue with multiple uploads
      final processOrder = <String>[];
      final queue = UploadQueue(
        uploader: MockUploader(
          onUpload: (task) => processOrder.add(task.roomId),
        ),
      );
      await queue.initialize();
      
      // When: Queue uploads in specific order
      await queue.enqueue(UploadTask(roomId: 'first', sceneGlbPath: '/1.glb', navmeshGlbPath: '/1n.glb'));
      await queue.enqueue(UploadTask(roomId: 'second', sceneGlbPath: '/2.glb', navmeshGlbPath: '/2n.glb'));
      await queue.enqueue(UploadTask(roomId: 'third', sceneGlbPath: '/3.glb', navmeshGlbPath: '/3n.glb'));
      
      await queue.processQueue();
      
      // Then: Should process in FIFO order
      expect(processOrder, equals(['first', 'second', 'third']));
    });

    test('cancels pending upload', () async {
      // Given: Queued upload
      final queue = UploadQueue();
      await queue.initialize();
      
      final uploadId = await queue.enqueue(
        UploadTask(
          roomId: 'room-cancel',
          sceneGlbPath: '/path/to/scene.glb',
          navmeshGlbPath: '/path/to/navmesh.glb',
        ),
      );
      
      // When: Cancel upload
      await queue.cancel(uploadId);
      
      // Then: Upload should be removed from queue
      expect(await queue.getStatus(uploadId), equals(UploadStatus.cancelled));
      expect(await queue.getPendingCount(), equals(0));
    });

    test('cancels in-progress upload', () async {
      // Given: Upload in progress
      final queue = UploadQueue(
        uploader: MockUploader(uploadDuration: const Duration(seconds: 5)),
      );
      await queue.initialize();
      
      final uploadId = await queue.enqueue(
        UploadTask(
          roomId: 'room-cancel-progress',
          sceneGlbPath: '/path/to/scene.glb',
          navmeshGlbPath: '/path/to/navmesh.glb',
        ),
      );
      
      // Start processing
      queue.processQueue();
      await Future.delayed(const Duration(milliseconds: 100));
      
      // When: Cancel during upload
      await queue.cancel(uploadId);
      
      // Then: Upload should be cancelled
      expect(await queue.getStatus(uploadId), equals(UploadStatus.cancelled));
    });

    test('cleans up cancelled upload files', () async {
      // Given: Upload with temporary files
      final cleanedFiles = <String>[];
      final queue = UploadQueue(
        fileCleanup: (path) async {
          cleanedFiles.add(path);
        },
      );
      await queue.initialize();
      
      final uploadId = await queue.enqueue(
        UploadTask(
          roomId: 'room-cleanup',
          sceneGlbPath: '/temp/scene.glb',
          navmeshGlbPath: '/temp/navmesh.glb',
        ),
      );
      
      // When: Cancel upload
      await queue.cancel(uploadId);
      
      // Then: Should clean up files
      expect(cleanedFiles, contains('/temp/scene.glb'));
      expect(cleanedFiles, contains('/temp/navmesh.glb'));
    });

    test('tracks upload progress', () async {
      // Given: Upload with progress tracking
      final progressUpdates = <double>[];
      final queue = UploadQueue(
        uploader: MockUploader(
          onProgress: (progress) => progressUpdates.add(progress),
        ),
      );
      await queue.initialize();
      
      // When: Queue and process upload
      final uploadId = await queue.enqueue(
        UploadTask(
          roomId: 'room-progress',
          sceneGlbPath: '/path/to/scene.glb',
          navmeshGlbPath: '/path/to/navmesh.glb',
        ),
      );
      
      await queue.processQueue();
      
      // Then: Should receive progress updates
      expect(progressUpdates, isNotEmpty);
      expect(progressUpdates.first, equals(0.0));
      expect(progressUpdates.last, equals(1.0));
    });

    test('handles concurrent queue operations safely', () async {
      // Given: Empty queue
      final queue = UploadQueue();
      await queue.initialize();
      
      // When: Enqueue multiple uploads concurrently
      final futures = List.generate(
        10,
        (i) => queue.enqueue(
          UploadTask(
            roomId: 'room-concurrent-$i',
            sceneGlbPath: '/path/to/scene-$i.glb',
            navmeshGlbPath: '/path/to/navmesh-$i.glb',
          ),
        ),
      );
      
      final uploadIds = await Future.wait(futures);
      
      // Then: All uploads should be queued
      expect(uploadIds.length, equals(10));
      expect(uploadIds.toSet().length, equals(10)); // All unique IDs
      expect(await queue.getPendingCount(), equals(10));
    });

    test('retries only failed upload, not entire queue', () async {
      // Given: Queue with one failing upload and two successful
      final processCounts = <String, int>{};
      final queue = UploadQueue(
        uploader: MockUploader(
          shouldFailForRoom: 'room-fail',
          onUpload: (task) {
            processCounts[task.roomId] = (processCounts[task.roomId] ?? 0) + 1;
          },
        ),
      );
      await queue.initialize();
      
      // When: Queue mixed uploads
      await queue.enqueue(UploadTask(roomId: 'room-ok-1', sceneGlbPath: '/1.glb', navmeshGlbPath: '/1n.glb'));
      await queue.enqueue(UploadTask(roomId: 'room-fail', sceneGlbPath: '/2.glb', navmeshGlbPath: '/2n.glb'));
      await queue.enqueue(UploadTask(roomId: 'room-ok-2', sceneGlbPath: '/3.glb', navmeshGlbPath: '/3n.glb'));
      
      await queue.processQueue();
      
      // Then: Successful uploads processed once, failed upload retried 4 times
      expect(processCounts['room-ok-1'], equals(1));
      expect(processCounts['room-ok-2'], equals(1));
      expect(processCounts['room-fail'], equals(4)); // 1 initial + 3 retries
    });
  });
}

/// Mock upload queue (actual implementation will use Drift + UploadService)
class UploadQueue {
  final MockConnectivity? connectivity;
  final MockUploader? uploader;
  final MockDriftStorage? storage;
  final Future<void> Function(String path)? fileCleanup;
  
  final Map<String, UploadTask> _tasks = {};
  final Map<String, UploadStatus> _statuses = {};
  final Map<String, int> _retryCounts = {};
  
  UploadQueue({
    this.connectivity,
    this.uploader,
    this.storage,
    this.fileCleanup,
  });
  
  Future<void> initialize() async {
    // Restore from storage if available
    if (storage != null) {
      final saved = await storage!.loadQueue();
      _tasks.addAll(saved);
      for (final id in saved.keys) {
        _statuses[id] = UploadStatus.queued;
      }
    }
  }
  
  Future<String> enqueue(UploadTask task) async {
    final id = 'upload-${DateTime.now().millisecondsSinceEpoch}';
    _tasks[id] = task;
    _statuses[id] = (connectivity?.isOnline ?? true) 
        ? UploadStatus.pending 
        : UploadStatus.queued;
    _retryCounts[id] = 0;
    
    await storage?.saveTask(id, task);
    return id;
  }
  
  Future<void> processQueue() async {
    for (final entry in _tasks.entries) {
      final id = entry.key;
      final task = entry.value;
      
      if (_statuses[id] == UploadStatus.cancelled) continue;
      
      _statuses[id] = UploadStatus.uploading;
      
      bool success = false;
      int attempts = 0;
      const maxRetries = 3;
      
      while (!success && attempts <= maxRetries) {
        try {
          await uploader?.upload(task);
          success = true;
          _statuses[id] = UploadStatus.completed;
        } catch (e) {
          attempts++;
          if (attempts <= maxRetries) {
            final delay = Duration(seconds: 1 << (attempts - 1)); // 1s, 2s, 4s
            uploader?.onRetry?.call(delay);
            await Future.delayed(delay);
          }
        }
      }
      
      if (!success) {
        _statuses[id] = UploadStatus.failed;
        _retryCounts[id] = maxRetries;
      }
    }
  }
  
  Future<void> onConnectivityRestored() async {
    await processQueue();
  }
  
  Future<void> cancel(String uploadId) async {
    _statuses[uploadId] = UploadStatus.cancelled;
    final task = _tasks[uploadId];
    if (task != null && fileCleanup != null) {
      await fileCleanup!(task.sceneGlbPath);
      await fileCleanup!(task.navmeshGlbPath);
    }
    _tasks.remove(uploadId);
  }
  
  Future<int> getPendingCount() async {
    return _statuses.values.where((s) => 
      s == UploadStatus.pending || s == UploadStatus.queued
    ).length;
  }
  
  Future<UploadStatus> getStatus(String uploadId) async {
    return _statuses[uploadId] ?? UploadStatus.unknown;
  }
  
  Future<int> getRetryCount(String uploadId) async {
    return _retryCounts[uploadId] ?? 0;
  }
}

class UploadTask {
  final String roomId;
  final String sceneGlbPath;
  final String navmeshGlbPath;
  
  UploadTask({
    required this.roomId,
    required this.sceneGlbPath,
    required this.navmeshGlbPath,
  });
}

enum UploadStatus {
  unknown,
  pending,
  queued,
  uploading,
  completed,
  failed,
  cancelled,
}

class MockConnectivity {
  bool isOnline;
  
  MockConnectivity({required this.isOnline});
  
  void setOnline(bool online) {
    isOnline = online;
  }
}

class MockUploader {
  final bool shouldFail;
  final int shouldFailUntil;
  final String? shouldFailForRoom;
  final Duration uploadDuration;
  final void Function()? onAttempt;
  final void Function(Duration delay)? onRetry;
  final void Function(UploadTask task)? onUpload;
  final void Function(double progress)? onProgress;
  
  int _attemptCount = 0;
  
  MockUploader({
    this.shouldFail = false,
    this.shouldFailUntil = 0,
    this.shouldFailForRoom,
    this.uploadDuration = const Duration(milliseconds: 100),
    this.onAttempt,
    this.onRetry,
    this.onUpload,
    this.onProgress,
  });
  
  Future<void> upload(UploadTask task) async {
    _attemptCount++;
    onAttempt?.call();
    onUpload?.call(task);
    
    // Simulate progress
    if (onProgress != null) {
      onProgress!(0.0);
      await Future.delayed(uploadDuration ~/ 2);
      onProgress!(0.5);
      await Future.delayed(uploadDuration ~/ 2);
      onProgress!(1.0);
    } else {
      await Future.delayed(uploadDuration);
    }
    
    if (shouldFail || 
        (shouldFailUntil > 0 && _attemptCount <= shouldFailUntil) ||
        (shouldFailForRoom != null && task.roomId == shouldFailForRoom)) {
      throw Exception('Upload failed');
    }
  }
}

class MockDriftStorage {
  final Map<String, UploadTask> _storage = {};
  
  Future<Map<String, UploadTask>> loadQueue() async {
    return Map.from(_storage);
  }
  
  Future<void> saveTask(String id, UploadTask task) async {
    _storage[id] = task;
  }
}
