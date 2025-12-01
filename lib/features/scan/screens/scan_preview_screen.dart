import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/scan_data.dart';
import '../repositories/scan_repository_provider.dart';
import 'scan_sessions_screen.dart';

/// Scan preview screen
///
/// Shows a preview of the completed scan with options to:
/// - View scan details (points, duration, file size)
/// - Edit room name
/// - Save scan to database
/// - Discard scan
class ScanPreviewScreen extends ConsumerStatefulWidget {
  final ScanData scanData;

  const ScanPreviewScreen({
    super.key,
    required this.scanData,
  });

  @override
  ConsumerState<ScanPreviewScreen> createState() => _ScanPreviewScreenState();
}

class _ScanPreviewScreenState extends ConsumerState<ScanPreviewScreen> {
  late TextEditingController _roomNameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _roomNameController = TextEditingController(
      text: widget.scanData.roomName ?? _generateDefaultRoomName(),
    );
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  String _generateDefaultRoomName() {
    final now = DateTime.now();
    final formatter = DateFormat('MMM d, yyyy HH:mm');
    return 'Room ${formatter.format(now)}';
  }

  Future<void> _saveScan() async {
    final roomName = _roomNameController.text.trim();
    if (roomName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room name')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      print('📁 Saving scan from preview screen...');
      print('Room name: $roomName');
      print('Scan ID: ${widget.scanData.id}');
      print('Guest mode: ${widget.scanData.isGuestMode}');
      print('Project ID: ${widget.scanData.projectId}');

      final repository = ref.read(scanRepositoryProvider);
      await repository.saveScan(widget.scanData, roomName);

      print('✅ Scan saved successfully from preview!');

      if (mounted) {
        // Pop the preview screen
        Navigator.of(context).pop();
        // Pop the scan screen
        Navigator.of(context).pop();

        // Navigate to session list
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ScanSessionsScreen(
              projectId: widget.scanData.projectId,
              projectName: widget.scanData.projectName,
            ),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$roomName saved successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error saving from preview: $e');

      if (mounted) {
        setState(() => _isSaving = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save scan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _discardScan() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Scan?'),
        content: const Text(
          'Are you sure you want to discard this scan? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Pop dialog
              Navigator.of(context).pop();
              // Pop preview screen
              Navigator.of(context).pop();
              // Pop scan screen
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _scanAnotherRoom() {
    // Pop preview screen to go back to scan screen
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan Preview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Scan completed - Room 1',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Ready to save',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 3D Room Visualization
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(300, 300),
                  painter: RoomPlanPainter(
                    pointsCollected: widget.scanData.pointsCollected,
                  ),
                ),
              ),
            ),
          ),

          // Action Buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Room Name Input
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.label_outline,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Room Name',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _roomNameController,
                          enabled: !_isSaving,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter room name',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            suffixIcon: _roomNameController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: _isSaving
                                        ? null
                                        : () {
                                            _roomNameController.clear();
                                            setState(() {});
                                          },
                                  )
                                : null,
                          ),
                          textInputAction: TextInputAction.done,
                          onChanged: (value) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Save Scan Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save, size: 24),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Scan',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Scan Another Room Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _scanAnotherRoom,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.blue, width: 1.5),
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 24),
                      label: const Text(
                        'Scan Another Room',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(0)} seconds';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).floor();
      final remainingSeconds = (seconds % 60).floor();
      return '$minutes min $remainingSeconds sec';
    } else {
      final hours = (seconds / 3600).floor();
      final minutes = ((seconds % 3600) / 60).floor();
      return '$hours hr $minutes min';
    }
  }
}

/// Statistic card widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for simple room floor plan visualization
class RoomPlanPainter extends CustomPainter {
  final int pointsCollected;

  RoomPlanPainter({required this.pointsCollected});

  @override
  void paint(Canvas canvas, Size size) {
    // Use orange/gold color scheme to match design mockup
    const orangeColor = Color(0xFFD4A056); // Gold/Orange color

    // Draw 3D room outline with perspective
    final roomPaint = Paint()
      ..color = orangeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final fillPaint = Paint()
      ..color = orangeColor.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    // Create a 3D-like perspective room
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Front face (larger)
    final frontRect = Rect.fromCenter(
      center: Offset(centerX, centerY + 20),
      width: size.width * 0.55,
      height: size.height * 0.45,
    );

    // Back face (smaller, for perspective)
    final backRect = Rect.fromCenter(
      center: Offset(centerX, centerY - 30),
      width: size.width * 0.35,
      height: size.height * 0.3,
    );

    // Draw back face
    canvas.drawRect(backRect, fillPaint);
    canvas.drawRect(backRect, roomPaint);

    // Draw connecting lines (depth)
    canvas.drawLine(frontRect.topLeft, backRect.topLeft, roomPaint);
    canvas.drawLine(frontRect.topRight, backRect.topRight, roomPaint);
    canvas.drawLine(frontRect.bottomLeft, backRect.bottomLeft, roomPaint);
    canvas.drawLine(frontRect.bottomRight, backRect.bottomRight, roomPaint);

    // Draw front face
    canvas.drawRect(frontRect, roomPaint);

    // Draw floor grid for depth
    final gridPaint = Paint()
      ..color = orangeColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Horizontal floor lines
    for (int i = 1; i < 4; i++) {
      final y = frontRect.bottom - (frontRect.height * i / 4);
      final backY = backRect.bottom - (backRect.height * i / 4);
      canvas.drawLine(
        Offset(frontRect.left, y),
        Offset(backRect.left, backY),
        gridPaint,
      );
      canvas.drawLine(
        Offset(frontRect.right, y),
        Offset(backRect.right, backY),
        gridPaint,
      );
    }

    // Draw corner markers on front face
    final markerPaint = Paint()
      ..color = orangeColor
      ..style = PaintingStyle.fill;

    final corners = [
      frontRect.topLeft,
      frontRect.topRight,
      frontRect.bottomLeft,
      frontRect.bottomRight,
    ];

    for (final corner in corners) {
      canvas.drawCircle(corner, 3, markerPaint);
    }

    // Draw scan points as small dots scattered in the room
    final pointPaint = Paint()
      ..color = orangeColor.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final random = pointsCollected.hashCode;
    for (int i = 0; i < (pointsCollected / 100).clamp(8, 25); i++) {
      final x = frontRect.left + (frontRect.width * ((random + i * 37) % 100) / 100);
      final y = frontRect.top + (frontRect.height * ((random + i * 73) % 100) / 100);
      canvas.drawCircle(Offset(x, y), 1.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(RoomPlanPainter oldDelegate) =>
      oldDelegate.pointsCollected != pointsCollected;
}
