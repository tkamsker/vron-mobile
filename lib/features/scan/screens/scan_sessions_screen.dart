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

    return Scaffold(
      backgroundColor: Colors.white,
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
              'Scan Sessions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (projectName != null)
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
            : database.watchAllSessions(),
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

        // Room Stitching View button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _openStitchingView(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: const BorderSide(color: Colors.blue),
              ),
              child: const Text(
                'Room Stitching View',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openStitchingView(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(scanRepositoryProvider);
    final database = repository.database;

    // Collect all room data from all sessions
    final List<RoomData> roomDataList = [];
    final colors = [
      const Color(0xFF6B9BD1), // Blue (like Living Room in mockup)
      const Color(0xFF90C695), // Green (like Kitchen in mockup)
      const Color(0xFFB89CCB), // Purple (like Bathroom in mockup)
      const Color(0xFFE8A87C), // Orange
      const Color(0xFFC77C91), // Rose
    ];

    int colorIndex = 0;
    double xOffset = 150.0;

    for (final session in sessions) {
      // Get scans for this session
      final scans = session.isGuestMode
          ? await database.watchGuestScansBySession(session.id).first
          : await database.watchRoomsBySession(session.id).first;

      for (final scan in scans) {
        final scanName = session.isGuestMode
            ? (scan as GuestScan).name
            : (scan as Room).name;

        roomDataList.add(
          RoomData(
            id: session.isGuestMode ? (scan as GuestScan).id : (scan as Room).id,
            name: scanName,
            position: Offset(xOffset, 200 + (colorIndex * 50)),
            size: const Size(150, 200),
            color: colors[colorIndex % colors.length],
          ),
        );

        xOffset += 180;
        colorIndex++;
      }
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
          sessionId: sessions.first.id,
          projectName: sessions.first.projectName,
          rooms: roomDataList,
        ),
      ),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session name
          Text(
            session.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Scan thumbnails
          StreamBuilder(
            stream: session.isGuestMode
                ? database.watchGuestScansBySession(session.id)
                : database.watchRoomsBySession(session.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final scans = snapshot.data!;
              if (scans.isEmpty) {
                return Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'No scans in this session',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.2,
                ),
                itemCount: scans.length,
                itemBuilder: (context, index) {
                  final scan = scans[index];
                  final scanName = session.isGuestMode
                      ? (scan as GuestScan).name
                      : (scan as Room).name;

                  return _ScanThumbnail(
                    scanName: scanName,
                    isGuestMode: session.isGuestMode,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
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
