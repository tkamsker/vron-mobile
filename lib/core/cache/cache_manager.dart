import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../database/database_provider.dart';

/// Cache entry with TTL metadata
class CacheEntry {
  final dynamic data;
  final DateTime cachedAt;
  final DateTime expiresAt;

  CacheEntry({
    required this.data,
    required this.cachedAt,
    required this.expiresAt,
  });

  /// Check if cache entry is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Time until expiration
  Duration get timeUntilExpiration => expiresAt.difference(DateTime.now());

  /// Time since cached
  Duration get age => DateTime.now().difference(cachedAt);
}

/// Cache manager for Hive-based local caching
///
/// Manages multiple cache boxes with TTL and size limits:
/// - GraphQL query cache (24-hour TTL)
/// - User profile cache (24-hour TTL)
/// - Demo assets cache (7-day TTL)
///
/// Per Constitution Principle II (Offline-First):
/// - All data cached locally for offline access
/// - Background sync when online
/// - Automatic cache invalidation based on TTL
class CacheManager {
  final AppDatabase _database;
  Box? _graphqlCacheBox;
  Box? _userCacheBox;
  Box? _demoAssetsBox;

  CacheManager(this._database);

  /// Initialize all Hive boxes
  ///
  /// Must be called during app startup after Hive.initFlutter()
  Future<void> initialize() async {
    _graphqlCacheBox = await Hive.openBox('graphql_cache');
    _userCacheBox = await Hive.openBox('user_cache');
    _demoAssetsBox = await Hive.openBox('demo_assets');
  }

  /// Get GraphQL query cache box
  Box get graphqlCache {
    if (_graphqlCacheBox == null) {
      throw StateError('Cache not initialized. Call initialize() first.');
    }
    return _graphqlCacheBox!;
  }

  /// Get user profile cache box
  Box get userCache {
    if (_userCacheBox == null) {
      throw StateError('Cache not initialized. Call initialize() first.');
    }
    return _userCacheBox!;
  }

  /// Get demo assets cache box
  Box get demoAssetsCache {
    if (_demoAssetsBox == null) {
      throw StateError('Cache not initialized. Call initialize() first.');
    }
    return _demoAssetsBox!;
  }

  /// Put data in cache with TTL
  ///
  /// Usage:
  /// ```dart
  /// await cacheManager.put(
  ///   'query_key',
  ///   queryData,
  ///   ttl: Duration(hours: 24),
  /// );
  /// ```
  Future<void> put(
    String key,
    dynamic data, {
    Duration ttl = const Duration(hours: 24),
    Box? box,
  }) async {
    final cacheBox = box ?? graphqlCache;
    final now = DateTime.now();
    final entry = CacheEntry(
      data: data,
      cachedAt: now,
      expiresAt: now.add(ttl),
    );

    await cacheBox.put(key, {
      'data': data,
      'cachedAt': now.toIso8601String(),
      'expiresAt': entry.expiresAt.toIso8601String(),
    });

    // Update database metadata for tracking
    await _updateCacheMetadata(key, entry);
  }

  /// Get data from cache
  ///
  /// Returns null if:
  /// - Key doesn't exist
  /// - Cache entry is expired
  Future<dynamic> get(String key, {Box? box}) async {
    final cacheBox = box ?? graphqlCache;
    final raw = cacheBox.get(key);

    if (raw == null) return null;

    try {
      final Map<String, dynamic> entry = Map<String, dynamic>.from(raw as Map);
      final expiresAt = DateTime.parse(entry['expiresAt'] as String);

      // Check if expired
      if (DateTime.now().isAfter(expiresAt)) {
        await delete(key, box: cacheBox);
        return null;
      }

      return entry['data'];
    } catch (e) {
      // Invalid cache entry, delete it
      await delete(key, box: cacheBox);
      return null;
    }
  }

  /// Delete cache entry
  Future<void> delete(String key, {Box? box}) async {
    final cacheBox = box ?? graphqlCache;
    await cacheBox.delete(key);
  }

  /// Clear all entries in a box
  Future<void> clear({Box? box}) async {
    final cacheBox = box ?? graphqlCache;
    await cacheBox.clear();
  }

