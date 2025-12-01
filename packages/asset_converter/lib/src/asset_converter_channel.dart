import 'dart:async';
import 'package:flutter/services.dart';

/// Platform channel contract for 3D asset conversion
///
/// Provides interface for:
/// - Converting USDZ to GLB format
/// - Extracting navmesh from USDZ
/// - Checking conversion capabilities
/// - Monitoring conversion progress
///
/// Platform-specific implementations:
/// - iOS: Uses Model I/O framework + custom navmesh extraction
/// - Android: Uses Filament + custom conversion pipeline
class AssetConverterChannel {
  /// Channel name for method calls
  static const String _channelName = 'one.vron.mobile/asset_converter';

  /// Event channel for conversion progress updates
  static const String _eventChannelName =
      'one.vron.mobile/asset_converter_events';

  /// Method channel for platform calls
  final MethodChannel _methodChannel = const MethodChannel(_channelName);

  /// Event channel for receiving conversion progress
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);

  Stream<ConversionProgress>? _progressStream;

  /// Check if USDZ to GLB conversion is supported on this device
  ///
  /// Returns true if:
  /// - iOS: Model I/O framework available (iOS 14+)
  /// - Android: Filament library loaded successfully
  ///
  /// Throws [PlatformException] if check fails
  Future<bool> isConversionSupported() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isConversionSupported',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw AssetConverterException(
        'Failed to check conversion support: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Get converter capabilities
  ///
  /// Returns map with:
  /// - supportsUSDZ: bool
  /// - supportsGLB: bool
  /// - supportsNavmesh: bool
  /// - maxFileSize: int (bytes)
  /// - supportedFormats: List<String>
  Future<Map<String, dynamic>> getCapabilities() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getCapabilities',
      );
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      throw AssetConverterException(
        'Failed to get capabilities: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Convert USDZ file to GLB format
  ///
  /// Parameters:
  /// - [usdzPath]: Path to input USDZ file
  /// - [glbPath]: Path where GLB file will be saved
  /// - [options]: Conversion options (optional)
  ///
  /// Returns: [ConversionResult] with output paths and metadata
  ///
  /// Throws:
  /// - [FileNotFoundException] if input file doesn't exist
  /// - [FileTooLargeException] if file exceeds 50MB limit
  /// - [ConversionFailedException] if conversion fails
  /// - [AssetConverterException] for other errors
  Future<ConversionResult> convertUsdzToGlb({
    required String usdzPath,
    required String glbPath,
    ConversionOptions? options,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'convertUsdzToGlb',
        {
          'usdzPath': usdzPath,
          'glbPath': glbPath,
          'options': options?.toMap() ?? {},
        },
      );

      if (result == null) {
        throw AssetConverterException('Conversion returned null result');
      }

      return ConversionResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      if (e.code == 'FILE_NOT_FOUND') {
        throw FileNotFoundException(e.message ?? 'File not found', usdzPath);
      } else if (e.code == 'FILE_TOO_LARGE') {
        throw FileTooLargeException(e.message ?? 'File too large');
      } else if (e.code == 'CONVERSION_FAILED') {
        throw ConversionFailedException(e.message ?? 'Conversion failed');
      }
      throw AssetConverterException(
        'Failed to convert USDZ to GLB: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Extract navigation mesh from USDZ file
  ///
  /// Parameters:
  /// - [usdzPath]: Path to input USDZ file
  /// - [navmeshPath]: Path where navmesh GLB will be saved
  /// - [options]: Navmesh extraction options (optional)
  ///
  /// Returns: [NavmeshResult] with output path and metadata
  ///
  /// Throws:
  /// - [FileNotFoundException] if input file doesn't exist
  /// - [NavmeshExtractionFailedException] if extraction fails
  /// - [AssetConverterException] for other errors
  Future<NavmeshResult> extractNavmesh({
    required String usdzPath,
    required String navmeshPath,
    NavmeshOptions? options,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'extractNavmesh',
        {
          'usdzPath': usdzPath,
          'navmeshPath': navmeshPath,
          'options': options?.toMap() ?? {},
        },
      );

      if (result == null) {
        throw AssetConverterException('Navmesh extraction returned null result');
      }

      return NavmeshResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      if (e.code == 'FILE_NOT_FOUND') {
        throw FileNotFoundException(e.message ?? 'File not found', usdzPath);
      } else if (e.code == 'NAVMESH_EXTRACTION_FAILED') {
        throw NavmeshExtractionFailedException(
          e.message ?? 'Navmesh extraction failed',
        );
      }
      throw AssetConverterException(
        'Failed to extract navmesh: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Cancel ongoing conversion
  ///
  /// Throws [AssetConverterException] if cancel fails
  Future<void> cancelConversion() async {
    try {
      await _methodChannel.invokeMethod<void>('cancelConversion');
    } on PlatformException catch (e) {
      throw AssetConverterException(
        'Failed to cancel conversion: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Generate navigation mesh from GLB file (v1 API)
  ///
  /// **iOS Only** - Uses Recast Navigation library for high-quality navmesh generation
  ///
  /// Parameters:
  /// - [glbPath]: Path to input GLB scene file
  /// - [navmeshPath]: Path where navmesh GLB will be saved
  /// - [agentHeight]: Agent height in meters (0.3 - 3.0)
  /// - [agentRadius]: Agent radius in meters (0.1 - 2.0)
  /// - [maxSlope]: Maximum walkable slope in degrees (0 - 60)
  ///
  /// Returns: [NavmeshGenerationResult] with vertex/triangle counts
  ///
  /// Throws:
  /// - [UnsupportedPlatformException] on Android (iOS only feature)
  /// - [FileNotFoundException] if input GLB doesn't exist
  /// - [InvalidGLBFormatException] if GLB file is corrupted
  /// - [InvalidParametersException] if agent parameters are invalid
  /// - [NoGeometryException] if no walkable surfaces found
  /// - [NavmeshGenerationFailedException] if generation fails
  /// - [AssetConverterException] for other errors
  ///
  /// Performance: Should complete in <15 seconds for typical room scans (~2000 vertices)
  Future<NavmeshGenerationResult> generateNavmesh({
    required String glbPath,
    required String navmeshPath,
    required double agentHeight,
    required double agentRadius,
    required double maxSlope,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'generateNavmesh_v1',
        {
          'glbPath': glbPath,
          'navmeshPath': navmeshPath,
          'agentHeight': agentHeight,
          'agentRadius': agentRadius,
          'maxSlope': maxSlope,
        },
      );

      if (result == null) {
        throw AssetConverterException('Navmesh generation returned null result');
      }

      return NavmeshGenerationResult.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'UNSUPPORTED_PLATFORM':
          throw UnsupportedPlatformException(
            e.message ?? 'Navmesh generation is only supported on iOS',
          );
        case 'FILE_NOT_FOUND':
          throw FileNotFoundException(e.message ?? 'GLB file not found', glbPath);
        case 'INVALID_GLB_FORMAT':
          throw InvalidGLBFormatException(
            e.message ?? 'Invalid or corrupted GLB file',
          );
        case 'INVALID_PARAMETERS':
          throw InvalidParametersException(
            e.message ?? 'Invalid agent parameters',
          );
        case 'NO_GEOMETRY':
          throw NoGeometryException(
            e.message ?? 'No walkable geometry found in scene',
          );
        case 'GENERATION_FAILED':
        case 'EXPORT_FAILED':
          throw NavmeshGenerationFailedException(
            e.message ?? 'Navmesh generation failed',
          );
        case 'CANCELLED':
          throw NavmeshGenerationCancelledException(
            e.message ?? 'Navmesh generation was cancelled',
          );
        default:
          throw AssetConverterException(
            'Failed to generate navmesh: ${e.message}',
            code: e.code,
          );
      }
    }
  }

  /// Cancel ongoing navmesh generation
  ///
  /// Throws [AssetConverterException] if cancel fails
  Future<void> cancelNavmeshGeneration() async {
    try {
      await _methodChannel.invokeMethod<void>('cancelNavmeshGeneration');
    } on PlatformException catch (e) {
      throw AssetConverterException(
        'Failed to cancel navmesh generation: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Stream of conversion progress updates
  ///
  /// Emits [ConversionProgress] objects with:
  /// - percentage: 0.0 to 1.0
  /// - stage: Current conversion stage
  /// - message: Status message
  Stream<ConversionProgress> get conversionProgress {
    _progressStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) =>
            ConversionProgress.fromMap(Map<String, dynamic>.from(event as Map)));

    return _progressStream!;
  }
}

/// Conversion options for USDZ to GLB
class ConversionOptions {
  /// Optimize for file size (may reduce quality)
  final bool optimizeSize;

  /// Include materials and textures
  final bool includeMaterials;

  /// Texture resolution (max dimension in pixels)
  final int? maxTextureSize;

  /// Compression level (0-9, higher = more compression)
  final int compressionLevel;

  const ConversionOptions({
    this.optimizeSize = false,
    this.includeMaterials = true,
    this.maxTextureSize,
    this.compressionLevel = 5,
  });

  Map<String, dynamic> toMap() {
    return {
      'optimizeSize': optimizeSize,
      'includeMaterials': includeMaterials,
      if (maxTextureSize != null) 'maxTextureSize': maxTextureSize,
      'compressionLevel': compressionLevel,
    };
  }
}

/// Navmesh extraction options
class NavmeshOptions {
  /// Simplification level (0.0-1.0, higher = more simplified)
  final double simplificationLevel;

  /// Minimum walkable surface area (square meters)
  final double minSurfaceArea;

  /// Maximum slope angle for walkable surfaces (degrees)
  final double maxSlopeAngle;

  const NavmeshOptions({
    this.simplificationLevel = 0.5,
    this.minSurfaceArea = 0.1,
    this.maxSlopeAngle = 45.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'simplificationLevel': simplificationLevel,
      'minSurfaceArea': minSurfaceArea,
      'maxSlopeAngle': maxSlopeAngle,
    };
  }
}

/// Result of USDZ to GLB conversion
class ConversionResult {
  /// Path to generated GLB file
  final String glbPath;

  /// Output file size in bytes
  final int fileSize;

  /// Conversion duration in milliseconds
  final int durationMs;

  /// Additional metadata
  final Map<String, dynamic> metadata;

  const ConversionResult({
    required this.glbPath,
    required this.fileSize,
    required this.durationMs,
    this.metadata = const {},
  });

  factory ConversionResult.fromMap(Map<String, dynamic> map) {
    return ConversionResult(
      glbPath: map['glbPath'] as String,
      fileSize: map['fileSize'] as int,
      durationMs: map['durationMs'] as int,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }
}

/// Result of navmesh extraction
class NavmeshResult {
  /// Path to generated navmesh GLB file
  final String navmeshPath;

  /// Output file size in bytes
  final int fileSize;

  /// Number of triangles in navmesh
  final int triangleCount;

  /// Total walkable surface area (square meters)
  final double surfaceArea;

  const NavmeshResult({
    required this.navmeshPath,
    required this.fileSize,
    required this.triangleCount,
    required this.surfaceArea,
  });

  factory NavmeshResult.fromMap(Map<String, dynamic> map) {
    return NavmeshResult(
      navmeshPath: map['navmeshPath'] as String,
      fileSize: map['fileSize'] as int,
      triangleCount: map['triangleCount'] as int,
      surfaceArea: (map['surfaceArea'] as num).toDouble(),
    );
  }
}

/// Conversion progress data
class ConversionProgress {
  /// Progress percentage (0.0 to 1.0)
  final double percentage;

  /// Current conversion stage
  final ConversionStage stage;

  /// Status message
  final String message;

  const ConversionProgress({
    required this.percentage,
    required this.stage,
    required this.message,
  });

  factory ConversionProgress.fromMap(Map<String, dynamic> map) {
    return ConversionProgress(
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
      stage: ConversionStage.values.firstWhere(
        (s) => s.name == map['stage'],
        orElse: () => ConversionStage.unknown,
      ),
      message: map['message'] as String? ?? '',
    );
  }
}

/// Conversion stages
enum ConversionStage {
  loading,
  parsing,
  converting,
  optimizing,
  saving,
  complete,
  unknown,
}

/// Base exception for asset converter errors
class AssetConverterException implements Exception {
  final String message;
  final String? code;

  const AssetConverterException(this.message, {this.code});

  @override
  String toString() {
    if (code != null) {
      return 'AssetConverterException [$code]: $message';
    }
    return 'AssetConverterException: $message';
  }
}

/// File not found exception
class FileNotFoundException extends AssetConverterException {
  final String filePath;

  const FileNotFoundException(String message, this.filePath)
      : super(message, code: 'FILE_NOT_FOUND');

  @override
  String toString() {
    return 'FileNotFoundException: File not found at "$filePath" - $message';
  }
}

/// File too large exception
class FileTooLargeException extends AssetConverterException {
  const FileTooLargeException(String message)
      : super(message, code: 'FILE_TOO_LARGE');
}

/// Conversion failed exception
class ConversionFailedException extends AssetConverterException {
  const ConversionFailedException(String message)
      : super(message, code: 'CONVERSION_FAILED');
}

/// Navmesh extraction failed exception
class NavmeshExtractionFailedException extends AssetConverterException {
  const NavmeshExtractionFailedException(String message)
      : super(message, code: 'NAVMESH_EXTRACTION_FAILED');
}

/// Navmesh generation result (v1 API)
class NavmeshGenerationResult {
  /// Whether generation succeeded
  final bool success;

  /// Number of vertices in generated navmesh
  final int vertexCount;

  /// Number of triangles in generated navmesh
  final int triangleCount;

  /// Optional error message if failed
  final String? errorMessage;

  const NavmeshGenerationResult({
    required this.success,
    required this.vertexCount,
    required this.triangleCount,
    this.errorMessage,
  });

  factory NavmeshGenerationResult.fromMap(Map<String, dynamic> map) {
    return NavmeshGenerationResult(
      success: map['success'] as bool? ?? false,
      vertexCount: map['vertexCount'] as int? ?? 0,
      triangleCount: map['triangleCount'] as int? ?? 0,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'vertexCount': vertexCount,
      'triangleCount': triangleCount,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }
}

/// Unsupported platform exception (feature not available on this platform)
class UnsupportedPlatformException extends AssetConverterException {
  const UnsupportedPlatformException(String message)
      : super(message, code: 'UNSUPPORTED_PLATFORM');
}

/// Invalid GLB format exception
class InvalidGLBFormatException extends AssetConverterException {
  const InvalidGLBFormatException(String message)
      : super(message, code: 'INVALID_GLB_FORMAT');
}

/// Invalid parameters exception
class InvalidParametersException extends AssetConverterException {
  const InvalidParametersException(String message)
      : super(message, code: 'INVALID_PARAMETERS');
}

/// No geometry exception (no walkable surfaces found)
class NoGeometryException extends AssetConverterException {
  const NoGeometryException(String message)
      : super(message, code: 'NO_GEOMETRY');
}

/// Navmesh generation failed exception
class NavmeshGenerationFailedException extends AssetConverterException {
  const NavmeshGenerationFailedException(String message)
      : super(message, code: 'GENERATION_FAILED');
}

/// Navmesh generation cancelled exception
class NavmeshGenerationCancelledException extends AssetConverterException {
  const NavmeshGenerationCancelledException(String message)
      : super(message, code: 'CANCELLED');
}
