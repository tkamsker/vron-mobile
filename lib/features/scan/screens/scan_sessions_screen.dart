import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../repositories/scan_repository_provider.dart';
import 'room_stitching_screen.dart';

/// Scan sessions list screen
///
/// Shows all scan sessions grouped by date
class ScanSessionsScreen extends ConsumerWidget {
  final String? projectId;
  final String? projectName;

  const ScanSessionsScreen({
    super.key,
    this.projectId,
    this.projectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(scanRepositoryProvider);
    final database = repository.database;

    // Check if we can pop - if not, we're the root screen (home tab)
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: canPop,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan Sessions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (projectName != null && projectName != 'All Sessions')
              Text(
                'Project: $projectName',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
      ),
      body: StreamBuilder<List<ScanSession>>(
        stream: projectId != null
            ? database.watchSessionsByProject(projectId!)
            : database.watchSessionsWithScans(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final sessions = snapshot.data!;
          final groupedSessions = _groupSessionsByDate(sessions);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedSessions.length,
            itemBuilder: (context, index) {
              final group = groupedSessions[index];
              return _SessionGroup(
                dateLabel: group.dateLabel,
                sessions: group.sessions,
                projectId: projectId,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.scanner,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No scan sessions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start scanning to create your first session',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  List<_SessionDateGroup> _groupSessionsByDate(List<ScanSession> sessions) {
    final groups = <String, List<ScanSession>>{};

    for (final session in sessions) {
      final dateLabel = _getDateLabel(session.createdAt);
      groups.putIfAbsent(dateLabel, () => []).add(session);
    }

    return groups.entries
        .map((e) => _SessionDateGroup(
              dateLabel: e.key,
              sessions: e.value,
            ))
        .toList();
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) {
      return 'Today';
    } else if (sessionDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }
}

class _SessionDateGroup {
  final String dateLabel;
  final List<ScanSession> sessions;

  _SessionDateGroup({
    required this.dateLabel,
    required this.sessions,
  });
}

class _SessionGroup extends ConsumerWidget {
  final String dateLabel;
  final List<ScanSession> sessions;
  final String? projectId;

  const _SessionGroup({
    required this.dateLabel,
    required this.sessions,
    this.projectId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 16),
          child: Text(
            dateLabel,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Scan count
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${sessions.length} Scans',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),

        // Session thumbnails grid
        ...sessions.map((session) => _SessionCard(
              session: session,
              projectId: projectId,
            )),
      ],
    );
  }

}

class _SessionCard extends ConsumerWidget {
  final ScanSession session;
  final String? projectId;

  const _SessionCard({
    required this.session,
    this.projectId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(scanRepositoryProvider);
    final database = repository.database;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Large floor plan preview / thumbnail
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F1E8), // Beige background
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: session.thumbnailPath != null && session.thumbnailPath!.isNotEmpty
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image.file(
                      File(session.thumbnailPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to generated floor plan if thumbnail fails to load
                        return _buildFallbackFloorPlan(session, database);
                      },
                    ),
                  )
                : _buildFallbackFloorPlan(session, database),
          ),

          // Session info and button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date/Time with delete button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDateTime(session.createdAt),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red.shade400,
                        size: 22,
                      ),
                      onPressed: () => _deleteSession(context, ref, session),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stitched View button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openStitchingForSession(context, ref, session),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Stitched View',
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
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (date == today) {
      dateStr = 'Today';
    } else if (date == today.subtract(const Duration(days: 1))) {
      dateStr = 'Yesterday';
    } else {
      dateStr = '${_monthName(dateTime.month)} ${dateTime.day}, ${dateTime.year}';
    }

    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$dateStr, $hour:$minute $period';
  }

  String _monthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }

  Widget _buildFallbackFloorPlan(ScanSession session, AppDatabase database) {
    return StreamBuilder(
      stream: session.isGuestMode
          ? database.watchGuestScansBySession(session.id)
          : database.watchRoomsBySession(session.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: Colors.grey.shade400,
            ),
          );
        }

        final scans = snapshot.data!;

