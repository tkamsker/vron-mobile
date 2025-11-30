import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// App logger configuration
class AppLoggerConfig {
  /// Enable logging
  final bool enabled;

  /// Log level filter
  final Level level;

  /// Print time in logs
  final bool printTime;

  /// Print emojis in logs
  final bool printEmojis;

  /// Print colors in logs
  final bool printColors;

  /// Number of method calls to print in stack trace
  final int methodCount;

  /// Number of error method calls to print
  final int errorMethodCount;

  /// Line length for logs
  final int lineLength;

  const AppLoggerConfig({
    this.enabled = true,
    this.level = Level.debug,
    this.printTime = true,
    this.printEmojis = true,
    this.printColors = true,
    this.methodCount = 0,
    this.errorMethodCount = 5,
    this.lineLength = 120,
  });

  /// Development config (verbose logging)
  static const development = AppLoggerConfig(
    enabled: true,
    level: Level.trace,
    printTime: true,
    printEmojis: true,
    printColors: true,
  );

  /// Production config (minimal logging)
  static const production = AppLoggerConfig(
    enabled: true,
    level: Level.warning,
    printTime: false,
    printEmojis: false,
    printColors: false,
    methodCount: 0,
    errorMethodCount: 3,
  );

  /// Test config (no logging)
  static const test = AppLoggerConfig(
    enabled: false,
    level: Level.off,
  );
}

/// App logger wrapper
///
/// Provides structured logging with different levels:
/// - trace: Finest-grained information (e.g., method entry/exit)
/// - debug: Detailed information for debugging
/// - info: Informational messages (e.g., app lifecycle events)
/// - warning: Warnings about potentially harmful situations
/// - error: Errors that might allow app to continue running
/// - fatal: Severe errors that might cause app to crash
///
/// Usage:
/// ```dart
/// final logger = ref.read(appLoggerProvider);
/// logger.info('User signed in', data: {'userId': userId});
/// logger.error('Failed to upload file', error: e, stackTrace: st);
/// ```
class AppLogger {
  final Logger _logger;
  final AppLoggerConfig _config;

  AppLogger(this._config)
      : _logger = Logger(
          filter: _AppLogFilter(_config),
          printer: PrettyPrinter(
            methodCount: _config.methodCount,
            errorMethodCount: _config.errorMethodCount,
            lineLength: _config.lineLength,
            colors: _config.printColors,
            printEmojis: _config.printEmojis,
            dateTimeFormat: _config.printTime
                ? DateTimeFormat.onlyTimeAndSinceStart
                : DateTimeFormat.none,
            excludeBox: const {},
            noBoxingByDefault: false,
          ),
        );

  /// Log trace message (finest-grained)
  void trace(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    if (!_config.enabled) return;
    final formattedMessage = _formatMessage(message, data);
    _logger.t(formattedMessage, time: time, error: error, stackTrace: stackTrace);
  }

  /// Log debug message
  void debug(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    if (!_config.enabled) return;
    final formattedMessage = _formatMessage(message, data);
    _logger.d(formattedMessage, time: time, error: error, stackTrace: stackTrace);
  }

  /// Log info message
  void info(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    if (!_config.enabled) return;
    final formattedMessage = _formatMessage(message, data);
    _logger.i(formattedMessage, time: time, error: error, stackTrace: stackTrace);
  }

  /// Log warning message
  void warning(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    if (!_config.enabled) return;
    final formattedMessage = _formatMessage(message, data);
    _logger.w(formattedMessage, time: time, error: error, stackTrace: stackTrace);
  }

  /// Log error message
  void error(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    if (!_config.enabled) return;
    final formattedMessage = _formatMessage(message, data);
    _logger.e(formattedMessage, time: time, error: error, stackTrace: stackTrace);
  }

  /// Log fatal error message
  void fatal(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    if (!_config.enabled) return;
    final formattedMessage = _formatMessage(message, data);
    _logger.f(formattedMessage, time: time, error: error, stackTrace: stackTrace);
  }

  /// Format message with additional data
  String _formatMessage(dynamic message, Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return message.toString();
    }

    final buffer = StringBuffer()
      ..write(message.toString())
      ..write(' | ');

    final entries = data.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.write('${entry.key}: ${entry.value}');
      if (i < entries.length - 1) {
        buffer.write(', ');
      }
    }

    return buffer.toString();
  }

  /// Close logger (cleanup resources)
  void close() {
    _logger.close();
  }
}

/// Custom log filter
class _AppLogFilter extends LogFilter {
  final AppLoggerConfig config;

  _AppLogFilter(this.config);

  @override
  bool shouldLog(LogEvent event) {
    if (!config.enabled) return false;

    // Filter by log level
    return event.level.index >= config.level.index;
  }
}

/// App logger provider
final appLoggerProvider = Provider<AppLogger>((ref) {
  // Use development config in debug mode, production in release
  final config = kDebugMode
      ? AppLoggerConfig.development
      : AppLoggerConfig.production;

  final logger = AppLogger(config);

  // Ensure logger is closed when provider is disposed
  ref.onDispose(() {
    logger.close();
  });

  return logger;
});

/// Module-specific logger providers
///
/// Usage:
/// ```dart
/// final logger = ref.read(authLoggerProvider);
/// logger.info('User signed in');
/// ```
final authLoggerProvider = Provider<AppLogger>((ref) {
  return ref.watch(appLoggerProvider);
});

final networkLoggerProvider = Provider<AppLogger>((ref) {
  return ref.watch(appLoggerProvider);
});

final databaseLoggerProvider = Provider<AppLogger>((ref) {
  return ref.watch(appLoggerProvider);
});

final uploadLoggerProvider = Provider<AppLogger>((ref) {
  return ref.watch(appLoggerProvider);
});

final scanLoggerProvider = Provider<AppLogger>((ref) {
  return ref.watch(appLoggerProvider);
});

/// Log extension for easy logging from any widget
extension LogExtension on WidgetRef {
  AppLogger get log => read(appLoggerProvider);
}
