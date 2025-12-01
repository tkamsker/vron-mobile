import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scan_data.dart';
import 'scan_preview_screen.dart';
import 'scan_sessions_screen.dart';
import '../repositories/scan_repository_provider.dart';

/// Scan complete screen
///
/// Shows detailed metrics and quality information after completing a scan
class ScanCompleteScreen extends ConsumerWidget {
  final ScanData scanData;
  final String? thumbnailPath;

  const ScanCompleteScreen({
    super.key,
    required this.scanData,
    this.thumbnailPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Calculate mock metrics (in production, these would come from actual scan data)
    final coverage = 96;
    final detail = 'High';
    final scanTimeMinutes = (scanData.durationSeconds / 60).toStringAsFixed(0);
    final floorArea = (scanData.pointsCollected / 1000).toStringAsFixed(1);
    final ceilingHeight = 2.7;
    final roomVolume = (double.parse(floorArea) * ceilingHeight).toStringAsFixed(1);
    final wallSurfaces = (double.parse(floorArea) * 2).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Scan completed banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Scan completed',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Here is what we captured from this room.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricChip(
                              label: 'Coverage',
                              value: '$coverage%',
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricChip(
                              label: 'Detail',
                              value: detail,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricChip(
                              label: 'Scan time',
                              value: '$scanTimeMinutes min',
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Room overview section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Room overview',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Approx. size',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Floor plan preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CustomPaint(
                          painter: MiniFloorPlanPainter(),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MetricRow(
                              label: 'Floor area',
                              value: '$floorArea m²',
                            ),
                            const SizedBox(height: 12),
                            _MetricRow(
                              label: 'Ceiling height',
                              value: '$ceilingHeight m',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Metrics grid
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Room volume',
                        value: '$roomVolume m³',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Wall surfaces',
                        value: '$wallSurfaces m²',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Openings',
                        value: '2 doors · 3 windows',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Scan completeness',
                        value: '$coverage%',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Detail & quality section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Detail & quality',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'High',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                LinearProgressIndicator(
                  value: coverage / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),

                const SizedBox(height: 12),

                Text(
                  'Edges and corners are well captured. You can proceed to 3D data generation or rescan to improve even further.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 24),

                // About this room section
                const Text(
                  'About this room',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                _InfoRow(
                  label: 'Room type',
                  value: 'Living room',
                ),
                _InfoRow(
                  label: 'Capture path',
                  value: 'Single pass',
                ),
                _InfoRow(
                  label: 'Lighting',
                  value: 'Balanced / daylight',
                ),
                _InfoRow(
                  label: 'Objects detected',
                  value: 'Sofa, table, 2 windows, radiator',
                ),

                const SizedBox(height: 32),

                // View 3D room button
                ElevatedButton(
                  onPressed: () => _viewRoom(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'View 3D room',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Action buttons row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _saveAndContinue(context, ref),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: const BorderSide(color: Colors.blue),
                        ),
                        child: const Text(
                          'Save & continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text(
                          'Rescan room',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: () => _returnToScans(context),
                    child: const Text(
                      'Or return to scans',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _viewRoom(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScanPreviewScreen(scanData: scanData),
      ),
    );
  }

  Future<void> _saveAndContinue(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(scanRepositoryProvider);
    await repository.saveScan(
      scanData,
      'Room ${DateTime.now().toString().substring(0, 16)}',
      thumbnailPath: thumbnailPath,
    );

    if (!context.mounted) return;

    // Navigate to session list
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => ScanSessionsScreen(
          projectId: scanData.projectId,
          projectName: scanData.projectName,
        ),
      ),
      (route) => false,
    );
  }

  void _returnToScans(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => ScanSessionsScreen(
          projectId: scanData.projectId,
          projectName: scanData.projectName,
        ),
      ),
      (route) => false,
    );
  }
}

/// Metric chip widget
class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '$label · ',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Metric card widget
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;

  const _MetricCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Metric row widget
class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Info row widget
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini floor plan painter for preview
class MiniFloorPlanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw a simple floor plan outline
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.3);
    path.lineTo(size.width * 0.2, size.height * 0.8);
    path.lineTo(size.width * 0.5, size.height * 0.8);
    path.lineTo(size.width * 0.5, size.height * 0.6);
    path.lineTo(size.width * 0.8, size.height * 0.6);
    path.lineTo(size.width * 0.8, size.height * 0.2);
    path.lineTo(size.width * 0.5, size.height * 0.2);
    path.lineTo(size.width * 0.5, size.height * 0.3);
    path.close();

    canvas.drawPath(path, paint);

    // Draw some interior details (furniture/objects)
    final detailPaint = Paint()
      ..color = Colors.green.shade300
      ..style = PaintingStyle.fill;

    // Small rectangles representing objects
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.25, size.height * 0.4, 15, 10),
      detailPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.6, size.height * 0.3, 12, 12),
      detailPaint,
    );
  }

  @override
  bool shouldRepaint(MiniFloorPlanPainter oldDelegate) => false;
}
