import 'package:hive_flutter/hive_flutter.dart';

/// Cache eviction strategies
enum EvictionStrategy {
  /// Least Recently Used - evict oldest accessed entries first
  lru,

  /// Time To Live - evict expired entries
  ttl,

  /// Least Frequently Used - evict least accessed entries
  lfu,

  /// First In First Out - evict oldest entries
  fifo,
}

/// Cache eviction policy configuration
class CacheEvictionPolicy {
  /// Maximum cache size in bytes (default: 50 MB)
  final int maxSizeBytes;

  /// Eviction strategy to use
  final EvictionStrategy strategy;

  /// TTL for cache entries
  final Duration defaultTtl;

  /// Percentage of cache to clear when max size reached (default: 20%)
  final double evictionPercentage;

  const CacheEvictionPolicy({
    this.maxSizeBytes = 50 * 1024 * 1024, // 50 MB
    this.strategy = EvictionStrategy.lru,
    this.defaultTtl = const Duration(hours: 24),
    this.evictionPercentage = 0.2, // Clear 20% of cache when full
  });

  /// Default policy for GraphQL cache (24-hour TTL, 50 MB max)
  static const graphqlCache = CacheEvictionPolicy(
    maxSizeBytes: 50 * 1024 * 1024,
    strategy: EvictionStrategy.lru,
    defaultTtl: Duration(hours: 24),
  );

  /// Policy for demo assets (7-day TTL, 100 MB max)
  static const demoAssets = CacheEvictionPolicy(
    maxSizeBytes: 100 * 1024 * 1024,
    strategy: EvictionStrategy.lru,
    defaultTtl: Duration(days: 7),
  );

  /// Policy for user cache (24-hour TTL, 10 MB max)
  static const userCache = CacheEvictionPolicy(
    maxSizeBytes: 10 * 1024 * 1024,
    strategy: EvictionStrategy.lru,
    defaultTtl: Duration(hours: 24),
  );
}

/// Cache eviction manager
///
/// Implements LRU + TTL eviction strategies to keep cache size under control.
/// Per Constitution Principle II (Offline-First), we balance:
/// - Keeping data cached for offline access
/// - Not exceeding device storage limits
/// - Maintaining app performance
class CacheEvictionManager {
  final CacheEvictionPolicy policy;

  CacheEvictionManager(this.policy);

  /// Check if cache needs eviction and perform if necessary
  ///
  /// Returns number of entries evicted
  Future<int> enforcePolicy(Box box) async {
    // First, clear expired entries (TTL-based eviction)
    int evictedCount = await _clearExpiredEntries(box);

    // Then, check if we need LRU eviction
    final estimatedSize = _estimateCacheSize(box);

    if (estimatedSize > policy.maxSizeBytes) {
      evictedCount += await _evictLRU(box);
    }

    return evictedCount;
  }

  /// Clear expired entries based on TTL
  Future<int> _clearExpiredEntries(Box box) async {
    final now = DateTime.now();
    final keysToDelete = <dynamic>[];

    for (final key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw == null) continue;

        final Map<String, dynamic> entry = Map<String, dynamic>.from(raw as Map);
        final expiresAt = DateTime.parse(entry['expiresAt'] as String);

        if (now.isAfter(expiresAt)) {
          keysToDelete.add(key);
        }
      } catch (e) {
        // Invalid entry, mark for deletion
        keysToDelete.add(key);
      }
    }

    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }

    return keysToDelete.length;
  }

  /// Evict entries using LRU strategy
  Future<int> _evictLRU(Box box) async {
    final entries = <_CacheEntryInfo>[];

    // Build list of entries with metadata
    for (final key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw == null) continue;

        final Map<String, dynamic> entry = Map<String, dynamic>.from(raw as Map);
        final cachedAt = DateTime.parse(entry['cachedAt'] as String);
        final lastAccessedAt = entry['lastAccessedAt'] != null
            ? DateTime.parse(entry['lastAccessedAt'] as String)
            : cachedAt;
        final accessCount = entry['accessCount'] as int? ?? 0;

        entries.add(_CacheEntryInfo(
          key: key,
          cachedAt: cachedAt,
          lastAccessedAt: lastAccessedAt,
          accessCount: accessCount,
          size: _estimateEntrySize(entry['data']),
        ));
      } catch (e) {
        // Invalid entry, will be handled later
      }
    }

    // Sort by eviction strategy
    switch (policy.strategy) {
      case EvictionStrategy.lru:
        // Sort by last accessed time (oldest first)
        entries.sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));
        break;
      case EvictionStrategy.lfu:
        // Sort by access count (least accessed first)
        entries.sort((a, b) => a.accessCount.compareTo(b.accessCount));
        break;
      case EvictionStrategy.fifo:
        // Sort by cached time (oldest first)
        entries.sort((a, b) => a.cachedAt.compareTo(b.cachedAt));
        break;
      case EvictionStrategy.ttl:
        // Already handled by _clearExpiredEntries
        return 0;
    }

    // Calculate number of entries to evict
    final entriesToEvict = (entries.length * policy.evictionPercentage).ceil();
    final keysToDelete = entries.take(entriesToEvict).map((e) => e.key).toList();

    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }

    return keysToDelete.length;
  }

  /// Estimate total cache size
  int _estimateCacheSize(Box box) {
    int totalSize = 0;

    for (final key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw == null) continue;

        final Map<String, dynamic> entry = Map<String, dynamic>.from(raw as Map);
        totalSize += _estimateEntrySize(entry['data']);
      } catch (e) {
        // Ignore invalid entries
      }
    }

    return totalSize;
  }

  /// Estimate entry size in bytes
  int _estimateEntrySize(dynamic data) {
    if (data == null) return 0;
    if (data is String) return data.length * 2; // 2 bytes per char (UTF-16)
    if (data is List) return data.length * 512; // Assume 512 bytes per item
    if (data is Map) return data.length * 256; // Assume 256 bytes per key-value
    if (data is int) return 8;
    if (data is double) return 8;
    if (data is bool) return 1;
    return 1024; // Default 1KB for unknown types
  }

  /// Update access metadata for cache entry (for LRU/LFU tracking)
  Future<void> recordAccess(Box box, String key) async {
    try {
      final raw = box.get(key);
      if (raw == null) return;

      final Map<String, dynamic> entry = Map<String, dynamic>.from(raw as Map);
      entry['lastAccessedAt'] = DateTime.now().toIso8601String();
      entry['accessCount'] = (entry['accessCount'] as int? ?? 0) + 1;

      await box.put(key, entry);
    } catch (e) {
      // Ignore errors in access tracking
    }
  }
}

/// Internal class for cache entry metadata
class _CacheEntryInfo {
  final dynamic key;
  final DateTime cachedAt;
  final DateTime lastAccessedAt;
  final int accessCount;
  final int size;

  _CacheEntryInfo({
    required this.key,
    required this.cachedAt,
    required this.lastAccessedAt,
    required this.accessCount,
    required this.size,
  });
}

/// Eviction manager instances for different cache types
class CacheEvictionManagers {
  static final graphqlCache = CacheEvictionManager(
    CacheEvictionPolicy.graphqlCache,
  );

  static final demoAssets = CacheEvictionManager(
    CacheEvictionPolicy.demoAssets,
  );

  static final userCache = CacheEvictionManager(
    CacheEvictionPolicy.userCache,
  );
}
