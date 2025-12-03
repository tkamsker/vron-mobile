// T175-T179: Upload service with resumable chunks
// Handles chunked uploads with Content-Range headers, progress persistence,
// connectivity restoration, and exponential backoff retry

import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:logger/logger.dart';
import '../database/upload_database.dart';
import '../database/tables.dart';

/// Chunk size for resumable uploads (5MB)
const int kChunkSize = 5 * 1024 * 1024;

/// Maximum retry attempts
const int kMaxRetries = 3;

/// Initial retry delay in milliseconds
const int kInitialRetryDelay = 1000;

/// Upload service for resumable GLB file uploads
/// Supports chunked uploads, progress persistence, and automatic retry
class UploadService {
  final UploadDatabase _database;
  final Dio _dio;
  final Logger _logger;

  UploadService({
    required UploadDatabase database,
    Dio? dio,
    Logger? logger,
  })  : _database = database,
        _dio = dio ?? Dio(),
        _logger = logger ?? Logger();

  /// Queue a file for upload
  /// Creates entry in upload queue and returns upload ID
  Future<int> queueUpload({
    required String roomId,
    required FileType fileType,
    required String filePath,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final fileSize = await file.length();

    final uploadId = await _database.insertUpload(
      UploadQueueCompanion(
        roomId: drift.Value(roomId),
        fileType: drift.Value(fileType.graphqlValue),
        filePath: drift.Value(filePath),
        fileSize: drift.Value(fileSize),
        uploadedBytes: const drift.Value(0),
        status: const drift.Value('pending'),
        retryCount: const drift.Value(0),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );

    _logger.i('Queued upload $uploadId for room $roomId (${fileType.graphqlValue})');
    return uploadId;
  }

  /// Upload a file with resumable chunks
  /// Supports resuming from last uploaded byte
  /// T175: Resumable chunks (5MB)
  /// T176: Content-Range headers
  /// T177: Save progress to Drift
  /// T178: Restore upload offset
  /// T179: Exponential backoff retry
  Future<void> uploadFile({
    required int uploadId,
    required String uploadUrl,
    void Function(int sent, int total)? onProgress,
  }) async {
    final upload = await _database.getUpload(uploadId);
    if (upload == null) {
      throw StateError('Upload $uploadId not found');
    }

    final file = File(upload.filePath);
    if (!await file.exists()) {
      await _database.markUploadFailed(uploadId, 'File not found: ${upload.filePath}');
      throw FileSystemException('File not found', upload.filePath);
    }

    final fileSize = upload.fileSize;
    int uploadedBytes = upload.uploadedBytes;
    int retryCount = upload.retryCount;

    _logger.i('Starting upload $uploadId (${upload.fileType}): $fileSize bytes, resuming from $uploadedBytes');

    // Upload file in chunks
    while (uploadedBytes < fileSize) {
      try {
        final chunkStart = uploadedBytes;
        final chunkEnd = (uploadedBytes + kChunkSize < fileSize) ? uploadedBytes + kChunkSize : fileSize;
        final chunkSize = chunkEnd - chunkStart;

        _logger.d('Uploading chunk: $chunkStart-${chunkEnd - 1}/$fileSize');

        // Read chunk from file
        final chunk = await _readFileChunk(file, chunkStart, chunkSize);

        // Upload chunk with Content-Range header (T176)
        await _uploadChunk(
          uploadUrl: uploadUrl,
          chunk: chunk,
          start: chunkStart,
          end: chunkEnd - 1,
          total: fileSize,
        );

        uploadedBytes = chunkEnd;

        // Save progress to Drift (T177)
        await _database.updateUploadProgress(uploadId, uploadedBytes);

        // Call progress callback
        onProgress?.call(uploadedBytes, fileSize);

        _logger.d('Chunk uploaded: $uploadedBytes/$fileSize (${(uploadedBytes / fileSize * 100).toStringAsFixed(1)}%)');

        // Reset retry count on successful chunk
        retryCount = 0;
      } catch (e) {
        _logger.e('Upload chunk failed: $e');

        // Implement exponential backoff retry (T179)
        if (retryCount < kMaxRetries) {
          retryCount++;
          final delay = kInitialRetryDelay * (1 << (retryCount - 1)); // 1s, 2s, 4s

          _logger.w('Retrying upload in ${delay}ms (attempt $retryCount/$kMaxRetries)');
          await Future.delayed(Duration(milliseconds: delay));

          // Update retry info in database
          await _database.markUploadFailed(uploadId, 'Retry attempt $retryCount: $e');

          // Continue to retry
          continue;
        } else {
          // Max retries exceeded
          _logger.e('Upload failed after $kMaxRetries retries');
          await _database.markUploadFailed(uploadId, 'Failed after $kMaxRetries retries: $e');
          rethrow;
        }
      }
    }

    _logger.i('Upload $uploadId completed successfully');
  }

  /// Resume all pending uploads
  /// Called on connectivity restoration (T178)
  Future<void> resumePendingUploads(String roomId) async {
    final pendingUploads = await _database.getPendingUploads(roomId);

    for (final upload in pendingUploads) {
      if (upload.uploadUrl == null) {
        _logger.w('Upload ${upload.id} has no upload URL, skipping');
        continue;
      }

      try {
        _logger.i('Resuming upload ${upload.id} from ${upload.uploadedBytes} bytes');
        await uploadFile(uploadId: upload.id, uploadUrl: upload.uploadUrl!);
      } catch (e) {
        _logger.e('Failed to resume upload ${upload.id}: $e');
      }
    }
  }

  /// Read a chunk from file
  Future<Uint8List> _readFileChunk(File file, int start, int length) async {
    final randomAccessFile = await file.open(mode: FileMode.read);
    try {
      await randomAccessFile.setPosition(start);
      return await randomAccessFile.read(length);
    } finally {
      await randomAccessFile.close();
    }
  }

  /// Upload a single chunk with Content-Range header
  /// T176: Content-Range header support
  Future<void> _uploadChunk({
    required String uploadUrl,
    required Uint8List chunk,
    required int start,
    required int end,
    required int total,
  }) async {
    final contentRange = 'bytes $start-$end/$total';

    _logger.d('PUT $uploadUrl with Content-Range: $contentRange');

    final response = await _dio.put(
      uploadUrl,
      data: Stream.fromIterable([chunk]),
      options: Options(
        headers: {
          'Content-Range': contentRange,
          'Content-Type': 'application/octet-stream',
          'Content-Length': chunk.length,
        },
        validateStatus: (status) {
          // Accept 200 (OK), 201 (Created), and 308 (Resume Incomplete)
          return status != null && (status == 200 || status == 201 || status == 308);
        },
      ),
    );

    if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 308) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Unexpected status code: ${response.statusCode}',
        type: DioExceptionType.badResponse,
      );
    }

