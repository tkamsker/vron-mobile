// T180-T184: Upload notifier provider
// Provides UploadNotifier with dependency injection

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../database/database_provider.dart';
import '../services/upload_service_provider.dart';
import 'upload_notifier.dart';

/// Provider for upload notifier
/// Manages upload workflow state and orchestration
final uploadNotifierProvider = StateNotifierProvider<UploadNotifier, Map<String, UploadState>>((ref) {
  final uploadService = ref.watch(uploadServiceProvider);
  final database = ref.watch(uploadDatabaseProvider);
  final logger = Logger();

  return UploadNotifier(
    uploadService: uploadService,
    database: database,
    logger: logger,
  );
});

/// Watch upload state for a specific room and file type
final uploadStateProvider = Provider.family<UploadState?, (String, String)>((ref, params) {
  final (roomId, fileType) = params;
  final key = '${roomId}_$fileType';
  final allStates = ref.watch(uploadNotifierProvider);
  return allStates[key];
});
