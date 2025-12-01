import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    );
  }

  void _handlePanStart(DragStartDetails details) {
    _dragStart = details.localPosition;

    // Select room on tap
    if (_selectedTool == StitchingTool.select) {
      final room = _findRoomAtPosition(details.localPosition);
      setState(() {
        _selectedRoomId = room?.id;
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final delta = details.localPosition - _dragStart;

    if (_selectedTool == StitchingTool.move && _selectedRoomId != null) {
      setState(() {
        final room = widget.rooms.firstWhere((r) => r.id == _selectedRoomId);
        room.position += delta / _gridScale;
        _dragStart = details.localPosition;
      });
    } else if (_selectedTool == StitchingTool.rotate && _selectedRoomId != null) {
      setState(() {
        final room = widget.rooms.firstWhere((r) => r.id == _selectedRoomId);
        room.rotation += delta.dx * 0.01;
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
    } else if (_selectedTool == StitchingTool.addDoor && _selectedRoomId != null) {
      // Find another room near the tap
      final targetRoom = _findRoomAtPosition(details.localPosition);
      if (targetRoom != null && targetRoom.id != _selectedRoomId) {
        setState(() {
          _doors.add(DoorConnection(
            room1Id: _selectedRoomId!,
            room2Id: targetRoom.id,
            position: details.localPosition,
          ));
        });
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

    // Room background
    final fillPaint = Paint()
      ..color = room.color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: roomSize.width,
      height: roomSize.height,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      fillPaint,
    );

    // Room border
    final borderPaint = Paint()
      ..color = isSelected ? Colors.blue : room.color
      ..strokeWidth = isSelected ? 3 : 2
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );

    // Room label
    final textPainter = TextPainter(
      text: TextSpan(
        text: room.name,
        style: TextStyle(
          color: room.color.computeLuminance() > 0.5 ? Colors.black : Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w600,
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

  RoomData({
    required this.id,
    required this.name,
    required this.position,
    required this.size,
    this.rotation = 0.0,
    required this.color,
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