  /// Clear expired cache entries across all boxes
  ///
  /// Should be called periodically (e.g., on app startup)
  Future<void> clearExpired() async {
    await _clearExpiredInBox(_graphqlCacheBox);
    await _clearExpiredInBox(_userCacheBox);
    await _clearExpiredInBox(_demoAssetsBox);

    // Also clear expired entries from database
    await _database.clearExpiredCache();
  }

  /// Clear expired entries in specific box
  Future<void> _clearExpiredInBox(Box? box) async {
    if (box == null) return;

    final now = DateTime.now();
    final keysToDelete = <String>[];

    for (final key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw == null) continue;

        final Map<String, dynamic> entry = Map<String, dynamic>.from(raw as Map);
        final expiresAt = DateTime.parse(entry['expiresAt'] as String);

        if (now.isAfter(expiresAt)) {
          keysToDelete.add(key.toString());
        }
      } catch (e) {
        // Invalid entry, mark for deletion
        keysToDelete.add(key.toString());
      }
    }

    await box.deleteAll(keysToDelete);
  }

  /// Clear all caches (used on logout or manual clear)
  Future<void> clearAll() async {
    await clear(box: _graphqlCacheBox);
    await clear(box: _userCacheBox);
    await clear(box: _demoAssetsBox);
    await _database.clearAllCache();
  }

  /// Get cache statistics
  ///
  /// Returns map with cache sizes and entry counts
  Map<String, dynamic> getStats() {
    return {
      'graphql_cache': {
        'entries': _graphqlCacheBox?.length ?? 0,
        'size_bytes': _estimateBoxSize(_graphqlCacheBox),
      },
      'user_cache': {
        'entries': _userCacheBox?.length ?? 0,
        'size_bytes': _estimateBoxSize(_userCacheBox),
      },
      'demo_assets': {
        'entries': _demoAssetsBox?.length ?? 0,
        'size_bytes': _estimateBoxSize(_demoAssetsBox),
      },
    };
  }

  /// Estimate box size in bytes (approximation)
  int _estimateBoxSize(Box? box) {
    if (box == null) return 0;
    // Rough estimate: 1KB per entry on average
    return box.length * 1024;
  }

  /// Update cache metadata in database for tracking
  Future<void> _updateCacheMetadata(String key, CacheEntry entry) async {
    try {
      // Store metadata in database for analytics and cleanup
      final sizeBytes = _estimateEntrySize(entry.data);

      await _database.into(_database.graphQLCacheMeta).insertOnConflictUpdate(
            GraphQLCacheMetaCompanion.insert(
              queryKey: key,
              queryHash: key.hashCode.toString(),
              cachedAt: entry.cachedAt,
              expiresAt: entry.expiresAt,
              sizeBytes: Value(sizeBytes),
            ),
          );
    } catch (e) {
      // Ignore metadata update errors
    }
  }

  /// Estimate entry size in bytes (rough approximation)
  int _estimateEntrySize(dynamic data) {
    // Very rough estimate based on data type
    if (data == null) return 0;
    if (data is String) return data.length;
    if (data is List) return data.length * 512; // Assume 512 bytes per item
    if (data is Map) return data.length * 256; // Assume 256 bytes per key-value
    return 1024; // Default 1KB
  }

  /// Close all boxes
  Future<void> dispose() async {
    await _graphqlCacheBox?.close();
    await _userCacheBox?.close();
    await _demoAssetsBox?.close();
  }
}

/// Cache manager provider
final cacheManagerProvider = Provider<CacheManager>((ref) {
  final db = ref.watch(databaseProvider);
  final cacheManager = CacheManager(db);

  // Ensure cache is disposed when provider is disposed
  ref.onDispose(() {
    cacheManager.dispose();
  });

  return cacheManager;
});

/// Initialize cache manager on app startup
///
/// Call this in main() after Hive.initFlutter()
final cacheInitializationProvider = FutureProvider<void>((ref) async {
  final cacheManager = ref.watch(cacheManagerProvider);
  await cacheManager.initialize();

  // Clear expired entries on startup
  await cacheManager.clearExpired();
});
