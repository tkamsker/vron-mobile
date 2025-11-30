import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../errors/app_exceptions.dart';

/// File utilities for temporary file management
///
/// Handles:
/// - Creating temp directories
/// - Managing temp file lifecycle
/// - Cleaning up old files
/// - Calculating file sizes
/// - Checking storage space
class FileUtils {
  /// Get temp directory for the app
  static Future<Directory> getTempDirectory() async {
    return await getTemporaryDirectory();
  }

  /// Get app documents directory
  static Future<Directory> getAppDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Get app support directory
  static Future<Directory> getAppSupportDirectory() async {
    return await getApplicationSupportDirectory();
  }

  /// Create temp directory for scans
  static Future<Directory> createScanTempDirectory() async {
    final tempDir = await getTempDirectory();
    final scanDir = Directory(p.join(tempDir.path, 'scans'));

    if (!await scanDir.exists()) {
      await scanDir.create(recursive: true);
    }

    return scanDir;
  }

  /// Create temp directory for conversions
  static Future<Directory> createConversionTempDirectory() async {
    final tempDir = await getTempDirectory();
    final conversionDir = Directory(p.join(tempDir.path, 'conversions'));

    if (!await conversionDir.exists()) {
      await conversionDir.create(recursive: true);
    }

    return conversionDir;
  }

  /// Create temp directory for uploads
  static Future<Directory> createUploadTempDirectory() async {
    final tempDir = await getTempDirectory();
    final uploadDir = Directory(p.join(tempDir.path, 'uploads'));

    if (!await uploadDir.exists()) {
      await uploadDir.create(recursive: true);
    }

    return uploadDir;
  }

  /// Create unique temp file path with extension
  ///
  /// Usage:
  /// ```dart
  /// final path = await FileUtils.createTempFilePath('glb');
  /// // Returns: /temp/12345678-1234-1234-1234-123456789abc.glb
  /// ```
  static Future<String> createTempFilePath(String extension) async {
    final tempDir = await getTempDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = timestamp.toString();
    final fileName = '$randomSuffix.$extension';
    return p.join(tempDir.path, fileName);
  }

  /// Get file size in bytes
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException(
          'File does not exist',
          filePath: filePath,
        );
      }
      return await file.length();
    } catch (e) {
      throw FileSystemException(
        'Failed to get file size: $e',
        filePath: filePath,
        originalError: e,
      );
    }
  }

  /// Get human-readable file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Check if file exists
  static Future<bool> fileExists(String filePath) async {
    return await File(filePath).exists();
  }

  /// Delete file
  static Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw FileSystemException(
        'Failed to delete file: $e',
        filePath: filePath,
        originalError: e,
      );
    }
  }

  /// Delete directory recursively
  static Future<void> deleteDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      throw FileSystemException(
        'Failed to delete directory: $e',
        filePath: dirPath,
        originalError: e,
      );
    }
  }

  /// Clean temp directory (delete old files)
  ///
  /// Deletes files older than specified duration
  static Future<int> cleanTempDirectory({
    Duration olderThan = const Duration(days: 1),
  }) async {
    int deletedCount = 0;

    try {
      final tempDir = await getTempDirectory();
      final now = DateTime.now();

      await for (final entity in tempDir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);

          if (age > olderThan) {
            try {
              await entity.delete();
              deletedCount++;
            } catch (e) {
              // Ignore deletion errors for individual files
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors during cleanup
    }

    return deletedCount;
  }

  /// Get available storage space in bytes
  ///
  /// Note: This is an approximation on mobile platforms
  static Future<int> getAvailableStorageBytes() async {
    try {
      // This is a placeholder - actual implementation would use
      // platform-specific code to get available storage

      // Return a large number as placeholder
      // In production, implement proper storage check via platform channels
      return 1024 * 1024 * 1024 * 10; // 10 GB placeholder
    } catch (e) {
      return 0;
    }
  }

  /// Check if enough storage space is available
  static Future<bool> hasEnoughStorage(int requiredBytes) async {
    final availableBytes = await getAvailableStorageBytes();
    return availableBytes >= requiredBytes;
  }

  /// Ensure enough storage or throw exception
  static Future<void> ensureEnoughStorage(int requiredBytes) async {
    final availableBytes = await getAvailableStorageBytes();

    if (availableBytes < requiredBytes) {
      throw InsufficientStorageException(
        'Not enough storage space available',
        requiredBytes: requiredBytes,
        availableBytes: availableBytes,
      );
    }
  }

  /// Copy file to destination
  static Future<void> copyFile(String sourcePath, String destPath) async {
    try {
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        throw FileSystemException(
          'Source file does not exist',
          filePath: sourcePath,
        );
      }

      // Ensure destination directory exists
      final destDir = Directory(p.dirname(destPath));
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      await sourceFile.copy(destPath);
    } catch (e) {
      throw FileSystemException(
        'Failed to copy file: $e',
        filePath: sourcePath,
        originalError: e,
      );
    }
  }

  /// Move file to destination
  static Future<void> moveFile(String sourcePath, String destPath) async {
    try {
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        throw FileSystemException(
          'Source file does not exist',
          filePath: sourcePath,
        );
      }

      // Ensure destination directory exists
      final destDir = Directory(p.dirname(destPath));
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      await sourceFile.rename(destPath);
    } catch (e) {
      throw FileSystemException(
        'Failed to move file: $e',
        filePath: sourcePath,
        originalError: e,
      );
    }
  }

  /// Get directory size in bytes (recursive)
  static Future<int> getDirectorySize(String dirPath) async {
    int totalSize = 0;

    try {
      final dir = Directory(dirPath);

      if (!await dir.exists()) {
        return 0;
      }

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (e) {
            // Ignore errors for individual files
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }

    return totalSize;
  }

  /// List files in directory
  static Future<List<File>> listFiles(
    String dirPath, {
    bool recursive = false,
    String? extension,
  }) async {
    final files = <File>[];

    try {
      final dir = Directory(dirPath);

      if (!await dir.exists()) {
        return files;
      }

      await for (final entity in dir.list(recursive: recursive)) {
        if (entity is File) {
          if (extension == null || p.extension(entity.path) == '.$extension') {
            files.add(entity);
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }

    return files;
  }

  /// Get file extension without dot
  static String getFileExtension(String filePath) {
    final ext = p.extension(filePath);
    return ext.startsWith('.') ? ext.substring(1) : ext;
  }

  /// Get file name without extension
  static String getFileNameWithoutExtension(String filePath) {
    return p.basenameWithoutExtension(filePath);
  }

  /// Get file name with extension
  static String getFileName(String filePath) {
    return p.basename(filePath);
  }
}
