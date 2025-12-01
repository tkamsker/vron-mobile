import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import 'scan_repository.dart';

/// Scan repository provider
///
/// Provides singleton instance of ScanRepository for managing room scans.
final scanRepositoryProvider = Provider<ScanRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return ScanRepository(database);
});

/// Stream provider for watching rooms by project
///
/// Usage:
/// ```dart
/// final rooms = ref.watch(scanRoomsProvider('project-id'));
/// ```
final scanRoomsProvider = StreamProvider.family<List<Room>, String>((ref, projectId) {
  final repository = ref.watch(scanRepositoryProvider);
  return repository.watchRoomsByProject(projectId);
});

/// Stream provider for watching guest scans
///
/// Automatically updates UI when guest scans change in database.
final guestScansProvider = StreamProvider<List<GuestScan>>((ref) {
  final repository = ref.watch(scanRepositoryProvider);
  return repository.watchGuestScans();
});

/// Future provider for getting recent scans
///
/// Returns mixed list of authenticated and guest scans.
final recentScansProvider = FutureProvider.family<List<dynamic>, int>((ref, limit) async {
  final repository = ref.watch(scanRepositoryProvider);
  return await repository.getRecentScans(limit: limit);
});
