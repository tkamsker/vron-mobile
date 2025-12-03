// T175-T179: Upload service provider
// Provides UploadService with database dependency injection

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../database/database_provider.dart';
import 'upload_service.dart';

/// Provider for the upload service
/// Depends on uploadDatabaseProvider for persistence
final uploadServiceProvider = Provider<UploadService>((ref) {
  final database = ref.watch(uploadDatabaseProvider);
  final logger = Logger();

  return UploadService(
    database: database,
    logger: logger,
  );
});
