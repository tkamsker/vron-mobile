import 'package:graphql_flutter/graphql_flutter.dart';

/// Project repository - GraphQL operations for projects
///
/// Handles:
/// - Fetch all projects with pagination
/// - Fetch single project by ID
/// - Update project metadata
class ProjectRepository {
  final GraphQLClient _client;

  ProjectRepository(this._client);

  /// Fetch all projects for authenticated user
  ///
  /// Returns list of projects from getProjects query.
  Future<QueryResult> fetchProjects() async {
    const query = '''
      query GetProjects(\$input: VRGetProjectsInput!) {
        getProjects(input: \$input) {
          id
          slug
          name {
            text
          }
          imageUrl
          isLive
          liveDate
          subscription {
            canChoosePlan
            prices {
              monthly
              yearly
              currency
            }
            isTrial
            status
            startedAt
            expiresAt
            renewsAt
            price
            currency
            renewalInterval
            hasExpired
            isActive
          }
        }
      }
    ''';

    return _client.query(
      QueryOptions(
        document: gql(query),
        variables: {
          'input': {}, // Empty input to fetch all projects
        },
        fetchPolicy: FetchPolicy.cacheFirst, // Cache-first strategy per Constitution Principle II
      ),
    );
  }

  /// Fetch single project by ID with all rooms
  ///
  /// Returns project details including rooms.
  Future<QueryResult> fetchProject(String id) async {
    const query = '''
      query Project(\$id: ID!) {
        project(id: \$id) {
          id
          name
          description
          status
          thumbnailUrl
          createdAt
          updatedAt
          rooms {
            id
            name
            sceneUrl
            navmeshUrl
            createdAt
            updatedAt
          }
        }
      }
    ''';

    return _client.query(
      QueryOptions(
        document: gql(query),
        variables: {'id': id},
        fetchPolicy: FetchPolicy.cacheFirst,
      ),
    );
  }

  /// Update project metadata (name, description, status)
  ///
  /// Users cannot create or delete projects (managed via web platform).
  /// Returns updated project.
  Future<QueryResult> updateProject({
    required String id,
    String? name,
    String? description,
    String? status,
  }) async {
    const mutation = '''
      mutation UpdateProject(\$input: UpdateProjectInput!) {
        updateProject(input: \$input) {
          id
          name
          description
          status
          thumbnailUrl
          createdAt
          updatedAt
        }
      }
    ''';

    return _client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          'input': {
            'id': id,
            if (name != null) 'name': name,
            if (description != null) 'description': description,
            if (status != null) 'status': status,
          }
        },
      ),
    );
  }
}
