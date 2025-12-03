// T188: Upload progress dialog
// Modal dialog showing chunked upload progress with detailed information

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vron_graphql_client/vron_graphql_client.dart';

/// Upload progress dialog showing detailed upload information
class UploadProgressDialog extends ConsumerStatefulWidget {
  final String roomId;
  final List<String> fileTypes; // ['SCENE_GLB', 'NAVMESH_GLB']

  const UploadProgressDialog({
    super.key,
    required this.roomId,
    required this.fileTypes,
  });

  @override
  ConsumerState<UploadProgressDialog> createState() =>
      _UploadProgressDialogState();
}

class _UploadProgressDialogState extends ConsumerState<UploadProgressDialog> {
  @override
  Widget build(BuildContext context) {
    // Watch upload states for all file types
    final uploadStates = widget.fileTypes
        .map((fileType) =>
            ref.watch(uploadStateProvider((widget.roomId, fileType))))
        .whereType<UploadState>() // Filter out nulls
        .toList();

    // Check if all uploads are complete
    final allComplete = uploadStates.isNotEmpty &&
        uploadStates.every((state) => state.status == UploadStatus.completed);

    final anyFailed =
        uploadStates.any((state) => state.status == UploadStatus.failed);

    return WillPopScope(
      onWillPop: () async {
        // Prevent dismissing during upload
        return allComplete || anyFailed;
      },
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              allComplete
                  ? Icons.check_circle
                  : anyFailed
                      ? Icons.error
                      : Icons.cloud_upload,
              color: allComplete
                  ? Colors.green
                  : anyFailed
                      ? Colors.red
                      : Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                allComplete
                    ? 'Upload Complete'
                    : anyFailed
                        ? 'Upload Failed'
                        : 'Uploading Files',
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (uploadStates.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Preparing upload...'),
                  ),
                )
              else
                ...uploadStates.map((state) => _buildFileProgress(state)),
              if (anyFailed) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Upload failed. You can retry from the upload queue.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (allComplete) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'All files uploaded successfully!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!allComplete && !anyFailed)
            TextButton(
              onPressed: () {
                // Background upload will continue
                Navigator.of(context).pop(false);
              },
              child: const Text('Continue in Background'),
            ),
          if (allComplete || anyFailed)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(allComplete);
              },
              child: Text(allComplete ? 'Done' : 'Close'),
            ),
        ],
      ),
    );
  }

  Widget _buildFileProgress(UploadState state) {
    final progressPercent = (state.progress * 100).toStringAsFixed(1);
    final isUploading = state.status == UploadStatus.uploading;
    final isFailed = state.status == UploadStatus.failed;
    final isCompleted = state.status == UploadStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFailed
              ? Colors.red.shade200
              : isCompleted
                  ? Colors.green.shade200
                  : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getFileTypeIcon(state.fileType),
                size: 20,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getFileTypeLabel(state.fileType),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isCompleted)
                Icon(Icons.check_circle, color: Colors.green, size: 20),
              if (isFailed)
                Icon(Icons.error, color: Colors.red, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: state.progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              isFailed
                  ? Colors.red
                  : isCompleted
                      ? Colors.green
                      : Colors.blue,
            ),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getStatusText(state.status),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                isUploading ? '$progressPercent%' : '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  IconData _getFileTypeIcon(FileType fileType) {
    switch (fileType) {
      case FileType.sceneGlb:
        return Icons.view_in_ar;
      case FileType.navmeshGlb:
        return Icons.map;
    }
  }

  String _getFileTypeLabel(FileType fileType) {
    switch (fileType) {
      case FileType.sceneGlb:
        return 'Scene GLB';
      case FileType.navmeshGlb:
        return 'Navigation Mesh';
    }
  }

  String _getStatusText(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return 'Queued...';
      case UploadStatus.uploading:
        return 'Uploading...';
      case UploadStatus.completed:
        return 'Complete';
      case UploadStatus.failed:
        return 'Failed';
    }
  }
}

/// Show upload progress dialog
Future<bool?> showUploadProgressDialog(
  BuildContext context, {
  required String roomId,
  required List<String> fileTypes,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => UploadProgressDialog(
      roomId: roomId,
      fileTypes: fileTypes,
    ),
  );
}
