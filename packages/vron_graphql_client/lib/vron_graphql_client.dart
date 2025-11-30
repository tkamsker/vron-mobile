/// VRON GraphQL Client Package
///
/// Provides type-safe GraphQL client for vron.one API with:
/// - Base64-encoded authentication per vron.one spec
/// - Offline-first caching with Hive
/// - WebSocket subscriptions support
/// - Required headers (X-VRon-Platform: merchants)
library;

export 'src/graphql_client_provider.dart';
export 'src/auth_link.dart';
export 'src/cache_config.dart';

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
