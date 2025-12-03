// T174: UploadQueue Drift entity for persistent upload tracking
// Tracks upload progress for resumable uploads across app restarts and network changes

import 'package:drift/drift.dart';

/// Upload queue table for tracking GLB file uploads
/// Supports resumable uploads with progress persistence
@DataClassName('UploadQueueEntry')
class UploadQueue extends Table {
  /// Primary key
  IntColumn get id => integer().autoIncrement()();

  /// Room ID this upload belongs to
  TextColumn get roomId => text()();

  /// File type: 'SCENE_GLB' or 'NAVMESH_GLB'
  TextColumn get fileType => text()();

  /// Local file path on device
  TextColumn get filePath => text()();

  /// Total file size in bytes
  IntColumn get fileSize => integer()();

  /// Number of bytes uploaded so far
  IntColumn get uploadedBytes => integer().withDefault(const Constant(0))();

  /// Presigned S3 upload URL (valid for 1 hour)
  TextColumn get uploadUrl => text().nullable()();

  /// S3 file key for the uploaded file
  TextColumn get fileKey => text().nullable()();

  /// CDN URL after successful upload
  TextColumn get cdnUrl => text().nullable()();

  /// Upload status: 'pending', 'uploading', 'completed', 'failed'
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Number of retry attempts
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Timestamp of last retry attempt
  DateTimeColumn get lastRetryAt => dateTime().nullable()();

  /// Error message if upload failed
  TextColumn get errorMessage => text().nullable()();

  /// When this entry was created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// When this entry was last updated
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Upload status enum
enum UploadStatus {
  pending,
  uploading,
  completed,
  failed,
}

/// File type enum matching GraphQL schema
enum FileType {
  sceneGlb,
  navmeshGlb,
}

extension FileTypeExtension on FileType {
  String get graphqlValue {
    switch (this) {
      case FileType.sceneGlb:
        return 'SCENE_GLB';
      case FileType.navmeshGlb:
        return 'NAVMESH_GLB';
    }
  }

  static FileType fromGraphql(String value) {
    switch (value) {
      case 'SCENE_GLB':
        return FileType.sceneGlb;
      case 'NAVMESH_GLB':
        return FileType.navmeshGlb;
      default:
        throw ArgumentError('Invalid file type: $value');
    }
  }
}
