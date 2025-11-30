import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// Projects table - Real estate properties
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('active'))();
  TextColumn get thumbnailUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Rooms table - Scanned physical spaces within projects
class Rooms extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  DateTimeColumn get scanDate => dateTime()();
  TextColumn get sceneGlbPath => text().nullable()();
  TextColumn get navmeshGlbPath => text().nullable()();
  IntColumn get sceneFileSize => integer().nullable()();
  IntColumn get navmeshFileSize => integer().nullable()();
  TextColumn get processingStatus => text()
      .withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {projectId, name}, // Unique room names per project
      ];
}

/// Upload queue table - Pending uploads for offline sync
class UploadQueue extends Table {
  TextColumn get id => text()();
  TextColumn get roomId => text().references(Rooms, #id, onDelete: KeyAction.cascade)();
  TextColumn get sceneGlbPath => text().nullable()();
  TextColumn get navmeshGlbPath => text().nullable()();
  IntColumn get uploadedBytes => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer()();
  TextColumn get uploadStatus => text()
      .withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// User cache table - Cached user profile data
class UserCache extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get accessToken => text()();
  TextColumn get activeRoles => text()(); // JSON string
  DateTimeColumn get cachedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// GraphQL cache metadata table - Track cache TTL
class GraphQLCacheMeta extends Table {
  TextColumn get queryKey => text()();
  TextColumn get queryHash => text()();
  DateTimeColumn get cachedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  IntColumn get sizeBytes => integer().nullable()();

  @override
  Set<Column> get primaryKey => {queryKey};
}

/// Demo assets cache table - Cached sailing/aviation demo content
class DemoAssetsCache extends Table {
  TextColumn get id => text()();
  TextColumn get theme => text()();
  TextColumn get name => text()();
  TextColumn get glbUrl => text()();
  TextColumn get previewThumbnailUrl => text()();
  TextColumn get description => text().nullable()();
  TextColumn get metadata => text().nullable()(); // JSON string
  IntColumn get displayOrder => integer()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Guest scans table - Scans made in guest mode (not uploaded)
class GuestScans extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get scanDate => dateTime()();
  TextColumn get sceneGlbPath => text()();
  TextColumn get navmeshGlbPath => text().nullable()();
  IntColumn get sceneFileSize => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Main database class
@DriftDatabase(tables: [
  Projects,
  Rooms,
  UploadQueue,
  UserCache,
  GraphQLCacheMeta,
  DemoAssetsCache,
  GuestScans,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration logic will be added here in future versions
      },
    );
  }

  // Project queries
  Stream<List<Project>> watchAllProjects() =>
      select(projects).watch();

  Stream<Project?> watchProject(String id) =>
      (select(projects)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<List<Project>> getAllProjects() =>
      select(projects).get();

  Future<void> upsertProject(ProjectsCompanion project) =>
      into(projects).insertOnConflictUpdate(project);

  Future<void> deleteProject(String id) =>
      (delete(projects)..where((p) => p.id.equals(id))).go();

  // Room queries
  Stream<List<Room>> watchRoomsByProject(String projectId) =>
      (select(rooms)..where((r) => r.projectId.equals(projectId))).watch();

  Future<void> upsertRoom(RoomsCompanion room) =>
      into(rooms).insertOnConflictUpdate(room);

  // Upload queue queries
  Stream<List<UploadQueueData>> watchPendingUploads() => (select(uploadQueue)
        ..where((u) => u.uploadStatus.isIn(['pending', 'in_progress']))
        ..orderBy([(u) => OrderingTerm.asc(u.createdAt)]))
      .watch();

  Future<void> addToUploadQueue(UploadQueueCompanion upload) =>
      into(uploadQueue).insert(upload);

  Future<void> updateUploadStatus(
    String id,
    String status, {
    int? uploadedBytes,
    DateTime? lastAttemptAt,
    int? retryCount,
  }) {
    return (update(uploadQueue)..where((u) => u.id.equals(id))).write(
      UploadQueueCompanion(
        uploadStatus: Value(status),
        uploadedBytes: uploadedBytes != null ? Value(uploadedBytes) : const Value.absent(),
        lastAttemptAt: lastAttemptAt != null ? Value(lastAttemptAt) : const Value.absent(),
        retryCount: retryCount != null ? Value(retryCount) : const Value.absent(),
      ),
    );
  }

  // Cache cleanup
  Future<void> clearExpiredCache() async {
    final now = DateTime.now();
    await (delete(graphQLCacheMeta)..where((c) => c.expiresAt.isSmallerThanValue(now))).go();
    await (delete(userCache)..where((c) => c.expiresAt.isSmallerThanValue(now))).go();
  }

  Future<void> clearAllCache() async {
    await delete(graphQLCacheMeta).go();
    await delete(userCache).go();
    await delete(demoAssetsCache).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'vron_mobile.db'));
    return NativeDatabase(file);
  });
}
