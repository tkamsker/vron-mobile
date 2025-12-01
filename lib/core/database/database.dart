import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// Projects table - Real estate properties
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get slug => text()();
  TextColumn get name => text().withLength(min: 1, max: 500)();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get isLive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get liveDate => dateTime().nullable()();

  // Subscription fields (flattened for simplicity)
  TextColumn get subscriptionStatus => text().nullable()();
  BoolColumn get subscriptionIsTrial => boolean().withDefault(const Constant(false))();
  BoolColumn get subscriptionIsActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get subscriptionStartedAt => dateTime().nullable()();
  DateTimeColumn get subscriptionExpiresAt => dateTime().nullable()();
  DateTimeColumn get subscriptionRenewsAt => dateTime().nullable()();

  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Rooms table - Scanned physical spaces within projects
class Rooms extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get sessionId => text().nullable().references(ScanSessions, #id, onDelete: KeyAction.setNull)();
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

/// Scan sessions table - Groups multiple room scans together
class ScanSessions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()(); // e.g., "Morning Session", "Floor 1 Scan"
  TextColumn get projectId => text().nullable().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get projectName => text().nullable()(); // Cached project name for display
  TextColumn get thumbnailPath => text().nullable()(); // Path to thumbnail image for preview
  BoolColumn get isGuestMode => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Guest scans table - Scans made in guest mode (not uploaded)
class GuestScans extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get sessionId => text().nullable().references(ScanSessions, #id, onDelete: KeyAction.cascade)();
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
  ScanSessions,
  GuestScans,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from == 1 && to == 2) {
          // Add ScanSessions table
          await m.createTable(scanSessions);

          // Add sessionId column to Rooms table
          await m.addColumn(rooms, rooms.sessionId);

          // Add sessionId column to GuestScans table
          await m.addColumn(guestScans, guestScans.sessionId);
        }
        if (from == 2 && to == 3) {
          // Add thumbnailPath column to ScanSessions table
          await m.addColumn(scanSessions, scanSessions.thumbnailPath);
        }
        // Handle migrations from version 1 to 3
        if (from == 1 && to == 3) {
          await m.createTable(scanSessions);
          await m.addColumn(rooms, rooms.sessionId);
          await m.addColumn(guestScans, guestScans.sessionId);
          // thumbnailPath will be included in createTable since it's part of the schema
        }
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

  // Scan session queries
  Stream<List<ScanSession>> watchAllSessions() =>
      (select(scanSessions)..orderBy([(s) => OrderingTerm.desc(s.createdAt)])).watch();

  // Watch only sessions that have scans (not empty)
  Stream<List<ScanSession>> watchSessionsWithScans() {
    return customSelect(
      '''
      SELECT DISTINCT s.* FROM scan_sessions s
      LEFT JOIN rooms r ON s.id = r.session_id
      LEFT JOIN guest_scans g ON s.id = g.session_id
      WHERE r.id IS NOT NULL OR g.id IS NOT NULL
      ORDER BY s.created_at DESC
      ''',
      readsFrom: {scanSessions, rooms, guestScans},
    ).watch().map((rows) {
      return rows.map((row) => ScanSession(
        id: row.read<String>('id'),
        name: row.read<String>('name'),
        projectId: row.readNullable<String>('project_id'),
        projectName: row.readNullable<String>('project_name'),
        thumbnailPath: row.readNullable<String>('thumbnail_path'),
        isGuestMode: row.read<bool>('is_guest_mode'),
        createdAt: row.read<DateTime>('created_at'),
        updatedAt: row.read<DateTime>('updated_at'),
      )).toList();
    });
  }

  Stream<List<ScanSession>> watchSessionsByProject(String projectId) =>
      (select(scanSessions)
            ..where((s) => s.projectId.equals(projectId))
            ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
          .watch();

  Future<ScanSession?> getSession(String sessionId) =>
      (select(scanSessions)..where((s) => s.id.equals(sessionId))).getSingleOrNull();

  Future<void> upsertSession(ScanSessionsCompanion session) =>
      into(scanSessions).insertOnConflictUpdate(session);

  Future<void> deleteSession(String sessionId) =>
      (delete(scanSessions)..where((s) => s.id.equals(sessionId))).go();

  // Get scans by session
  Stream<List<Room>> watchRoomsBySession(String sessionId) =>
      (select(rooms)..where((r) => r.sessionId.equals(sessionId))).watch();

  Stream<List<GuestScan>> watchGuestScansBySession(String sessionId) =>
      (select(guestScans)..where((g) => g.sessionId.equals(sessionId))).watch();

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
