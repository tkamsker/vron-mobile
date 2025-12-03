/// VRON GraphQL Client Package
///
/// Provides type-safe GraphQL client for vron.one API with:
/// - Base64-encoded authentication per vron.one spec
/// - Offline-first caching with Hive
/// - WebSocket subscriptions support
/// - Required headers (X-VRon-Platform: merchants)
/// - Resumable upload infrastructure with progress tracking
library;

// GraphQL Client & Configuration
export 'src/graphql_client_provider.dart';
export 'src/auth_link.dart';
export 'src/cache_config.dart';

// Repositories
export 'src/repositories/project_repository.dart';
export 'src/repositories/auth_repository.dart';

// Upload Infrastructure
export 'src/database/upload_database.dart';
export 'src/database/tables.dart';
export 'src/database/database_provider.dart';
export 'src/services/upload_service.dart';
export 'src/services/upload_service_provider.dart';
export 'src/notifiers/upload_notifier.dart';
export 'src/notifiers/upload_notifier_provider.dart';

// Re-export commonly used graphql_flutter types
export 'package:graphql_flutter/graphql_flutter.dart'
    show
        GraphQLClient,
        QueryOptions,
        MutationOptions,
        SubscriptionOptions,
        QueryResult,
        FetchPolicy,
        ErrorPolicy;
