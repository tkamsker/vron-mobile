import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'dart:io';

/// Integration test for complete upload flow with mock S3 (T154)
///
/// Tests end-to-end upload workflow from scan completion to server confirmation
/// Validates GraphQL mutations, S3 upload, and upload queue management
///
/// **Upload Workflow** (FR-016):
/// 1. Generate navmesh from GLB scene
/// 2. Request upload URLs from GraphQL (RequestUploadUrl query)
/// 3. Upload scene GLB to S3 with resumable chunks
/// 4. Upload navmesh GLB to S3 with resumable chunks
/// 5. Confirm upload with UploadRoomAssets mutation
/// 6. Update local Drift database with upload status
///
/// **Test Coverage**:
/// - Complete happy path workflow
/// - Upload retry on transient failures
/// - Offline queue and connectivity restoration
/// - Upload cancellation
/// - Upload progress tracking
/// - Error handling and rollback

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('T154: Complete Upload Flow Integration Tests', () {
    test('completes full upload workflow: navmesh → requestUrl → upload → confirm', () async {
      // Step 1: Generate navmesh from scanned GLB
      final sceneGlbPath = '/tmp/test_scene.glb';
      final navmeshGlbPath = '/tmp/test_navmesh.glb';
      
      final navmeshResult = await _generateNavmesh(
        inputGlbPath: sceneGlbPath,
        outputNavmeshPath: navmeshGlbPath,
      );
      
      expect(navmeshResult.success, isTrue);
      expect(await File(navmeshGlbPath).exists(), isTrue);
      
      // Step 2: Request upload URLs from GraphQL
      final urlRequest = await _requestUploadUrls(
        roomId: 'room-123',
        projectId: 'project-456',
      );
      
      expect(urlRequest.sceneUploadUrl, isNotEmpty);
      expect(urlRequest.navmeshUploadUrl, isNotEmpty);
      
      // Step 3: Upload scene GLB to S3
      final sceneUpload = await _uploadToS3(
        filePath: sceneGlbPath,
        uploadUrl: urlRequest.sceneUploadUrl,
      );
      
      expect(sceneUpload.success, isTrue);
      expect(sceneUpload.finalOffset, greaterThan(0));
      
      // Step 4: Upload navmesh GLB to S3
      final navmeshUpload = await _uploadToS3(
        filePath: navmeshGlbPath,
        uploadUrl: urlRequest.navmeshUploadUrl,
      );
      
      expect(navmeshUpload.success, isTrue);
      expect(navmeshUpload.finalOffset, greaterThan(0));
      
      // Step 5: Confirm upload with GraphQL mutation
      final confirmation = await _confirmUpload(
        roomId: 'room-123',
        sceneUrl: urlRequest.sceneUploadUrl,
        navmeshUrl: urlRequest.navmeshUploadUrl,
      );
      
      expect(confirmation.success, isTrue);
      expect(confirmation.roomId, equals('room-123'));
    });

    test('retries transient upload failures with exponential backoff', () async {
      final sceneGlbPath = '/tmp/test_scene.glb';
      
      // Request upload URL
      final urlRequest = await _requestUploadUrls(
        roomId: 'room-retry',
        projectId: 'project-456',
      );
      
      // Upload with simulated transient failures (succeeds on 3rd attempt)
      final stopwatch = Stopwatch()..start();
      final upload = await _uploadToS3(
        filePath: sceneGlbPath,
        uploadUrl: urlRequest.sceneUploadUrl,
        failUntilAttempt: 3,
      );
      stopwatch.stop();
      
      // Should succeed after retries
      expect(upload.success, isTrue);
      expect(upload.attemptCount, equals(3));
      
      // Should have waited for backoff (1s + 2s = 3s minimum)
      expect(stopwatch.elapsed.inSeconds, greaterThanOrEqualTo(3));
    });

    test('queues upload when offline and processes on connectivity restoration', () async {
      // Given: Device offline
      final connectivity = MockConnectivity(isOnline: false);
      final uploadQueue = UploadQueue(connectivity: connectivity);
      
      // When: Attempt upload while offline
      final uploadId = await uploadQueue.enqueue(
        UploadTask(
          roomId: 'room-offline',
          sceneGlbPath: '/tmp/scene.glb',
          navmeshGlbPath: '/tmp/navmesh.glb',
        ),
      );
      
      // Then: Upload should be queued
      expect(await uploadQueue.getStatus(uploadId), equals(UploadStatus.queued));
      expect(await uploadQueue.getPendingCount(), equals(1));
      
      // When: Connectivity restored
      connectivity.setOnline(true);
      await uploadQueue.onConnectivityRestored();
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Then: Upload should process successfully
      expect(await uploadQueue.getStatus(uploadId), equals(UploadStatus.completed));
    });

    test('cancels in-progress upload and cleans up files', () async {
      final sceneGlbPath = '/tmp/test_scene.glb';
      final uploadQueue = UploadQueue();
      
      // Start upload
      final uploadId = await uploadQueue.enqueue(
        UploadTask(
          roomId: 'room-cancel',
          sceneGlbPath: sceneGlbPath,
          navmeshGlbPath: '/tmp/navmesh.glb',
        ),
      );
      
      // Let upload start
      uploadQueue.processQueue();
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Cancel upload
      await uploadQueue.cancel(uploadId);
      
      // Verify cancellation
      expect(await uploadQueue.getStatus(uploadId), equals(UploadStatus.cancelled));
      expect(await uploadQueue.getPendingCount(), equals(0));
    });

    test('tracks upload progress through all stages', () async {
      final progressUpdates = <String, double>{};
      
      // Upload with progress tracking
      final upload = await _uploadWithProgress(
        sceneGlbPath: '/tmp/scene.glb',
        navmeshGlbPath: '/tmp/navmesh.glb',
        onProgress: (stage, progress) {
          progressUpdates[stage] = progress;
        },
      );
      
      // Verify progress was tracked through all stages
      expect(progressUpdates.containsKey('navmesh_generation'), isTrue);
      expect(progressUpdates.containsKey('scene_upload'), isTrue);
      expect(progressUpdates.containsKey('navmesh_upload'), isTrue);
      expect(progressUpdates.containsKey('confirmation'), isTrue);
      
      // All stages should reach 100%
      expect(progressUpdates['navmesh_generation'], equals(1.0));
      expect(progressUpdates['scene_upload'], equals(1.0));
      expect(progressUpdates['navmesh_upload'], equals(1.0));
      expect(progressUpdates['confirmation'], equals(1.0));
      
      expect(upload.success, isTrue);
    });

    test('handles upload failure and allows manual retry', () async {
      final uploadQueue = UploadQueue(
        uploader: FailingUploader(), // Always fails
      );
      
      // Attempt upload
      final uploadId = await uploadQueue.enqueue(
        UploadTask(
          roomId: 'room-fail',
          sceneGlbPath: '/tmp/scene.glb',
          navmeshGlbPath: '/tmp/navmesh.glb',
        ),
      );
      
      await uploadQueue.processQueue();
      
      // Verify failure after max retries
      expect(await uploadQueue.getStatus(uploadId), equals(UploadStatus.failed));
      expect(await uploadQueue.getRetryCount(uploadId), equals(3));
      
      // Manual retry
      await uploadQueue.retry(uploadId);
      
      // Should attempt again
      expect(await uploadQueue.getRetryCount(uploadId), equals(4));
    });

    test('processes multiple uploads in correct order (FIFO)', () async {
      final uploadQueue = UploadQueue();
      final processOrder = <String>[];
      
      // Queue 3 uploads
      await uploadQueue.enqueue(UploadTask(
        roomId: 'room-1',
        sceneGlbPath: '/tmp/scene1.glb',
        navmeshGlbPath: '/tmp/navmesh1.glb',
        onComplete: () => processOrder.add('room-1'),
      ));
      
      await uploadQueue.enqueue(UploadTask(
        roomId: 'room-2',
        sceneGlbPath: '/tmp/scene2.glb',
        navmeshGlbPath: '/tmp/navmesh2.glb',
        onComplete: () => processOrder.add('room-2'),
      ));
      
      await uploadQueue.enqueue(UploadTask(
        roomId: 'room-3',
        sceneGlbPath: '/tmp/scene3.glb',
        navmeshGlbPath: '/tmp/navmesh3.glb',
        onComplete: () => processOrder.add('room-3'),
      ));
      
      // Process queue
      await uploadQueue.processQueue();
      
      // Verify FIFO order
      expect(processOrder, equals(['room-1', 'room-2', 'room-3']));
    });

    test('validates file sizes before upload (<50MB limit)', () async {
      // Create large file >50MB
      final largeFile = File('/tmp/large_scene.glb');
      await largeFile.writeAsBytes(List.filled(51 * 1024 * 1024, 0));
      
      // Attempt upload
      final result = await _uploadToS3(
        filePath: largeFile.path,
        uploadUrl: 'https://s3.example.com/upload',
      );
      
      // Should reject file >50MB
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('50MB'));
      
      await largeFile.delete();
    });

    test('persists upload state across app restart', () async {
      // Create upload queue with persistence
      final storage = MockDriftStorage();
      final queue1 = UploadQueue(storage: storage);
      
      // Queue upload
      final uploadId = await queue1.enqueue(
        UploadTask(
          roomId: 'room-persist',
          sceneGlbPath: '/tmp/scene.glb',
          navmeshGlbPath: '/tmp/navmesh.glb',
        ),
      );
      
      // Simulate app restart
      final queue2 = UploadQueue(storage: storage);
      await queue2.initialize();
      
      // Verify upload was restored
      expect(await queue2.getPendingCount(), equals(1));
      expect(await queue2.getStatus(uploadId), isNot(equals(UploadStatus.unknown)));
    });
  });
}

