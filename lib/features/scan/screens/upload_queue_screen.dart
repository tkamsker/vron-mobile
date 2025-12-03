// T186: Upload queue screen
// Shows all pending and failed uploads with retry capability

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vron_graphql_client/vron_graphql_client.dart';

/// Upload queue screen showing all uploads
class UploadQueueScreen extends ConsumerWidget {
  const UploadQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(uploadDatabaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _clearCompleted(context, ref),
            tooltip: 'Clear completed',
          ),
        ],
      ),
      body: FutureBuilder<List<UploadQueueEntry>>(
        future: database.getAllUploads(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading uploads',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final uploads = snapshot.data ?? [];

          if (uploads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_done,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No uploads in queue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All your uploads have been processed',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group uploads by status
          final pending = uploads.where((u) => u.status == 'pending').toList();
          final uploading = uploads.where((u) => u.status == 'uploading').toList();
          final failed = uploads.where((u) => u.status == 'failed').toList();
          final completed = uploads.where((u) => u.status == 'completed').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (uploading.isNotEmpty) ...[
                _buildSectionHeader('Uploading', uploading.length, Colors.blue),
                ...uploading.map((upload) => _buildUploadTile(context, ref, upload)),
                const SizedBox(height: 16),
              ],
              if (pending.isNotEmpty) ...[
                _buildSectionHeader('Queued', pending.length, Colors.orange),
                ...pending.map((upload) => _buildUploadTile(context, ref, upload)),
                const SizedBox(height: 16),
              ],
              if (failed.isNotEmpty) ...[
                _buildSectionHeader('Failed', failed.length, Colors.red),
                ...failed.map((upload) => _buildUploadTile(context, ref, upload)),
                const SizedBox(height: 16),
              ],
              if (completed.isNotEmpty) ...[
                _buildSectionHeader('Completed', completed.length, Colors.green),
                ...completed.map((upload) => _buildUploadTile(context, ref, upload)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$title ($count)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTile(
    BuildContext context,
    WidgetRef ref,
    UploadQueueEntry upload,
  ) {
    final statusColor = _getStatusColor(upload.status);
    final progress = upload.uploadedBytes / upload.fileSize;
    final progressPercent = (progress * 100).toStringAsFixed(1);
    final fileSizeMB = (upload.fileSize / (1024 * 1024)).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(
            _getStatusIcon(upload.status),
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          upload.fileType,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Room: ${upload.roomId}'),
            const SizedBox(height: 4),
            if (upload.status == 'uploading') ...[
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 4),
              Text(
                '$progressPercent% • ${fileSizeMB}MB',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ] else
              Text(
                '$fileSizeMB MB',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            if (upload.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                upload.errorMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: _buildTrailingAction(context, ref, upload),
      ),
    );
  }

  Widget? _buildTrailingAction(
    BuildContext context,
    WidgetRef ref,
    UploadQueueEntry upload,
  ) {
    final notifier = ref.read(uploadNotifierProvider.notifier);

    switch (upload.status) {
      case 'failed':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _retryUpload(context, ref, upload),
              tooltip: 'Retry',
              color: Colors.blue,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteUpload(context, ref, upload),
              tooltip: 'Delete',
              color: Colors.red,
            ),
          ],
        );
      case 'completed':
        return IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _deleteUpload(context, ref, upload),
          tooltip: 'Delete',
          color: Colors.grey,
        );
      case 'uploading':
        return Text(
          '${(upload.uploadedBytes / upload.fileSize * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        );
      default:
        return null;
    }
  }

  Future<void> _retryUpload(
    BuildContext context,
    WidgetRef ref,
    UploadQueueEntry upload,
  ) async {
    try {
      final notifier = ref.read(uploadNotifierProvider.notifier);
      final fileType = FileTypeExtension.fromGraphql(upload.fileType);

      await notifier.retryUpload(upload.roomId, fileType);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload resumed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to retry: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteUpload(
    BuildContext context,
    WidgetRef ref,
    UploadQueueEntry upload,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Upload'),
        content: const Text('Are you sure you want to delete this upload?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final database = ref.read(uploadDatabaseProvider);
      await database.deleteUpload(upload.id);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload deleted'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearCompleted(BuildContext context, WidgetRef ref) async {
    final database = ref.read(uploadDatabaseProvider);
    final deleted = await database.deleteOldCompletedUploads(DateTime.now());

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cleared $deleted completed uploads'),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'uploading':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'uploading':
        return Icons.cloud_upload;
      case 'completed':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      default:
        return Icons.cloud_queue;
    }
  }
}
