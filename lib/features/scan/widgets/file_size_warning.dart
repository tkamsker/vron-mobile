import 'package:flutter/material.dart';

/// File size warning dialog
///
/// Displays a warning when the scan file size approaches or exceeds the 50MB limit.
/// This helps users manage storage and understand upload constraints.
class FileSizeWarning {
  /// Maximum recommended file size in bytes (50MB)
  static const int maxRecommendedSize = 50 * 1024 * 1024; // 50MB

  /// Warning threshold (80% of max = 40MB)
  static const int warningThreshold = (maxRecommendedSize * 0.8).toInt();

  /// Show warning dialog if file size approaches or exceeds limit
  ///
  /// Parameters:
  /// - [context]: Build context for showing dialog
  /// - [currentSize]: Current file size in bytes
  /// - [onContinue]: Callback when user chooses to continue
  /// - [onCancel]: Callback when user chooses to cancel
  static Future<bool?> showIfNeeded({
    required BuildContext context,
    required int currentSize,
    VoidCallback? onContinue,
    VoidCallback? onCancel,
  }) async {
    // Only show warning if size is above threshold
    if (currentSize < warningThreshold) {
      return true; // Proceed without warning
    }

    final sizeMB = currentSize / (1024 * 1024);
    final isOverLimit = currentSize >= maxRecommendedSize;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isOverLimit ? Icons.error : Icons.warning,
              color: isOverLimit ? Colors.red : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isOverLimit ? 'File Size Limit Exceeded' : 'Large File Warning',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOverLimit
                  ? 'The current scan size is ${sizeMB.toStringAsFixed(1)}MB, which exceeds the recommended 50MB limit.'
                  : 'The current scan size is ${sizeMB.toStringAsFixed(1)}MB, approaching the 50MB limit.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Large files may:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildBulletPoint('Take longer to upload'),
            _buildBulletPoint('Consume more storage space'),
            _buildBulletPoint('May fail on slow connections'),
            if (isOverLimit) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  'Consider rescanning with lower detail settings or smaller area.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!isOverLimit)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
                onCancel?.call();
              },
              child: const Text('Cancel Scan'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              onContinue?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isOverLimit ? Colors.red : null,
            ),
            child: Text(
              isOverLimit ? 'Continue Anyway' : 'Continue',
            ),
          ),
        ],
      ),
    );
  }

  /// Format file size for display
  static String formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    } else {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    }
  }

  /// Check if file size is within acceptable range
  static bool isWithinLimit(int bytes) {
    return bytes < maxRecommendedSize;
  }

  /// Check if file size is approaching the limit (>80%)
  static bool isApproachingLimit(int bytes) {
    return bytes >= warningThreshold && bytes < maxRecommendedSize;
  }

  /// Check if file size exceeds the limit
  static bool exceedsLimit(int bytes) {
    return bytes >= maxRecommendedSize;
  }

  /// Build a bullet point for the warning list
  static Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