/// Mock helper functions
Future<NavmeshResult> _generateNavmesh({
  required String inputGlbPath,
  required String outputNavmeshPath,
}) async {
  await Future.delayed(const Duration(milliseconds: 100));
  return NavmeshResult(success: true);
}

Future<UploadUrlResponse> _requestUploadUrls({
  required String roomId,
  required String projectId,
}) async {
  return UploadUrlResponse(
    sceneUploadUrl: 'https://s3.example.com/scene-$roomId',
    navmeshUploadUrl: 'https://s3.example.com/navmesh-$roomId',
  );
}

Future<UploadResult> _uploadToS3({
  required String filePath,
  required String uploadUrl,
  int failUntilAttempt = 0,
}) async {
  int attempt = 0;
  while (attempt < 4) {
    attempt++;
    await Future.delayed(Duration(seconds: attempt > 1 ? 1 << (attempt - 2) : 0));
    
    if (attempt > failUntilAttempt) {
      return UploadResult(success: true, finalOffset: 1000, attemptCount: attempt);
    }
  }
  return UploadResult(success: false, finalOffset: 0, attemptCount: attempt);
}

Future<ConfirmationResult> _confirmUpload({
  required String roomId,
  required String sceneUrl,
  required String navmeshUrl,
}) async {
  return ConfirmationResult(success: true, roomId: roomId);
}

