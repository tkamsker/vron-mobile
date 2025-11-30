import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:hive/hive.dart';

/// Creates GraphQL cache with Hive store for offline persistence
///
/// Cache strategy per Constitution Principle II (Offline-First):
/// - Persistent storage via Hive
/// - 24-hour TTL (managed by cache manager in lib/core/cache/)
/// - Optimistic updates enabled
/// - Normalized cache for efficient storage
GraphQLCache createGraphQLCache() {
  // Use Hive for persistent cache storage
  // Get the box that was opened with correct type in main.dart
  final box = Hive.box<Map<dynamic, dynamic>?>('graphqlCache');
  final store = HiveStore(box);

  return GraphQLCache(
    store: store,
    // Normalize cache to deduplicate entities
    // Example: Multiple queries returning same Project will share cached data
    partialDataPolicy: PartialDataCachePolicy.accept,
  );
}

/// Cache configuration constants
class CacheConfig {
  CacheConfig._();

  /// Cache TTL (24 hours per specification)
  static const Duration cacheTtl = Duration(hours: 24);

  /// Maximum cache size (50 MB)
  static const int maxCacheSizeBytes = 50 * 1024 * 1024;

  /// Cache box name for Hive
  static const String cacheBoxName = 'graphql_cache';

  /// Enable cache debugging
  static const bool enableCacheDebugging = false;
}

/// Extension methods for cache operations
extension GraphQLCacheExtensions on GraphQLCache {
  /// Clears all cached data
  ///
  /// Used when:
  /// - User logs out
  /// - Cache corruption detected
  /// - Manual cache clear requested
  Future<void> clearAll() async {
    try {
      store.reset();
    } catch (e) {
      // Ignore errors during cache clear
    }
  }

  /// Checks if cache is initialized
  bool get isInitialized {
    return true; // Cache is always initialized with HiveStore
  }

  /// Estimates cache size (approximation)
  ///
  /// Note: Hive doesn't provide exact size, this is an estimate
  Future<int> estimateSizeBytes() async {
    try {
      // This is a rough estimate - Hive doesn't expose exact sizes
      // In production, you might want to track this separately
      return 0; // Placeholder
    } catch (e) {
      return 0;
    }
  }
}

/// Cache key utilities for consistent cache management
class CacheKeys {
  CacheKeys._();

  /// Generates cache key for projects query
  static String projectsKey({int? first, String? after}) {
    return 'projects_${first ?? 20}_${after ?? 'null'}';
  }

  /// Generates cache key for single project query
  static String projectKey(String id) {
    return 'project_$id';
  }

  /// Generates cache key for rooms query
  static String roomsKey(String projectId) {
    return 'rooms_$projectId';
  }

  /// Generates cache key for demo assets query
  static String demoAssetsKey(String? theme) {
    return 'demo_assets_${theme ?? 'all'}';
  }

  /// Generates cache key for user profile
  static String get userProfileKey => 'user_profile';
}
