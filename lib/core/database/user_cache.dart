import 'package:drift/drift.dart';
import 'database.dart';

/// User cache operations for offline support
///
/// Provides methods to cache and retrieve user profile data
/// for offline authentication and user data access
class UserCacheOperations {
  final AppDatabase _db;

  UserCacheOperations(this._db);

  /// Cache user profile data after successful login
  ///
  /// Stores user data in Drift for offline access
  /// Sets expiration to 24 hours from now
  Future<void> cacheUserProfile({
    required String userId,
    required String email,
    required String accessToken,
    List<String> activeRoles = const [],
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    await _db.into(_db.userCache).insertOnConflictUpdate(
          UserCacheCompanion.insert(
            id: userId,
            email: email,
            accessToken: accessToken,
            activeRoles: activeRoles.join(','), // Store as comma-separated string
            cachedAt: now,
            expiresAt: expiresAt,
          ),
        );
  }

  /// Get cached user profile by user ID
  ///
  /// Returns null if user not found or cache expired
  Future<UserCacheData?> getCachedUser(String userId) async {
    final query = _db.select(_db.userCache)
      ..where((u) => u.id.equals(userId));

    final user = await query.getSingleOrNull();

    if (user == null) return null;

    // Check if cache expired
    if (user.expiresAt.isBefore(DateTime.now())) {
      await deleteCachedUser(userId);
      return null;
    }

    return user;
  }

  /// Get cached user profile by email
  ///
  /// Returns null if user not found or cache expired
  Future<UserCacheData?> getCachedUserByEmail(String email) async {
    final query = _db.select(_db.userCache)
      ..where((u) => u.email.equals(email));

    final user = await query.getSingleOrNull();

    if (user == null) return null;

    // Check if cache expired
    if (user.expiresAt.isBefore(DateTime.now())) {
      await _db.delete(_db.userCache)
        ..where((u) => u.email.equals(email));
      return null;
    }

    return user;
  }

  /// Delete cached user profile
  Future<void> deleteCachedUser(String userId) async {
    await (_db.delete(_db.userCache)..where((u) => u.id.equals(userId))).go();
  }

  /// Clear all cached user profiles
  Future<void> clearAllUsers() async {
    await _db.delete(_db.userCache).go();
  }

  /// Get all cached users (for debugging)
  Future<List<UserCacheData>> getAllCachedUsers() async {
    return _db.select(_db.userCache).get();
  }

  /// Check if user is cached
  Future<bool> isUserCached(String userId) async {
    final user = await getCachedUser(userId);
    return user != null;
  }

  /// Refresh cache expiration for a user
  ///
  /// Extends cache expiration by 24 hours from now
  Future<void> refreshCacheExpiration(String userId) async {
    final expiresAt = DateTime.now().add(const Duration(hours: 24));

    await (_db.update(_db.userCache)..where((u) => u.id.equals(userId))).write(
      UserCacheCompanion(
        expiresAt: Value(expiresAt),
      ),
    );
  }
}
