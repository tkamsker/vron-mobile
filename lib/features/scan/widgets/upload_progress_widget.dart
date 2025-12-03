// T185: Upload progress widget
// Shows real-time upload progress with percentage and status

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vron_graphql_client/vron_graphql_client.dart';

/// Upload progress widget showing real-time upload status
class UploadProgressWidget extends ConsumerWidget {
  final String roomId;
  final String fileType;
  final bool showDetails;

  const UploadProgressWidget({
    super.key,
    required this.roomId,
    required this.fileType,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(
      uploadStateProvider((roomId, fileType)),
    );

    if (uploadState == null) {
      return const SizedBox.shrink();
    }

    return _buildProgressCard(context, uploadState);
  }

  Widget _buildProgressCard(BuildContext context, UploadState uploadState) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(uploadState.status);
    final statusIcon = _getStatusIcon(uploadState.status);
    final progressPercent = (uploadState.progress * 100).toStringAsFixed(1);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            Row(
              children: [
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusText(uploadState.status),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                if (uploadState.status == UploadStatus.uploading)
                  Text(
                    '$progressPercent%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryColor,
                    ),
                  ),
              ],
            ),

            if (showDetails && uploadState.status == UploadStatus.uploading) ...[
              const SizedBox(height: 12),

              // Progress bar
              LinearProgressIndicator(
                value: uploadState.progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),

              const SizedBox(height: 8),

              // File type label
              Text(
                _getFileTypeLabel(uploadState.fileType),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],

            // Error message
            if (uploadState.status == UploadStatus.failed && uploadState.error != null) ...[
              const SizedBox(height: 8),
              Text(
                uploadState.error!,
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
      ),
    );
  }

  Color _getStatusColor(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return Colors.orange;
      case UploadStatus.uploading:
        return Colors.blue;
      case UploadStatus.completed:
        return Colors.green;
      case UploadStatus.failed:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return Icons.schedule;
      case UploadStatus.uploading:
        return Icons.cloud_upload;
      case UploadStatus.completed:
        return Icons.check_circle;
      case UploadStatus.failed:
        return Icons.error;
    }
  }

  String _getStatusText(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return 'Upload queued';
      case UploadStatus.uploading:
        return 'Uploading...';
      case UploadStatus.completed:
        return 'Upload complete';
      case UploadStatus.failed:
        return 'Upload failed';
    }
  }

  String _getFileTypeLabel(FileType fileType) {
    switch (fileType) {
      case FileType.sceneGlb:
        return 'Scene GLB file';
      case FileType.navmeshGlb:
        return 'Navigation mesh file';
    }
  }
}

/// Compact upload progress indicator for inline use
class CompactUploadProgress extends ConsumerWidget {
  final String roomId;
  final String fileType;

  const CompactUploadProgress({
    super.key,
    required this.roomId,
    required this.fileType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(
      uploadStateProvider((roomId, fileType)),
    );

    if (uploadState == null || uploadState.status == UploadStatus.completed) {
      return const SizedBox.shrink();
    }

    final progressPercent = (uploadState.progress * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(uploadState.status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              value: uploadState.status == UploadStatus.uploading
                  ? uploadState.progress
                  : null,
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getStatusColor(uploadState.status),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            uploadState.status == UploadStatus.uploading
                ? '$progressPercent%'
                : _getStatusText(uploadState.status),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _getStatusColor(uploadState.status),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return Colors.orange;
      case UploadStatus.uploading:
        return Colors.blue;
      case UploadStatus.completed:
        return Colors.green;
      case UploadStatus.failed:
        return Colors.red;
    }
  }

  String _getStatusText(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return 'Queued';
      case UploadStatus.uploading:
        return 'Uploading';
      case UploadStatus.completed:
        return 'Done';
      case UploadStatus.failed:
        return 'Failed';
    }
  }
}
