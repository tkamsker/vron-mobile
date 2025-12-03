// T174: Riverpod provider for UploadDatabase
// Provides singleton access to upload database across the app

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'upload_database.dart';

/// Global provider for the upload database
/// Automatically disposes database on provider disposal
final uploadDatabaseProvider = Provider<UploadDatabase>((ref) {
  final database = UploadDatabase();

  // Close database when provider is disposed
  ref.onDispose(() {
    database.close();
  });

  return database;
});
