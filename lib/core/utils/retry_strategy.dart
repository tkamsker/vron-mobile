import 'dart:async';
import 'dart:math';

/// Retry strategy configuration
class RetryConfig {
  /// Maximum number of retry attempts
  final int maxAttempts;

  /// Initial delay before first retry
  final Duration initialDelay;

  /// Maximum delay between retries
  final Duration maxDelay;

  /// Backoff multiplier (exponential factor)
  final double backoffMultiplier;

  /// Jitter factor (randomness to prevent thundering herd)
  final double jitterFactor;

  /// Should retry on specific exceptions only
  final bool Function(dynamic error)? retryIf;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.jitterFactor = 0.2,
    this.retryIf,
  });

  /// Default retry config per spec: 1s, 2s, 4s exponential backoff
  static const defaultConfig = RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 8),
    backoffMultiplier: 2.0,
  );

  /// Aggressive retry for critical operations
  static const aggressiveConfig = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 16),
    backoffMultiplier: 2.0,
  );

  /// Conservative retry for non-critical operations
  static const conservativeConfig = RetryConfig(
    maxAttempts: 2,
    initialDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 10),
    backoffMultiplier: 2.0,
  );

  /// Network retry (for API calls)
  static const networkConfig = RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 8),
    backoffMultiplier: 2.0,
    jitterFactor: 0.3, // More jitter for network calls
  );
}

/// Retry strategy with exponential backoff
///
/// Implements exponential backoff with jitter per Constitution spec:
/// - Attempt 1: Wait 1 second
/// - Attempt 2: Wait 2 seconds
/// - Attempt 3: Wait 4 seconds
/// - Maximum 3 retries
///
/// Jitter is added to prevent thundering herd problem when multiple
/// clients retry simultaneously.
class RetryStrategy {
  final RetryConfig config;
  final Random _random = Random();

  RetryStrategy([this.config = RetryConfig.defaultConfig]);

  /// Execute function with retry logic
  ///
  /// Usage:
  /// ```dart
  /// final result = await retryStrategy.execute(
  ///   () => apiClient.fetchData(),
  ///   onRetry: (attempt, error, delay) {
  ///     print('Retry attempt $attempt after ${delay.inSeconds}s: $error');
  ///   },
  /// );
  /// ```
  Future<T> execute<T>(
    Future<T> Function() operation, {
    void Function(int attempt, dynamic error, Duration delay)? onRetry,
  }) async {
    int attempt = 0;
    dynamic lastError;

    while (attempt < config.maxAttempts) {
      attempt++;

      try {
        return await operation();
      } catch (error) {
        lastError = error;

        // Check if we should retry this error
        if (config.retryIf != null && !config.retryIf!(error)) {
          rethrow;
        }

        // Don't retry if this was the last attempt
        if (attempt >= config.maxAttempts) {
          rethrow;
        }

        // Calculate delay for next retry
        final delay = _calculateDelay(attempt);

        // Call retry callback if provided
        onRetry?.call(attempt, error, delay);

        // Wait before retrying
        await Future.delayed(delay);
      }
    }

    // This should never be reached, but just in case
    throw lastError ?? Exception('Retry failed after $attempt attempts');
  }

  /// Execute function with retry logic and return result or null on failure
  ///
  /// Useful when you want to handle failures gracefully without throwing
  Future<T?> executeOrNull<T>(
    Future<T> Function() operation, {
    void Function(int attempt, dynamic error, Duration delay)? onRetry,
  }) async {
    try {
      return await execute(operation, onRetry: onRetry);
    } catch (e) {
      return null;
    }
  }

  /// Calculate delay for next retry using exponential backoff with jitter
  ///
  /// Formula: delay = min(maxDelay, initialDelay * (backoffMultiplier ^ (attempt - 1)))
  /// With jitter: delay = delay * (1 ± jitterFactor)
  Duration _calculateDelay(int attempt) {
    // Calculate exponential delay
    final exponentialDelay = config.initialDelay.inMilliseconds *
        pow(config.backoffMultiplier, attempt - 1);

    // Apply max delay cap
    final cappedDelay = min(exponentialDelay, config.maxDelay.inMilliseconds.toDouble());

    // Apply jitter to prevent thundering herd
    final jitter = config.jitterFactor > 0
        ? (_random.nextDouble() * 2 - 1) * config.jitterFactor
        : 0.0;

    final delayWithJitter = cappedDelay * (1 + jitter);

    return Duration(milliseconds: max(0, delayWithJitter.round()));
  }

  /// Get delay for specific attempt number (for testing/debugging)
  Duration getDelayForAttempt(int attempt) {
    return _calculateDelay(attempt);
  }
}

/// Retry strategy builder for custom configurations
class RetryStrategyBuilder {
  int _maxAttempts = 3;
  Duration _initialDelay = const Duration(seconds: 1);
  Duration _maxDelay = const Duration(seconds: 30);
  double _backoffMultiplier = 2.0;
  double _jitterFactor = 0.2;
  bool Function(dynamic error)? _retryIf;

  RetryStrategyBuilder maxAttempts(int attempts) {
    _maxAttempts = attempts;
    return this;
  }

  RetryStrategyBuilder initialDelay(Duration delay) {
    _initialDelay = delay;
    return this;
  }

  RetryStrategyBuilder maxDelay(Duration delay) {
    _maxDelay = delay;
    return this;
  }

  RetryStrategyBuilder backoffMultiplier(double multiplier) {
    _backoffMultiplier = multiplier;
    return this;
  }

  RetryStrategyBuilder jitterFactor(double factor) {
    _jitterFactor = factor;
    return this;
  }

  RetryStrategyBuilder retryIf(bool Function(dynamic error) predicate) {
    _retryIf = predicate;
    return this;
  }

  RetryStrategy build() {
    return RetryStrategy(
      RetryConfig(
        maxAttempts: _maxAttempts,
        initialDelay: _initialDelay,
        maxDelay: _maxDelay,
        backoffMultiplier: _backoffMultiplier,
        jitterFactor: _jitterFactor,
        retryIf: _retryIf,
      ),
    );
  }
}

/// Common retry predicates
class RetryPredicates {
  /// Retry on network errors only
  static bool networkErrorsOnly(dynamic error) {
    // Add logic to detect network errors
    return error.toString().toLowerCase().contains('network') ||
        error.toString().toLowerCase().contains('connection') ||
        error.toString().toLowerCase().contains('timeout');
  }

  /// Retry on server errors (5xx) but not client errors (4xx)
  static bool serverErrorsOnly(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504');
  }

  /// Never retry
  static bool never(dynamic error) => false;

  /// Always retry
  static bool always(dynamic error) => true;
}