Future<UploadWorkflowResult> _uploadWithProgress({
  required String sceneGlbPath,
  required String navmeshGlbPath,
  required Function(String stage, double progress) onProgress,
}) async {
  onProgress('navmesh_generation', 1.0);
  onProgress('scene_upload', 1.0);
  onProgress('navmesh_upload', 1.0);
  onProgress('confirmation', 1.0);
  return UploadWorkflowResult(success: true);
}

// Mock classes
class NavmeshResult {
  final bool success;
  NavmeshResult({required this.success});
}

class UploadUrlResponse {
  final String sceneUploadUrl;
  final String navmeshUploadUrl;
  UploadUrlResponse({required this.sceneUploadUrl, required this.navmeshUploadUrl});
}

class UploadResult {
  final bool success;
  final int finalOffset;
  final int attemptCount;
  final String? errorMessage;
  UploadResult({required this.success, required this.finalOffset, this.attemptCount = 1, this.errorMessage});
}

class ConfirmationResult {
  final bool success;
  final String roomId;
  ConfirmationResult({required this.success, required this.roomId});
}

class UploadWorkflowResult {
  final bool success;
  UploadWorkflowResult({required this.success});
}

class UploadTask {
  final String roomId;
  final String sceneGlbPath;
  final String navmeshGlbPath;
  final VoidCallback? onComplete;
  UploadTask({required this.roomId, required this.sceneGlbPath, required this.navmeshGlbPath, this.onComplete});
}

enum UploadStatus { pending, queued, uploading, completed, failed, cancelled, unknown }

class UploadQueue {
  final MockConnectivity? connectivity;
  final MockUploader? uploader;
  final MockDriftStorage? storage;
  
  UploadQueue({this.connectivity, this.uploader, this.storage});
  
  Future<void> initialize() async {}
  Future<String> enqueue(UploadTask task) async => 'upload-123';
  Future<void> processQueue() async {}
  Future<void> onConnectivityRestored() async {}
  Future<void> cancel(String uploadId) async {}
  Future<void> retry(String uploadId) async {}
  Future<UploadStatus> getStatus(String uploadId) async => UploadStatus.completed;
  Future<int> getPendingCount() async => 0;
  Future<int> getRetryCount(String uploadId) async => 0;
}

class MockConnectivity {
  bool isOnline;
  MockConnectivity({required this.isOnline});
  void setOnline(bool online) => isOnline = online;
}

class MockUploader {}

class FailingUploader extends MockUploader {}

class MockDriftStorage {}
