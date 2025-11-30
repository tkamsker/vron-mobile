import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_link.dart';
import 'cache_config.dart';

/// GraphQL client provider for vron.one API
///
/// Provides configured GraphQL client with:
/// - Authentication via base64-encoded token
/// - Offline caching with Hive
/// - WebSocket subscriptions support
/// - Required headers (X-VRon-Platform: merchants)
final graphqlClientProvider = Provider<GraphQLClient>((ref) {
  final httpEndpoint = dotenv.env['GRAPHQL_ENDPOINT'] ??
      'https://api.vron.stage.motorenflug.at/graphql';
  final wsEndpoint = dotenv.env['GRAPHQL_WS_ENDPOINT'] ??
      'wss://api.vron.stage.motorenflug.at/graphql';

  // HTTP link for queries and mutations
  final httpLink = HttpLink(
    httpEndpoint,
    defaultHeaders: {
      'X-VRon-Platform': 'merchants',
    },
  );

  // WebSocket link for subscriptions
  final wsLink = WebSocketLink(
    wsEndpoint,
    config: SocketClientConfig(
      autoReconnect: true,
      inactivityTimeout: const Duration(seconds: 30),
      initialPayload: () async => {
        'headers': {
          'X-VRon-Platform': 'merchants',
        },
      },
    ),
  );

  // Auth link that adds Authorization header
  final authLink = createAuthLink(ref);

  // Split link: use WebSocket for subscriptions, HTTP for everything else
  final link = Link.split(
    (request) => request.isSubscription,
    authLink.concat(wsLink),
    authLink.concat(httpLink),
  );

  // Create client with offline cache
  return GraphQLClient(
    link: link,
    cache: createGraphQLCache(),
    defaultPolicies: DefaultPolicies(
      query: Policies(
        fetch: FetchPolicy.cacheFirst, // Offline-first per Constitution Principle II
        error: ErrorPolicy.all,
        cacheReread: CacheRereadPolicy.mergeOptimistic,
      ),
      mutate: Policies(
        fetch: FetchPolicy.networkOnly, // Always fresh for mutations
        error: ErrorPolicy.all,
      ),
      subscribe: Policies(
        fetch: FetchPolicy.noCache, // Real-time data, no cache
        error: ErrorPolicy.all,
      ),
      watchQuery: Policies(
        fetch: FetchPolicy.cacheAndNetwork,
        error: ErrorPolicy.all,
      ),
      watchMutation: Policies(
        fetch: FetchPolicy.networkOnly,
        error: ErrorPolicy.all,
      ),
    ),
  );
});

/// Provider for checking if client is initialized
final isGraphQLInitializedProvider = Provider<bool>((ref) {
  try {
    ref.watch(graphqlClientProvider);
    return true;
  } catch (e) {
    return false;
  }
});
