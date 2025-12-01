import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database.dart';
import '../models/scan_data.dart';

/// Repository for managing room scans
///
/// Handles storage and retrieval of scans in both
/// authenticated mode (Rooms table) and guest mode (GuestScans table)
class ScanRepository {
  final AppDatabase _database;
  final _uuid = const Uuid();

  ScanRepository(this._database);

  /// Save a completed scan
  ///
  /// Saves to Rooms table if authenticated, GuestScans table if guest mode
  Future<void> saveScan(ScanData scanData, String roomName) async {
    if (scanData.isGuestMode) {
      await _saveGuestScan(scanData, roomName);
    } else {
      await _saveAuthenticatedScan(scanData, roomName);
    }
  }

  /// Save scan in authenticated mode
  Future<void> _saveAuthenticatedScan(ScanData scanData, String roomName) async {
    if (scanData.projectId == null) {
      throw ArgumentError('ProjectId is required for authenticated scans');
    }

    final room = RoomsCompanion(
      id: Value(scanData.id),
      projectId: Value(scanData.projectId!),
      name: Value(roomName),
      scanDate: Value(scanData.completedAt ?? DateTime.now()),
      sceneGlbPath: Value(scanData.sceneGlbPath),
      navmeshGlbPath: Value(scanData.navmeshGlbPath),
      sceneFileSize: Value(scanData.sceneFileSize),
      navmeshFileSize: Value(scanData.navmeshFileSize),
      processingStatus: const Value('completed'),
      createdAt: Value(scanData.startedAt),
      updatedAt: Value(DateTime.now()),
    );

    await _database.upsertRoom(room);
  }

  /// Save scan in guest mode
  Future<void> _saveGuestScan(ScanData scanData, String roomName) async {
    final guestScan = GuestScansCompanion(
      id: Value(scanData.id),
      name: Value(roomName),
      scanDate: Value(scanData.completedAt ?? DateTime.now()),
      sceneGlbPath: Value(scanData.sceneGlbPath ?? ''),
      navmeshGlbPath: Value(scanData.navmeshGlbPath),
      sceneFileSize: Value(scanData.sceneFileSize ?? 0),
      createdAt: Value(scanData.startedAt),
    );

    await _database.into(_database.guestScans).insert(
          guestScan,
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Get all rooms for a project
  Stream<List<Room>> watchRoomsByProject(String projectId) {
    return _database.watchRoomsByProject(projectId);
  }

  /// Get all guest scans
  Stream<List<GuestScan>> watchGuestScans() {
    return _database.select(_database.guestScans).watch();
  }

  /// Get a specific room by ID
  Future<Room?> getRoom(String roomId) async {
    return await (_database.select(_database.rooms)
          ..where((r) => r.id.equals(roomId)))
        .getSingleOrNull();
  }

  /// Get a specific guest scan by ID
  Future<GuestScan?> getGuestScan(String scanId) async {
    return await (_database.select(_database.guestScans)
          ..where((s) => s.id.equals(scanId)))
        .getSingleOrNull();
  }

  /// Delete a room scan
  Future<void> deleteRoom(String roomId) async {
    await (_database.delete(_database.rooms)..where((r) => r.id.equals(roomId)))
        .go();
  }

  /// Delete a guest scan
  Future<void> deleteGuestScan(String scanId) async {
    await (_database.delete(_database.guestScans)
          ..where((s) => s.id.equals(scanId)))
        .go();
  }

  /// Generate a new scan ID
  String generateScanId() {
    return _uuid.v4();
  }

  /// Convert Room to ScanData
  ScanData roomToScanData(Room room) {
    return ScanData(
      id: room.id,
      roomName: room.name,
      projectId: room.projectId,
      startedAt: room.createdAt,
      completedAt: room.scanDate,
      sceneGlbPath: room.sceneGlbPath,
      navmeshGlbPath: room.navmeshGlbPath,
      sceneFileSize: room.sceneFileSize,
      navmeshFileSize: room.navmeshFileSize,
      isGuestMode: false,
      status: _getStatusFromProcessing(room.processingStatus),
    );
  }

  /// Convert GuestScan to ScanData
  ScanData guestScanToScanData(GuestScan scan) {
    return ScanData(
      id: scan.id,
      roomName: scan.name,
      startedAt: scan.createdAt,
      completedAt: scan.scanDate,
      sceneGlbPath: scan.sceneGlbPath,
      navmeshGlbPath: scan.navmeshGlbPath,
      sceneFileSize: scan.sceneFileSize,
      isGuestMode: true,
      status: ScanStatus.completed,
    );
  }

  /// Get scan status from processing status string
  ScanStatus _getStatusFromProcessing(String processingStatus) {
    switch (processingStatus) {
      case 'pending':
        return ScanStatus.ready;
      case 'processing':
        return ScanStatus.processing;
      case 'completed':
        return ScanStatus.completed;
      case 'failed':
        return ScanStatus.failed;
      default:
        return ScanStatus.ready;
    }
  }

  /// Count total scans (authenticated + guest)
  Future<int> getTotalScanCount() async {
    final roomCount = await _database.select(_database.rooms).get();
    final guestCount = await _database.select(_database.guestScans).get();
    return roomCount.length + guestCount.length;
  }

  /// Get recent scans (mixed authenticated + guest)
  Future<List<ScanData>> getRecentScans({int limit = 10}) async {
    final rooms = await _database.select(_database.rooms).get();
    final guestScans = await _database.select(_database.guestScans).get();

    final allScans = <ScanData>[
      ...rooms.map((r) => roomToScanData(r)),
      ...guestScans.map((s) => guestScanToScanData(s)),
    ];

    // Sort by creation date descending
    allScans.sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return allScans.take(limit).toList();
  }
}
