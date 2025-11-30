/// Base exception class for all app exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write(runtimeType.toString())
      ..write(': ')
      ..write(message);

    if (code != null) {
      buffer.write(' (Code: $code)');
    }

    return buffer.toString();
  }
}

// ============================================================================
// GraphQL Exceptions (T033)
// ============================================================================

/// Base class for GraphQL-related exceptions
abstract class GraphQLException extends AppException {
  const GraphQLException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Authentication error from GraphQL API
class AuthenticationException extends GraphQLException {
  const AuthenticationException(
    super.message, {
    super.code = 'UNAUTHENTICATED',
    super.originalError,
    super.stackTrace,
  });
}

/// Authorization error from GraphQL API (insufficient permissions)
class AuthorizationException extends GraphQLException {
  const AuthorizationException(
    super.message, {
    super.code = 'FORBIDDEN',
    super.originalError,
    super.stackTrace,
  });
}

/// Resource not found error from GraphQL API
class NotFoundException extends GraphQLException {
  const NotFoundException(
    super.message, {
    super.code = 'NOT_FOUND',
    super.originalError,
    super.stackTrace,
  });
}

/// Input validation error from GraphQL API
class ValidationException extends GraphQLException {
  final Map<String, List<String>>? validationErrors;

  const ValidationException(
    super.message, {
    super.code = 'VALIDATION_ERROR',
    this.validationErrors,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer()..write(super.toString());

    if (validationErrors != null && validationErrors!.isNotEmpty) {
      buffer.write('\nValidation errors:');
      validationErrors!.forEach((field, errors) {
        buffer.write('\n  $field: ${errors.join(', ')}');
      });
    }

    return buffer.toString();
  }
}

/// File too large error from GraphQL API
class FileTooLargeException extends GraphQLException {
  final int fileSize;
  final int maxSize;

  const FileTooLargeException(
    super.message, {
    super.code = 'FILE_TOO_LARGE',
    required this.fileSize,
    required this.maxSize,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    return '$runtimeType: $message (File size: ${_formatBytes(fileSize)}, Max allowed: ${_formatBytes(maxSize)})';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Rate limit exceeded error from GraphQL API
class RateLimitException extends GraphQLException {
  final int? retryAfterSeconds;

  const RateLimitException(
    super.message, {
    super.code = 'RATE_LIMIT_EXCEEDED',
    this.retryAfterSeconds,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer()..write(super.toString());
    if (retryAfterSeconds != null) {
      buffer.write(' (Retry after $retryAfterSeconds seconds)');
    }
    return buffer.toString();
  }
}

/// Server error from GraphQL API
class ServerException extends GraphQLException {
  const ServerException(
    super.message, {
    super.code = 'INTERNAL_SERVER_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Network error (no internet connection, timeout, etc.)
class NetworkException extends GraphQLException {
  const NetworkException(
    super.message, {
    super.code = 'NETWORK_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

// ============================================================================
// Platform Channel Exceptions (T034)
// ============================================================================

/// Base class for platform channel exceptions
abstract class PlatformChannelException extends AppException {
  const PlatformChannelException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Platform method not implemented
class MethodNotImplementedException extends PlatformChannelException {
  final String methodName;

  const MethodNotImplementedException(
    super.message, {
    required this.methodName,
    super.code = 'METHOD_NOT_IMPLEMENTED',
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    return '$runtimeType: Method "$methodName" not implemented on platform';
  }
}

/// Platform method call failed
class PlatformMethodException extends PlatformChannelException {
  final String methodName;

  const PlatformMethodException(
    super.message, {
    required this.methodName,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    return '$runtimeType: Failed to call method "$methodName": $message';
  }
}

/// LiDAR scanning error
class LidarScanException extends PlatformChannelException {
  const LidarScanException(
    super.message, {
    super.code = 'LIDAR_SCAN_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// LiDAR not available on device
class LidarNotAvailableException extends PlatformChannelException {
  const LidarNotAvailableException(
    super.message, {
    super.code = 'LIDAR_NOT_AVAILABLE',
    super.originalError,
    super.stackTrace,
  });
}

/// USDZ to GLB conversion error
class ConversionException extends PlatformChannelException {
  final String sourceFormat;
  final String targetFormat;

  const ConversionException(
    super.message, {
    required this.sourceFormat,
    required this.targetFormat,
    super.code = 'CONVERSION_ERROR',
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    return '$runtimeType: Failed to convert $sourceFormat to $targetFormat: $message';
  }
}

/// Camera/AR permission denied
class PermissionDeniedException extends PlatformChannelException {
  final String permission;

  const PermissionDeniedException(
    super.message, {
    required this.permission,
    super.code = 'PERMISSION_DENIED',
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    return '$runtimeType: Permission "$permission" denied: $message';
  }
}

// ============================================================================
// Storage & File Exceptions
// ============================================================================

/// File system exception
class FileSystemException extends AppException {
  final String? filePath;

  const FileSystemException(
    super.message, {
    this.filePath,
    super.code = 'FILE_SYSTEM_ERROR',
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer()..write(super.toString());
    if (filePath != null) {
      buffer.write(' (Path: $filePath)');
    }
    return buffer.toString();
  }
}

/// Insufficient storage space
class InsufficientStorageException extends FileSystemException {
  final int requiredBytes;
  final int availableBytes;

  const InsufficientStorageException(
    super.message, {
    required this.requiredBytes,
    required this.availableBytes,
    super.filePath,
    super.code = 'INSUFFICIENT_STORAGE',
    super.originalError,
    super.stackTrace,
  });
}

// ============================================================================
// Cache Exceptions
// ============================================================================

/// Cache exception
class CacheException extends AppException {
  const CacheException(
    super.message, {
    super.code = 'CACHE_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Database exception
class DatabaseException extends AppException {
  const DatabaseException(
    super.message, {
    super.code = 'DATABASE_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

// ============================================================================
// Upload Exceptions
// ============================================================================

/// Upload exception
class UploadException extends AppException {
  final String? fileId;
  final int? uploadedBytes;
  final int? totalBytes;

  const UploadException(
    super.message, {
    this.fileId,
    this.uploadedBytes,
    this.totalBytes,
    super.code = 'UPLOAD_ERROR',
    super.originalError,
    super.stackTrace,
  });

  /// Calculate upload progress percentage
  double? get progressPercentage {
    if (uploadedBytes == null || totalBytes == null || totalBytes == 0) {
      return null;
    }
    return (uploadedBytes! / totalBytes!) * 100;
  }
}
