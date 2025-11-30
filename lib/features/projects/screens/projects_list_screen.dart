import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifiers/projects_notifier.dart';
import '../widgets/project_card.dart';
import '../../../core/auth/auth_notifier.dart';
import 'project_detail_screen.dart';

/// Projects list screen - Displays list of user's projects
class ProjectsListScreen extends ConsumerWidget {
  const ProjectsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsState = ref.watch(projectsNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Projects'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(projectsNotifierProvider.notifier).refresh();
        },
        child: _buildBody(context, ref, projectsState, theme),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, projectsState, ThemeData theme) {
    // Loading state
    if (projectsState.isLoading && projectsState.projects.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Error state (no cached data)
    if (projectsState.isErrorState) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to Load Projects',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatErrorMessage(projectsState.error),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(projectsNotifierProvider.notifier).refresh();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (projectsState.projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Your projects will appear here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Loaded state
    return Column(
      children: [
        // Offline indicator
        if (projectsState.hasError && projectsState.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.errorContainer,
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 20,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Showing cached data',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatErrorMessage(projectsState.error),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    size: 20,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    await ref.read(projectsNotifierProvider.notifier).refresh();
                  },
                  tooltip: 'Retry',
                ),
              ],
            ),
          ),

        // Projects list
        Expanded(
          child: ListView.builder(
            itemCount: projectsState.projects.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final project = projectsState.projects[index];
              return ProjectCard(
                project: project,
                onTap: () {
                  // Navigate to project detail
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProjectDetailScreen(
                        project: project,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Format error message to be user-friendly
  String _formatErrorMessage(String? error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';

    // Network errors
    if (error.toLowerCase().contains('network')) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    }

    // GraphQL validation errors
    if (error.contains('GRAPHQL_VALIDATION_FAILED') ||
        error.contains('argument') ||
        error.contains('required')) {
      return 'There was a problem with the request. Please update the app or contact support.';
    }

    // Authentication errors
    if (error.toLowerCase().contains('unauthorized') ||
        error.toLowerCase().contains('authentication') ||
        error.toLowerCase().contains('token')) {
      return 'Your session has expired. Please log in again.';
    }

    // Server errors
    if (error.toLowerCase().contains('server')) {
      return 'The server is currently unavailable. Please try again later.';
    }

    // Timeout errors
    if (error.toLowerCase().contains('timeout')) {
      return 'The request took too long. Please check your connection and try again.';
    }

    // Default: return a simplified version of the error
    // Remove technical details but keep the core message
    final simplifiedError = error
        .replaceAll(RegExp(r'ServerException.*'), 'Server error')
        .replaceAll(RegExp(r'originalException.*'), '')
        .replaceAll(RegExp(r'originalStackTrace.*'), '')
        .replaceAll(RegExp(r'parsedResponse.*'), '')
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .trim();

    if (simplifiedError.length > 150) {
      return '${simplifiedError.substring(0, 147)}...';
    }

    return simplifiedError.isNotEmpty
        ? simplifiedError
        : 'An unexpected error occurred. Please try again.';
  }
}