        return scans.isEmpty
            ? Center(
                child: Text(
                  'No scans in this session',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            : CustomPaint(
                painter: StitchedFloorPlanPainter(
                  roomCount: scans.length,
                ),
              );
      },
    );
  }

  Future<void> _openStitchingForSession(
    BuildContext context,
    WidgetRef ref,
    ScanSession session,
  ) async {
    final repository = ref.read(scanRepositoryProvider);
    final database = repository.database;

    // Collect room data for this specific session
    final List<RoomData> roomDataList = [];
    final colors = [
      const Color(0xFF6B9BD1), // Blue
      const Color(0xFF90C695), // Green
      const Color(0xFFB89CCB), // Purple
      const Color(0xFFE8A87C), // Orange
      const Color(0xFFC77C91), // Rose
    ];

    final scans = session.isGuestMode
        ? await database.watchGuestScansBySession(session.id).first
        : await database.watchRoomsBySession(session.id).first;

    double xOffset = 150.0;
    int colorIndex = 0;

    for (final scan in scans) {
      final scanName = session.isGuestMode
          ? (scan as GuestScan).name
          : (scan as Room).name;

      // Add sample door positions for demo
      final sampleDoors = [
        DoorPosition(wall: 'left', position: 0.5, width: 30),
        if (colorIndex > 0) DoorPosition(wall: 'right', position: 0.5, width: 30),
      ];

      roomDataList.add(
        RoomData(
          id: session.isGuestMode ? (scan as GuestScan).id : (scan as Room).id,
          name: scanName,
          position: Offset(xOffset, 200 + (colorIndex * 50)),
          size: const Size(150, 200),
          color: colors[colorIndex % colors.length],
          doorPositions: sampleDoors,
        ),
      );

      xOffset += 180;
      colorIndex++;
    }

    if (roomDataList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No rooms to stitch'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RoomStitchingScreen(
          sessionId: session.id,
          projectName: session.projectName,
          rooms: roomDataList,
        ),
      ),
    );
  }

  Future<void> _deleteSession(
    BuildContext context,
    WidgetRef ref,
    ScanSession session,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
          'Are you sure you want to delete this scan session?\n\n'
          'This will permanently delete all scans in this session. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final repository = ref.read(scanRepositoryProvider);
      final database = repository.database;

      try {
        // Delete the session (cascade delete will remove associated rooms/guest scans)
        await database.deleteSession(session.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session deleted successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete session: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }
}

class _ScanThumbnail extends StatelessWidget {
  final String scanName;
  final bool isGuestMode;

  const _ScanThumbnail({
    required this.scanName,
    required this.isGuestMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade800,
            Colors.blue.shade600,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Simple 3D room wireframe visualization
          Center(
            child: CustomPaint(
              size: const Size(60, 60),
              painter: _MiniRoomPainter(),
            ),
          ),
          // Scan name label
          Positioned(
            bottom: 4,
            left: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                scanName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini room painter for thumbnails
class _MiniRoomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const orangeColor = Color(0xFFD4A056);

    final roomPaint = Paint()
      ..color = orangeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Front face
    final frontRect = Rect.fromCenter(
      center: Offset(centerX, centerY + 8),
      width: size.width * 0.6,
      height: size.height * 0.5,
    );

    // Back face
    final backRect = Rect.fromCenter(
      center: Offset(centerX, centerY - 8),
      width: size.width * 0.4,
      height: size.height * 0.35,
    );

    // Draw back face
    canvas.drawRect(backRect, roomPaint);

    // Draw connecting lines
    canvas.drawLine(frontRect.topLeft, backRect.topLeft, roomPaint);
    canvas.drawLine(frontRect.topRight, backRect.topRight, roomPaint);
    canvas.drawLine(frontRect.bottomLeft, backRect.bottomLeft, roomPaint);
    canvas.drawLine(frontRect.bottomRight, backRect.bottomRight, roomPaint);

    // Draw front face
    canvas.drawRect(frontRect, roomPaint);
  }

  @override
  bool shouldRepaint(_MiniRoomPainter oldDelegate) => false;
}

/// Stitched floor plan painter for large preview cards
class StitchedFloorPlanPainter extends CustomPainter {
  final int roomCount;

  StitchedFloorPlanPainter({required this.roomCount});

  @override
  void paint(Canvas canvas, Size size) {
    final wallPaint = Paint()
      ..color = Colors.grey.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final doorPaint = Paint()
      ..color = Colors.grey.shade500
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final windowPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw a realistic floor plan based on room count
    if (roomCount == 1) {
      // Single room
      _drawSingleRoom(canvas, size, wallPaint, doorPaint, windowPaint);
    } else if (roomCount == 2) {
      // Two rooms side by side
      _drawTwoRooms(canvas, size, wallPaint, doorPaint, windowPaint);
    } else {
      // Multi-room layout
      _drawMultiRooms(canvas, size, wallPaint, doorPaint, windowPaint);
    }
  }

  void _drawSingleRoom(Canvas canvas, Size size, Paint wallPaint, Paint doorPaint, Paint windowPaint) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final roomWidth = size.width * 0.7;
    final roomHeight = size.height * 0.6;

    // Outer walls
    final path = Path();
    path.moveTo(centerX - roomWidth / 2, centerY - roomHeight / 2);
    path.lineTo(centerX + roomWidth / 2, centerY - roomHeight / 2);
    path.lineTo(centerX + roomWidth / 2, centerY + roomHeight / 2);
    path.lineTo(centerX - roomWidth / 2, centerY + roomHeight / 2);
    path.close();

    canvas.drawPath(path, wallPaint);

    // Add door
    _drawDoor(
      canvas,
      Offset(centerX - roomWidth / 2, centerY + roomHeight / 4),
      30,
      doorPaint,
    );

    // Add windows
    _drawWindow(
      canvas,
      Offset(centerX, centerY - roomHeight / 2),
      40,
      windowPaint,
      true,
    );
  }

  void _drawTwoRooms(Canvas canvas, Size size, Paint wallPaint, Paint doorPaint, Paint windowPaint) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final roomWidth = size.width * 0.35;
    final roomHeight = size.height * 0.55;

    // Left room
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX - roomWidth / 2, centerY),
        width: roomWidth,
        height: roomHeight,
      ),
      wallPaint,
    );

    // Right room
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX + roomWidth / 2, centerY),
        width: roomWidth,
        height: roomHeight,
      ),
      wallPaint,
    );

    // Connecting door
    _drawDoor(
      canvas,
      Offset(centerX, centerY),
      30,
      doorPaint,
    );
  }

  void _drawMultiRooms(Canvas canvas, Size size, Paint wallPaint, Paint doorPaint, Paint windowPaint) {
    // Complex multi-room layout
    final path = Path();

    // Main outline
    path.moveTo(size.width * 0.15, size.height * 0.25);
    path.lineTo(size.width * 0.15, size.height * 0.75);
    path.lineTo(size.width * 0.55, size.height * 0.75);
    path.lineTo(size.width * 0.55, size.height * 0.55);
    path.lineTo(size.width * 0.85, size.height * 0.55);
    path.lineTo(size.width * 0.85, size.height * 0.25);
    path.lineTo(size.width * 0.55, size.height * 0.25);
    path.lineTo(size.width * 0.55, size.height * 0.45);
    path.lineTo(size.width * 0.15, size.height * 0.45);
    path.lineTo(size.width * 0.15, size.height * 0.25);

    canvas.drawPath(path, wallPaint);

    // Internal walls
    canvas.drawLine(
      Offset(size.width * 0.35, size.height * 0.45),
      Offset(size.width * 0.35, size.height * 0.65),
      wallPaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.45),
      Offset(size.width * 0.7, size.height * 0.45),
      wallPaint,
    );

    // Doors
    _drawDoor(
      canvas,
      Offset(size.width * 0.35, size.height * 0.55),
      25,
      doorPaint,
    );

    _drawDoor(
      canvas,
      Offset(size.width * 0.62, size.height * 0.45),
      25,
      doorPaint,
    );

    // Windows
    _drawWindow(
      canvas,
      Offset(size.width * 0.25, size.height * 0.25),
      35,
      windowPaint,
      true,
    );
  }

  void _drawDoor(Canvas canvas, Offset position, double width, Paint paint) {
    canvas.drawLine(
      Offset(position.dx - width / 2, position.dy),
      Offset(position.dx + width / 2, position.dy),
      paint,
    );
  }

  void _drawWindow(
    Canvas canvas,
    Offset position,
    double width,
    Paint paint,
    bool horizontal,
  ) {
    if (horizontal) {
      canvas.drawLine(
        Offset(position.dx - width / 2, position.dy),
        Offset(position.dx + width / 2, position.dy),
        paint,
      );
      canvas.drawLine(
        Offset(position.dx, position.dy - 3),
        Offset(position.dx, position.dy + 3),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(position.dx, position.dy - width / 2),
        Offset(position.dx, position.dy + width / 2),
        paint,
      );
      canvas.drawLine(
        Offset(position.dx - 3, position.dy),
        Offset(position.dx + 3, position.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StitchedFloorPlanPainter oldDelegate) {
    return oldDelegate.roomCount != roomCount;
  }
}