    _logger.d('Chunk upload response: ${response.statusCode}');
  }

  /// Cancel an upload
  Future<void> cancelUpload(int uploadId) async {
    final upload = await _database.getUpload(uploadId);
    if (upload == null) {
      throw StateError('Upload $uploadId not found');
    }

    await _database.markUploadFailed(uploadId, 'Cancelled by user');
    _logger.i('Upload $uploadId cancelled');
  }

  /// Retry a failed upload
  Future<void> retryUpload(int uploadId) async {
    final upload = await _database.getUpload(uploadId);
    if (upload == null) {
      throw StateError('Upload $uploadId not found');
    }

    if (upload.uploadUrl == null) {
      throw StateError('Upload $uploadId has no upload URL');
    }

    await _database.resetUploadForRetry(uploadId);
    _logger.i('Retrying upload $uploadId');

    await uploadFile(uploadId: uploadId, uploadUrl: upload.uploadUrl!);
  }

  /// Delete completed uploads older than specified duration
  Future<int> cleanupOldUploads({Duration age = const Duration(days: 7)}) async {
    final cutoff = DateTime.now().subtract(age);
    final deleted = await _database.deleteOldCompletedUploads(cutoff);
    _logger.i('Cleaned up $deleted old uploads');
    return deleted;
  }
}
