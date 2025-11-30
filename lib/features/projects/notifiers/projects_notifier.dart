import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:vron_graphql_client/vron_graphql_client.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../models/projects_state.dart';

/// Projects notifier - Manages projects list state
///
/// Handles:
/// - Fetch projects from GraphQL API
/// - Cache projects in Drift for offline access
/// - Refresh projects list
/// - Cache-first fetch strategy
class ProjectsNotifier extends StateNotifier<ProjectsState> {
  final ProjectRepository _projectRepository;
  final AppDatabase _db;

  ProjectsNotifier(this._projectRepository, this._db)
      : super(const ProjectsState.initial());

  /// Fetch projects from API and cache locally
  ///
  /// Uses cache-first strategy:
  /// 1. Return cached data immediately if available
  /// 2. Fetch from API in background
  /// 3. Update cache with fresh data
  Future<void> fetchProjects({bool forceRefresh = false}) async {
    try {
      // Show loading state only if no cached data
      if (!forceRefresh && state.projects.isEmpty) {
        state = const ProjectsState.loading();
      }

      // Fetch from GraphQL with cache-first strategy
      final result = await _projectRepository.fetchProjects();

      if (result.hasException) {
        // If we have cached data, show it with error
        final cachedProjects = await _db.getAllProjects();
        if (cachedProjects.isNotEmpty) {
          state = ProjectsState.loaded(
            projects: cachedProjects,
            hasError: true,
            errorMessage: _extractErrorMessage(result.exception),
          );
        } else {
          state = ProjectsState.error(_extractErrorMessage(result.exception));
        }
        return;
      }

      final data = result.data;
      if (data == null) {
        state = ProjectsState.error('No data returned from API');
        return;
      }

      // Parse projects from GraphQL response
      final projectsList = data['getProjects'] as List<dynamic>?;
      if (projectsList == null) {
        state = ProjectsState.error('Invalid response format');
        return;
      }

      // Cache projects in Drift
      for (final project in projectsList) {
        final projectMap = project as Map<String, dynamic>;
        final nameData = projectMap['name'] as Map<String, dynamic>?;
        final subscription = projectMap['subscription'] as Map<String, dynamic>?;

        await _db.upsertProject(
          ProjectsCompanion(
            id: Value(projectMap['id'] as String),
            slug: Value(projectMap['slug'] as String),
            name: Value(nameData?['text'] as String? ?? ''),
            imageUrl: Value(projectMap['imageUrl'] as String?),
            isLive: Value(projectMap['isLive'] as bool? ?? false),
            liveDate: Value(
              projectMap['liveDate'] != null
                  ? DateTime.parse(projectMap['liveDate'] as String)
                  : null,
            ),
            subscriptionStatus: Value(subscription?['status'] as String?),
            subscriptionIsTrial: Value(subscription?['isTrial'] as bool? ?? false),
            subscriptionIsActive: Value(subscription?['isActive'] as bool? ?? false),
            subscriptionStartedAt: Value(
              subscription?['startedAt'] != null
                  ? DateTime.parse(subscription!['startedAt'] as String)
                  : null,
            ),
            subscriptionExpiresAt: Value(
              subscription?['expiresAt'] != null
                  ? DateTime.parse(subscription!['expiresAt'] as String)
                  : null,
            ),
            subscriptionRenewsAt: Value(
              subscription?['renewsAt'] != null
                  ? DateTime.parse(subscription!['renewsAt'] as String)
                  : null,
            ),
            syncedAt: Value(DateTime.now()),
          ),
        );
      }

      // Get all projects from cache (includes previously cached)
      final projects = await _db.getAllProjects();
      state = ProjectsState.loaded(projects: projects);
    } catch (e) {
      // Try to load from cache on error
      try {
        final cachedProjects = await _db.getAllProjects();
        if (cachedProjects.isNotEmpty) {
          state = ProjectsState.loaded(
            projects: cachedProjects,
            hasError: true,
            errorMessage: 'Error: ${e.toString()}',
          );
        } else {
          state = ProjectsState.error('Failed to fetch projects: ${e.toString()}');
        }
      } catch (_) {
        state = ProjectsState.error('Failed to fetch projects: ${e.toString()}');
      }
    }
  }

  /// Refresh projects (force API call)
  Future<void> refresh() async {
    await fetchProjects(forceRefresh: true);
  }

  /// Extract error message from GraphQL exception
  String _extractErrorMessage(OperationException? exception) {
    if (exception == null) return 'Unknown error';

    // GraphQL errors (validation, query errors, etc.)
    if (exception.graphqlErrors.isNotEmpty) {
      final error = exception.graphqlErrors.first;
      final message = error.message;
      final code = error.extensions?['code'] as String?;

      // Format based on error code
      if (code == 'GRAPHQL_VALIDATION_FAILED') {
        return 'Query validation error: $message';
      } else if (code == 'UNAUTHENTICATED') {
        return 'Authentication required. Please log in again.';
      } else if (code == 'FORBIDDEN') {
        return 'You do not have permission to access this resource.';
      }

      return message;
    }

    // Network/connection errors
    if (exception.linkException != null) {
      final linkException = exception.linkException!;

      // Check for specific network error types
      if (linkException.toString().contains('SocketException') ||
          linkException.toString().contains('Failed host lookup')) {
        return 'Network error: Unable to reach server. Check your internet connection.';
      } else if (linkException.toString().contains('TimeoutException')) {
        return 'Network error: Request timed out. Please try again.';
      } else if (linkException.toString().contains('HandshakeException')) {
        return 'Network error: Secure connection failed.';
      }

      return 'Network error: ${linkException.toString()}';
    }

    return 'An unexpected error occurred';
  }
}

/// Projects notifier provider
final projectsNotifierProvider =
    StateNotifierProvider<ProjectsNotifier, ProjectsState>((ref) {
  final graphqlClient = ref.watch(graphqlClientProvider);
  final db = ref.watch(databaseProvider);
  final projectRepository = ProjectRepository(graphqlClient);

  final notifier = ProjectsNotifier(projectRepository, db);

  // Auto-fetch on initialization
  Future.microtask(() => notifier.fetchProjects());

  return notifier;
});

/// Convenience provider for projects list
final projectsListProvider = Provider<List<Project>>((ref) {
  final state = ref.watch(projectsNotifierProvider);
  return state.projects;
});
