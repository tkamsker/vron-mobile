import 'package:flutter/material.dart';
import '../../../core/database/database.dart';

/// Project card widget - Displays project info in a card
class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback? onTap;

  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  image: project.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(project.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: project.imageUrl == null
                    ? Icon(
                        Icons.apartment,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // Project info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Live status indicator
                        if (project.isLive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'LIVE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        // Subscription status badge
                        if (project.subscriptionStatus != null) ...[
                          if (project.isLive) const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(project),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              project.subscriptionIsTrial
                                  ? 'TRIAL'
                                  : _formatSubscriptionStatus(project.subscriptionStatus!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Sync date
                        if (project.syncedAt != null)
                          Text(
                            _formatDate(project.syncedAt!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(Project project) {
    if (!project.subscriptionIsActive) {
      return Colors.red;
    }
    if (project.subscriptionIsTrial) {
      return Colors.orange;
    }
    return Colors.blue;
  }

  String _formatSubscriptionStatus(String status) {
    if (status.length <= 10) {
      return status.toUpperCase();
    }
    // Shorten "MANAGED_BY_BRING_YOUR_OWN_WORLDS_TIER" to "MANAGED"
    if (status.startsWith('MANAGED_BY')) {
      return 'MANAGED';
    }
    return status.substring(0, 10).toUpperCase();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
