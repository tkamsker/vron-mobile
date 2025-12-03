// T174: Upload database for persistent upload queue management
// Provides Drift database with UploadQueue table

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'upload_database.g.dart';

/// Database for managing upload queue
/// Provides persistent storage for resumable uploads
@DriftDatabase(tables: [UploadQueue])
class UploadDatabase extends _$UploadDatabase {
  UploadDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future schema migrations here
      },
    );
  }

  // ============================================================================
  // Query Methods
  // ============================================================================

  /// Get all pending uploads for a room
  Future<List<UploadQueueEntry>> getPendingUploads(String roomId) {
    return (select(uploadQueue)
          ..where((t) => t.roomId.equals(roomId))
          ..where((t) => t.status.equals('pending') | t.status.equals('uploading'))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  /// Get all uploads (for debugging/UI)
  Future<List<UploadQueueEntry>> getAllUploads() {
    return (select(uploadQueue)..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])).get();
  }

  /// Get upload by ID
  Future<UploadQueueEntry?> getUpload(int id) {
    return (select(uploadQueue)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get upload by room ID and file type
  Future<UploadQueueEntry?> getUploadByRoomAndType(String roomId, String fileType) {
    return (select(uploadQueue)
          ..where((t) => t.roomId.equals(roomId))
          ..where((t) => t.fileType.equals(fileType)))
        .getSingleOrNull();
  }

  /// Watch pending uploads (for UI)
  Stream<List<UploadQueueEntry>> watchPendingUploads() {
    return (select(uploadQueue)
          ..where((t) => t.status.equals('pending') | t.status.equals('uploading'))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  // ============================================================================
  // Mutation Methods
  // ============================================================================

  /// Insert a new upload into the queue
  Future<int> insertUpload(UploadQueueCompanion entry) {
    return into(uploadQueue).insert(entry);
  }

  /// Update upload progress
  Future<void> updateUploadProgress(int id, int uploadedBytes) {
    return (update(uploadQueue)..where((t) => t.id.equals(id))).write(
      UploadQueueCompanion(
        uploadedBytes: Value(uploadedBytes),
        status: const Value('uploading'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update upload URL and file key
  Future<void> updateUploadUrl(int id, String uploadUrl, String fileKey) {
    return (update(uploadQueue)..where((t) => t.id.equals(id))).write(
      UploadQueueCompanion(
        uploadUrl: Value(uploadUrl),
        fileKey: Value(fileKey),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark upload as completed
  Future<void> markUploadCompleted(int id, String cdnUrl) async {
    final upload = await (select(uploadQueue)..where((t) => t.id.equals(id))).getSingle();
    await (update(uploadQueue)..where((t) => t.id.equals(id))).write(
      UploadQueueCompanion(
        status: const Value('completed'),
        cdnUrl: Value(cdnUrl),
        uploadedBytes: Value(upload.fileSize),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark upload as failed
  Future<void> markUploadFailed(int id, String errorMessage) async {
    final upload = await (select(uploadQueue)..where((t) => t.id.equals(id))).getSingle();
    await (update(uploadQueue)..where((t) => t.id.equals(id))).write(
      UploadQueueCompanion(
        status: const Value('failed'),
        errorMessage: Value(errorMessage),
        retryCount: Value(upload.retryCount + 1),
        lastRetryAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Reset upload for retry
  Future<void> resetUploadForRetry(int id) {
    return (update(uploadQueue)..where((t) => t.id.equals(id))).write(
      UploadQueueCompanion(
        status: const Value('pending'),
        errorMessage: const Value(null),
        lastRetryAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete completed uploads older than a certain date
  Future<int> deleteOldCompletedUploads(DateTime before) {
    return (delete(uploadQueue)
          ..where((t) => t.status.equals('completed'))
          ..where((t) => t.updatedAt.isSmallerThanValue(before)))
        .go();
  }

  /// Delete upload
  Future<int> deleteUpload(int id) {
    return (delete(uploadQueue)..where((t) => t.id.equals(id))).go();
  }
}

/// Opens the database connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'vron_uploads.sqlite'));
    return NativeDatabase(file);
  });
}
