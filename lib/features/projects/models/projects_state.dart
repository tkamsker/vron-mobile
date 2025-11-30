import '../../../core/database/database.dart';

/// Projects state - Represents different states of projects list
class ProjectsState {
  /// Whether projects are being loaded
  final bool isLoading;

  /// Error message if loading failed
  final String? error;

  /// List of projects
  final List<Project> projects;

  /// Whether there was an error while showing cached data
  final bool hasError;

  const ProjectsState({
    this.isLoading = false,
    this.error,
    this.projects = const [],
    this.hasError = false,
  });

  /// Initial state (not loaded)
  const ProjectsState.initial()
      : isLoading = false,
        error = null,
        projects = const [],
        hasError = false;

  /// Loading state (fetching projects)
  const ProjectsState.loading()
      : isLoading = true,
        error = null,
        projects = const [],
        hasError = false;

  /// Loaded state (projects available)
  const ProjectsState.loaded({
    required this.projects,
    this.hasError = false,
    String? errorMessage,
  })  : isLoading = false,
        error = errorMessage;

  /// Error state (loading failed)
  ProjectsState.error(String errorMessage)
      : isLoading = false,
        error = errorMessage,
        projects = const [],
        hasError = true;

  /// Copy with modifications
  ProjectsState copyWith({
    bool? isLoading,
    String? error,
    List<Project>? projects,
    bool? hasError,
  }) {
    return ProjectsState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      projects: projects ?? this.projects,
      hasError: hasError ?? this.hasError,
    );
  }

  /// Get state type
  bool get isInitial => !isLoading && projects.isEmpty && error == null;
  bool get isLoadedState => projects.isNotEmpty;
  bool get isErrorState => error != null && projects.isEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProjectsState &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.projects == projects &&
        other.hasError == hasError;
  }

  @override
  int get hashCode {
    return Object.hash(
      isLoading,
      error,
      projects,
      hasError,
    );
  }

  @override
  String toString() {
    return 'ProjectsState(isLoading: $isLoading, error: $error, projectsCount: ${projects.length}, hasError: $hasError)';
  }
}
