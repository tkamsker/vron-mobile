import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/navigation/main_navigation.dart' show MainNavigationScreen;
import '../../projects/screens/projects_list_screen.dart';
import '../../../core/auth/auth_notifier.dart';

/// Room stitching screen
///
/// Allows users to arrange and connect scanned rooms on a floor plan grid
class RoomStitchingScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String? projectName;
  final List<RoomData> rooms;

  const RoomStitchingScreen({
    super.key,
    required this.sessionId,
    this.projectName,
    required this.rooms,
  });

  @override
  ConsumerState<RoomStitchingScreen> createState() => _RoomStitchingScreenState();
}

class _RoomStitchingScreenState extends ConsumerState<RoomStitchingScreen> {
  StitchingTool _selectedTool = StitchingTool.select;
  String? _selectedRoomId;
  Offset _dragStart = Offset.zero;
  double _gridScale = 1.0;
  Offset _gridOffset = Offset.zero;
  List<DoorConnection> _doors = [];

  @override
  Widget build(BuildContext context) {
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
              'Room Stitching',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.projectName != null)
              Text(
                'Project: ${widget.projectName}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _savePlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              icon: const Icon(Icons.check, size: 20),
              label: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Grid canvas
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GestureDetector(
                  onPanStart: _handlePanStart,
                  onPanUpdate: _handlePanUpdate,
                  onPanEnd: _handlePanEnd,
                  onTapUp: _handleTapUp,
                  child: CustomPaint(
                    painter: FloorPlanPainter(
                      rooms: widget.rooms,
                      selectedRoomId: _selectedRoomId,
                      doors: _doors,
                      gridScale: _gridScale,
                      gridOffset: _gridOffset,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),

          // Tool buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ToolButton(
                  icon: Icons.select_all,
                  label: 'Select',
                  isSelected: _selectedTool == StitchingTool.select,
                  onTap: () => setState(() => _selectedTool = StitchingTool.select),
                ),
                _ToolButton(
                  icon: Icons.open_with,
                  label: 'Move',
                  isSelected: _selectedTool == StitchingTool.move,
                  onTap: () => setState(() => _selectedTool = StitchingTool.move),
                ),
                _ToolButton(
                  icon: Icons.rotate_right,
                  label: 'Rotate',
                  isSelected: _selectedTool == StitchingTool.rotate,
                  onTap: () => setState(() => _selectedTool = StitchingTool.rotate),
                ),
                _ToolButton(
                  icon: Icons.door_front_door,
                  label: 'Add Door',
                  isSelected: _selectedTool == StitchingTool.addDoor,
                  onTap: () => setState(() => _selectedTool = StitchingTool.addDoor),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0, // Highlight Sessions since we're viewing a session's stitching
        onDestinationSelected: (index) {
          // Navigate back to main navigation with selected tab
          if (index != 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => MainNavigationScreen(initialIndex: index),
              ),
            );
          } else {
            // Go back to sessions list
            Navigator.of(context).pop();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_in_ar_outlined),
            selectedIcon: Icon(Icons.view_in_ar),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    _dragStart = details.localPosition;

    // Select room on tap - selecting also enables moving
    if (_selectedTool == StitchingTool.select || _selectedTool == StitchingTool.move) {
      final room = _findRoomAtPosition(details.localPosition);
      setState(() {
        _selectedRoomId = room?.id;
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final delta = details.localPosition - _dragStart;

    // Allow moving with both select and move tools
    if ((_selectedTool == StitchingTool.select || _selectedTool == StitchingTool.move) && _selectedRoomId != null) {
      setState(() {
        final room = widget.rooms.firstWhere((r) => r.id == _selectedRoomId);

        // Update position with delta
        room.position += delta / _gridScale;

        // Snap to grid (20px grid)
        const gridSize = 20.0;
        room.position = Offset(
          (room.position.dx / gridSize).round() * gridSize,
          (room.position.dy / gridSize).round() * gridSize,
        );

        _dragStart = details.localPosition;
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    // Reset drag state
  }

  void _handleTapUp(TapUpDetails details) {
    if (_selectedTool == StitchingTool.select) {
      final room = _findRoomAtPosition(details.localPosition);
      setState(() {
        _selectedRoomId = room?.id;
      });
    } else if (_selectedTool == StitchingTool.rotate && _selectedRoomId != null) {
      // Rotate by 45° (0.7854 radians) per tap
      setState(() {
        final room = widget.rooms.firstWhere((r) => r.id == _selectedRoomId);
        room.rotation += 0.7854; // 45 degrees in radians
        // Normalize rotation to 0-2π range
        while (room.rotation >= 6.2832) {
          room.rotation -= 6.2832; // 2π
        }
      });
    } else if (_selectedTool == StitchingTool.addDoor && _selectedRoomId != null) {
      // Add door to wall at tap position
      final room = widget.rooms.firstWhere((r) => r.id == _selectedRoomId);
      final roomRect = _getRoomRect(room);
      final tapPos = details.localPosition;

      // Determine which wall was clicked (with threshold)
      const wallThreshold = 20.0;
      String? wall;
      double position = 0.5;

      // Check if tap is on a wall
      if ((tapPos.dy - roomRect.top).abs() < wallThreshold) {
        wall = 'top';
        position = (tapPos.dx - roomRect.left) / roomRect.width;
      } else if ((tapPos.dy - roomRect.bottom).abs() < wallThreshold) {
        wall = 'bottom';
        position = (tapPos.dx - roomRect.left) / roomRect.width;
      } else if ((tapPos.dx - roomRect.left).abs() < wallThreshold) {
        wall = 'left';
        position = (tapPos.dy - roomRect.top) / roomRect.height;
      } else if ((tapPos.dx - roomRect.right).abs() < wallThreshold) {
        wall = 'right';
        position = (tapPos.dy - roomRect.top) / roomRect.height;
      }

      if (wall != null && position >= 0 && position <= 1) {
        setState(() {
          room.doorPositions.add(DoorPosition(
            wall: wall!,
            position: position.clamp(0.1, 0.9), // Keep doors away from corners
            width: 30.0,
          ));
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Door added to $wall wall'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  RoomData? _findRoomAtPosition(Offset position) {
    for (final room in widget.rooms.reversed) {
      final rect = _getRoomRect(room);
      if (rect.contains(position)) {
        return room;
      }
    }
    return null;
  }

  Rect _getRoomRect(RoomData room) {
    final center = room.position * _gridScale + _gridOffset;
    final size = room.size * _gridScale;
    return Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height,
    );
  }

  /// Calculate rough outline points for a room (useful for collision detection and visualization)
  List<Offset> _calculateRoomOutline(RoomData room) {
    final center = room.position;
    final halfWidth = room.size.width / 2;
    final halfHeight = room.size.height / 2;

    // Define the 4 corners in local space (before rotation)
    final corners = [
      Offset(-halfWidth, -halfHeight), // Top-left
      Offset(halfWidth, -halfHeight),  // Top-right
      Offset(halfWidth, halfHeight),   // Bottom-right
      Offset(-halfWidth, halfHeight),  // Bottom-left
    ];

    // Apply rotation and translation
    final rotatedCorners = corners.map((corner) {
      // Rotate around origin
      final rotatedX = corner.dx * cos(room.rotation) - corner.dy * sin(room.rotation);
      final rotatedY = corner.dx * sin(room.rotation) + corner.dy * cos(room.rotation);

      // Translate to room position
      return Offset(
        center.dx + rotatedX,
        center.dy + rotatedY,
      );
    }).toList();

    return rotatedCorners;
  }

  void _savePlan() {
    // TODO: Save room positions and door connections to database
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Floor plan saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }
}

/// Floor plan painter
class FloorPlanPainter extends CustomPainter {
  final List<RoomData> rooms;
  final String? selectedRoomId;
  final List<DoorConnection> doors;
  final double gridScale;
  final Offset gridOffset;

  FloorPlanPainter({
    required this.rooms,
    required this.selectedRoomId,
    required this.doors,
    required this.gridScale,
    required this.gridOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid
    _drawGrid(canvas, size);

    // Draw door connections
    for (final door in doors) {
      _drawDoor(canvas, door);
    }

    // Draw rooms
    for (final room in rooms) {
      _drawRoom(canvas, room, room.id == selectedRoomId);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const gridSize = 20.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
  }

  void _drawRoom(Canvas canvas, RoomData room, bool isSelected) {
    final center = room.position * gridScale + gridOffset;
    final roomSize = room.size * gridScale;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(room.rotation);

    // Room background (floor)
    final fillPaint = Paint()
      ..color = room.color.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: roomSize.width,
      height: roomSize.height,
    );

    canvas.drawRect(rect, fillPaint);

    // Draw walls with thickness
    final wallThickness = 6.0;
    final wallPaint = Paint()
      ..color = isSelected ? Colors.blue.shade700 : Colors.grey.shade700
      ..style = PaintingStyle.fill;

    final innerWallPaint = Paint()
      ..color = isSelected ? Colors.blue.shade400 : Colors.grey.shade500
      ..style = PaintingStyle.fill;

    // Wall positions
    final left = rect.left;
    final right = rect.right;
    final top = rect.top;
    final bottom = rect.bottom;

    // Draw walls as thick rectangles
    // Top wall
    _drawWallSegment(canvas, Offset(left, top), Offset(right, top), wallThickness, wallPaint, innerWallPaint, room.doorPositions, 'top');

    // Right wall
    _drawWallSegment(canvas, Offset(right, top), Offset(right, bottom), wallThickness, wallPaint, innerWallPaint, room.doorPositions, 'right');

    // Bottom wall
    _drawWallSegment(canvas, Offset(right, bottom), Offset(left, bottom), wallThickness, wallPaint, innerWallPaint, room.doorPositions, 'bottom');

    // Left wall
    _drawWallSegment(canvas, Offset(left, bottom), Offset(left, top), wallThickness, wallPaint, innerWallPaint, room.doorPositions, 'left');

    // Draw corner reinforcements
    final cornerPaint = Paint()
      ..color = isSelected ? Colors.blue.shade800 : Colors.grey.shade800
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(left, top), wallThickness / 1.5, cornerPaint);
    canvas.drawCircle(Offset(right, top), wallThickness / 1.5, cornerPaint);
    canvas.drawCircle(Offset(right, bottom), wallThickness / 1.5, cornerPaint);
    canvas.drawCircle(Offset(left, bottom), wallThickness / 1.5, cornerPaint);

    // Selection indicator
    if (isSelected) {
      final selectionPaint = Paint()
        ..color = Colors.blue.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      final selectionRect = rect.inflate(12);
      canvas.drawRect(selectionRect, selectionPaint);

      // Draw corner handles
      final handlePaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(selectionRect.left, selectionRect.top), 6, handlePaint);
      canvas.drawCircle(Offset(selectionRect.right, selectionRect.top), 6, handlePaint);
      canvas.drawCircle(Offset(selectionRect.right, selectionRect.bottom), 6, handlePaint);
      canvas.drawCircle(Offset(selectionRect.left, selectionRect.bottom), 6, handlePaint);
    }

    // Room label
    final textPainter = TextPainter(
      text: TextSpan(
        text: room.name,
        style: TextStyle(
          color: Colors.grey.shade800,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          backgroundColor: Colors.white.withOpacity(0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );

    canvas.restore();
  }

  void _drawWallSegment(
    Canvas canvas,
    Offset start,
    Offset end,
    double thickness,
    Paint wallPaint,
    Paint innerPaint,
    List<DoorPosition> doors,
    String wallSide,
  ) {
    final isHorizontal = (end.dy - start.dy).abs() < 1;
    final wallLength = isHorizontal ? (end.dx - start.dx).abs() : (end.dy - start.dy).abs();

    // Find doors on this wall
    final doorsOnWall = doors.where((d) => d.wall == wallSide).toList();

    if (doorsOnWall.isEmpty) {
      // Draw solid wall
      if (isHorizontal) {
        final rect = Rect.fromLTWH(
          start.dx < end.dx ? start.dx : end.dx,
          start.dy - thickness / 2,
          wallLength,
          thickness,
        );
        canvas.drawRect(rect, wallPaint);

        // Inner highlight
        final innerRect = Rect.fromLTWH(
          rect.left,
          rect.top + thickness * 0.3,
          rect.width,
          thickness * 0.4,
        );
        canvas.drawRect(innerRect, innerPaint);
      } else {
        final rect = Rect.fromLTWH(
          start.dx - thickness / 2,
          start.dy < end.dy ? start.dy : end.dy,
          thickness,
          wallLength,
        );
        canvas.drawRect(rect, wallPaint);

        // Inner highlight
        final innerRect = Rect.fromLTWH(
          rect.left + thickness * 0.3,
          rect.top,
          thickness * 0.4,
          rect.height,
        );
        canvas.drawRect(innerRect, innerPaint);
      }
    } else {
      // Draw wall with door openings
      double currentPos = 0;

      for (final door in doorsOnWall) {
        final doorStart = wallLength * door.position;
        final doorEnd = doorStart + door.width;

        // Draw wall segment before door
        if (doorStart > currentPos) {
          if (isHorizontal) {
            final rect = Rect.fromLTWH(
              (start.dx < end.dx ? start.dx : end.dx) + currentPos,
              start.dy - thickness / 2,
              doorStart - currentPos,
              thickness,
            );
            canvas.drawRect(rect, wallPaint);
          } else {
            final rect = Rect.fromLTWH(
              start.dx - thickness / 2,
              (start.dy < end.dy ? start.dy : end.dy) + currentPos,
              thickness,
              doorStart - currentPos,
            );
            canvas.drawRect(rect, wallPaint);
          }
        }

        // Draw door opening marker
        final doorPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

        final doorMarkerPaint = Paint()
          ..color = Colors.orange.shade700
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        if (isHorizontal) {
          final doorRect = Rect.fromLTWH(
            (start.dx < end.dx ? start.dx : end.dx) + doorStart,
            start.dy - thickness / 2,
            door.width,
            thickness,
          );
          canvas.drawRect(doorRect, doorPaint);
          canvas.drawRect(doorRect, doorMarkerPaint);
        } else {
          final doorRect = Rect.fromLTWH(
            start.dx - thickness / 2,
            (start.dy < end.dy ? start.dy : end.dy) + doorStart,
            thickness,
            door.width,
          );
          canvas.drawRect(doorRect, doorPaint);
          canvas.drawRect(doorRect, doorMarkerPaint);
        }

        currentPos = doorEnd;
      }

      // Draw remaining wall after last door
      if (currentPos < wallLength) {
        if (isHorizontal) {
          final rect = Rect.fromLTWH(
            (start.dx < end.dx ? start.dx : end.dx) + currentPos,
            start.dy - thickness / 2,
            wallLength - currentPos,
            thickness,
          );
          canvas.drawRect(rect, wallPaint);
        } else {
          final rect = Rect.fromLTWH(
            start.dx - thickness / 2,
            (start.dy < end.dy ? start.dy : end.dy) + currentPos,
            thickness,
            wallLength - currentPos,
          );
          canvas.drawRect(rect, wallPaint);
        }
      }
    }
  }

  void _drawDoor(Canvas canvas, DoorConnection door) {
    final doorPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final doorBorderPaint = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw door at the connection point
    final doorPos = door.position;
    const doorSize = 30.0;

    // Border
    canvas.drawLine(
      Offset(doorPos.dx - doorSize / 2, doorPos.dy),
      Offset(doorPos.dx + doorSize / 2, doorPos.dy),
      doorBorderPaint,
    );

    // White center
    canvas.drawLine(
      Offset(doorPos.dx - doorSize / 2, doorPos.dy),
      Offset(doorPos.dx + doorSize / 2, doorPos.dy),
      doorPaint,
    );
  }

  @override
  bool shouldRepaint(FloorPlanPainter oldDelegate) {
    return oldDelegate.rooms != rooms ||
        oldDelegate.selectedRoomId != selectedRoomId ||
        oldDelegate.doors != doors ||
        oldDelegate.gridScale != gridScale ||
        oldDelegate.gridOffset != gridOffset;
  }
}

/// Tool button widget
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey.shade600,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey.shade700,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Room data model for stitching
class RoomData {
  final String id;
  final String name;
  Offset position;
  final Size size;
  double rotation;
  final Color color;
  final List<DoorPosition> doorPositions;

  RoomData({
    required this.id,
    required this.name,
    required this.position,
    required this.size,
    this.rotation = 0.0,
    required this.color,
    List<DoorPosition>? doorPositions,
  }) : doorPositions = doorPositions ?? [];
}

/// Door position on a room wall
class DoorPosition {
  final String wall; // 'top', 'right', 'bottom', 'left'
  final double position; // 0.0 to 1.0 along the wall
  final double width; // Width of door opening in pixels

  DoorPosition({
    required this.wall,
    required this.position,
    this.width = 30.0,
  });
}

/// Door connection model
class DoorConnection {
  final String room1Id;
  final String room2Id;
  final Offset position;

  DoorConnection({
    required this.room1Id,
    required this.room2Id,
    required this.position,
  });
}

/// Stitching tool enum
enum StitchingTool {
  select,
  move,
  rotate,
  addDoor,
}
