import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database.dart';

/// Database provider with lazy initialization
///
/// Provides singleton instance of AppDatabase for the entire app.
/// The database is initialized once and reused across all queries.
///
/// Usage:
/// ```dart
/// final db = ref.read(databaseProvider);
/// final projects = await db.getAllProjects();
/// ```
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();

  // Ensure database is closed when provider is disposed
  ref.onDispose(() {
    database.close();
  });

  return database;
});

/// Stream provider for watching all projects
///
/// Automatically updates UI when projects change in database.
final allProjectsProvider = StreamProvider<List<Project>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllProjects();
});

/// Stream provider for watching a specific project
///
/// Usage:
/// ```dart
/// final project = ref.watch(projectProvider('project-id'));
/// ```
final projectProvider = StreamProvider.family<Project?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.watchProject(id);
});

/// Stream provider for watching rooms by project
///
/// Usage:
/// ```dart
/// final rooms = ref.watch(projectRoomsProvider('project-id'));
/// ```
final projectRoomsProvider = StreamProvider.family<List<Room>, String>((ref, projectId) {
  final db = ref.watch(databaseProvider);
  return db.watchRoomsByProject(projectId);
});

/// Stream provider for watching pending uploads
///
/// Automatically updates UI when upload queue changes.
final pendingUploadsProvider = StreamProvider<List<UploadQueueData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchPendingUploads();
});

/// Database operations helper
///
/// Provides convenient methods for common database operations.
/// Use this for non-query operations like insert, update, delete.
class DatabaseOperations {
  final AppDatabase _db;

  DatabaseOperations(this._db);

  // Project operations
  Future<void> upsertProject(ProjectsCompanion project) =>
      _db.upsertProject(project);

  Future<void> deleteProject(String id) => _db.deleteProject(id);

  Future<List<Project>> getAllProjects() => _db.getAllProjects();

  // Room operations
  Future<void> upsertRoom(RoomsCompanion room) => _db.upsertRoom(room);

  // Upload queue operations
  Future<void> addToUploadQueue(UploadQueueCompanion upload) =>
      _db.addToUploadQueue(upload);

  Future<void> updateUploadStatus(
    String id,
    String status, {
    int? uploadedBytes,
    DateTime? lastAttemptAt,
    int? retryCount,
  }) =>
      _db.updateUploadStatus(
        id,
        status,
        uploadedBytes: uploadedBytes,
        lastAttemptAt: lastAttemptAt,
        retryCount: retryCount,
      );

  // Cache operations
  Future<void> clearExpiredCache() => _db.clearExpiredCache();

  Future<void> clearAllCache() => _db.clearAllCache();
}

/// Database operations provider
final databaseOperationsProvider = Provider<DatabaseOperations>((ref) {
  final db = ref.watch(databaseProvider);
  return DatabaseOperations(db);
});
