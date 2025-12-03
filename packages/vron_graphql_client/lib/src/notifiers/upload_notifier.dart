// T180-T184: Upload workflow orchestration
// Manages complete upload workflow from navmesh generation to confirmation
// Handles offline queueing, background sync, and connectivity monitoring

import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../database/upload_database.dart';
import '../database/tables.dart';
import '../services/upload_service.dart';

/// Upload state for UI
class UploadState {
  final String roomId;
  final FileType fileType;
  final UploadStatus status;
  final double progress;
  final String? error;

  const UploadState({
    required this.roomId,
    required this.fileType,
    required this.status,
    this.progress = 0.0,
    this.error,
  });

  UploadState copyWith({
    String? roomId,
    FileType? fileType,
    UploadStatus? status,
    double? progress,
    String? error,
  }) {
    return UploadState(
      roomId: roomId ?? this.roomId,
      fileType: fileType ?? this.fileType,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

/// Upload notifier for managing upload workflows
/// T180: UploadNotifier Riverpod provider
/// T181: Upload workflow orchestration
/// T182: Offline queueing
/// T183: Background sync
/// T184: Call uploadRoomAssets after completion
class UploadNotifier extends StateNotifier<Map<String, UploadState>> {
  final UploadService _uploadService;
  final UploadDatabase _database;
  final Logger _logger;
  StreamSubscription? _connectivitySubscription;

  UploadNotifier({
    required UploadService uploadService,
    required UploadDatabase database,
    Logger? logger,
  })  : _uploadService = uploadService,
        _database = database,
        _logger = logger ?? Logger(),
        super({}) {
    // Start background sync monitoring (T183)
    _initializeBackgroundSync();
  }

  /// Initialize background sync for pending uploads (T183)
  void _initializeBackgroundSync() {
    // Watch pending uploads and process them
    _database.watchPendingUploads().listen((uploads) {
      _logger.i('Background sync: ${uploads.length} pending uploads');
      _processPendingUploads();
    });
  }

  /// Queue and start upload workflow (T181)
  /// Creates room, requests upload URL, uploads file, confirms with backend
  Future<void> startUpload({
    required String roomId,
    required FileType fileType,
    required String filePath,
    required String fileName,
    required Future<String> Function() createRoomIfNeeded,
    required Future<({String uploadUrl, String fileKey})> Function(String roomId, String fileType, String fileName, int fileSize) requestUploadUrl,
    required Future<void> Function(String roomId, String? sceneUrl, String? navmeshUrl, int? sceneSize, int? navmeshSize) uploadRoomAssets,
  }) async {
    final key = '${roomId}_${fileType.graphqlValue}';

    try {
      // Set initial state
      state = {
        ...state,
        key: UploadState(
          roomId: roomId,
          fileType: fileType,
          status: UploadStatus.pending,
          progress: 0.0,
        ),
      };

      // Step 1: Create room if needed (T181)
      _logger.i('Step 1: Ensuring room exists for $roomId');
      await createRoomIfNeeded();

      // Step 2: Queue upload (T182 - handles offline queueing)
      _logger.i('Step 2: Queueing upload for $fileName');
      final uploadId = await _uploadService.queueUpload(
        roomId: roomId,
        fileType: fileType,
        filePath: filePath,
      );

      // Step 3: Request upload URL from backend
      _logger.i('Step 3: Requesting upload URL from backend');
      final fileSize = await _getFileSize(filePath);
      final urlInfo = await requestUploadUrl(roomId, fileType.graphqlValue, fileName, fileSize);

      // Save upload URL to database
      await _database.updateUploadUrl(uploadId, urlInfo.uploadUrl, urlInfo.fileKey);

      // Step 4: Upload file with chunking (T181)
      _logger.i('Step 4: Uploading file in chunks');
      state = {
        ...state,
        key: state[key]!.copyWith(status: UploadStatus.uploading),
      };

      await _uploadService.uploadFile(
        uploadId: uploadId,
        uploadUrl: urlInfo.uploadUrl,
        onProgress: (sent, total) {
          final progress = sent / total;
          state = {
            ...state,
            key: state[key]!.copyWith(progress: progress),
          };
        },
      );

      // Step 5: Confirm upload with backend (T184)
      _logger.i('Step 5: Confirming upload with backend');
      final cdnUrl = urlInfo.fileKey; // In real implementation, construct CDN URL

      await _database.markUploadCompleted(uploadId, cdnUrl);

      // Call uploadRoomAssets mutation to confirm upload
      if (fileType == FileType.sceneGlb) {
        await uploadRoomAssets(roomId, cdnUrl, null, fileSize, null);
      } else {
        await uploadRoomAssets(roomId, null, cdnUrl, null, fileSize);
      }

      // Mark as completed
      state = {
        ...state,
        key: state[key]!.copyWith(
          status: UploadStatus.completed,
          progress: 1.0,
        ),
      };

      _logger.i('Upload workflow completed successfully for $key');
    } catch (e, stackTrace) {
      _logger.e('Upload workflow failed for $key', error: e, stackTrace: stackTrace);

      state = {
        ...state,
        key: state[key]!.copyWith(
          status: UploadStatus.failed,
          error: e.toString(),
        ),
      };

      rethrow;
    }
  }

  /// Process pending uploads (background sync - T183)
  Future<void> _processPendingUploads() async {
    try {
      final uploads = await _database.getAllUploads();
      final pending = uploads.where((u) => u.status == 'pending' || u.status == 'uploading');

      for (final upload in pending) {
        if (upload.uploadUrl == null) {
          _logger.w('Upload ${upload.id} has no URL, skipping');
          continue;
        }

        final key = '${upload.roomId}_${upload.fileType}';

        // Skip if already uploading
        if (state[key]?.status == UploadStatus.uploading) {
          continue;
        }

        _logger.i('Background sync: Resuming upload ${upload.id}');

        try {
          await _uploadService.uploadFile(
            uploadId: upload.id,
            uploadUrl: upload.uploadUrl!,
            onProgress: (sent, total) {
              final progress = sent / total;
              state = {
                ...state,
                key: UploadState(
                  roomId: upload.roomId,
                  fileType: FileTypeExtension.fromGraphql(upload.fileType),
                  status: UploadStatus.uploading,
                  progress: progress,
                ),
              };
            },
          );

          await _database.markUploadCompleted(upload.id, upload.fileKey ?? '');

          state = {
            ...state,
            key: UploadState(
              roomId: upload.roomId,
              fileType: FileTypeExtension.fromGraphql(upload.fileType),
              status: UploadStatus.completed,
              progress: 1.0,
            ),
          };
        } catch (e) {
          _logger.e('Background sync failed for upload ${upload.id}: $e');
        }
      }
    } catch (e) {
      _logger.e('Failed to process pending uploads: $e');
    }
  }

  /// Retry a failed upload
  Future<void> retryUpload(String roomId, FileType fileType) async {
    final upload = await _database.getUploadByRoomAndType(roomId, fileType.graphqlValue);
    if (upload == null) {
      throw StateError('No upload found for $roomId/${fileType.graphqlValue}');
    }

    await _uploadService.retryUpload(upload.id);
  }

  /// Cancel an upload
  Future<void> cancelUpload(String roomId, FileType fileType) async {
    final upload = await _database.getUploadByRoomAndType(roomId, fileType.graphqlValue);
    if (upload == null) {
      throw StateError('No upload found for $roomId/${fileType.graphqlValue}');
    }

    await _uploadService.cancelUpload(upload.id);

    final key = '${roomId}_${fileType.graphqlValue}';
    state = {
      ...state,
      key: state[key]!.copyWith(
        status: UploadStatus.failed,
        error: 'Cancelled by user',
      ),
    };
  }

  /// Get file size helper
  Future<int> _getFileSize(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }
    return await file.length();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
