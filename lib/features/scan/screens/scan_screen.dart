import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io' show Platform, File, Directory;
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'package:roomplan_flutter/roomplan_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/scan_data.dart';
import 'scan_complete_screen.dart';

/// LiDAR Scan screen with simulated scanning
///
/// Provides LiDAR scanning UI matching the design from Vron_Lidar1.jpg
/// Ready for real RoomPlan integration when needed
class ScanScreen extends ConsumerStatefulWidget {
  final bool guestMode;
  final String? projectName;

  const ScanScreen({
    Key? key,
    this.guestMode = false,
    this.projectName,
  }) : super(key: key);

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late RoomPlanScanner _roomScanner;
  StreamSubscription<ScanResult?>? _scanSubscription;
  bool _isScanning = false;
  bool _isLidarAvailable = false;
  bool _isCheckingLidar = true;
  double _scanProgress = 0.0;
  String _scanStatus = 'Ready to scan';
  int _pointsCollected = 0;
  String _scanInstruction = '';
  ScanResult? _currentScanResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _roomScanner = RoomPlanScanner();
    _checkLidarAvailability();
    _listenToScanEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scanSubscription?.cancel();
    super.dispose();
  }

  /// Check if LiDAR is available on this device
  Future<void> _checkLidarAvailability() async {
    if (!Platform.isIOS) {
      setState(() {
        _isLidarAvailable = false;
        _isCheckingLidar = false;
      });
      return;
    }

    final available = await RoomPlanScanner.isSupported();

    if (!mounted) return;

    setState(() {
      _isLidarAvailable = available;
      _isCheckingLidar = false;
    });
  }

  /// Listen to scan events from RoomPlanScanner
  void _listenToScanEvents() {
    _scanSubscription = _roomScanner.onScanResult.listen((scanResult) {
      if (!mounted) return;

      if (scanResult != null) {
        setState(() {
          _currentScanResult = scanResult;
          // Update UI with real-time scan data
          final wallCount = scanResult.room.walls.length;
          final doorCount = scanResult.room.doors.length;
          final windowCount = scanResult.room.windows.length;

          _pointsCollected = (wallCount + doorCount + windowCount) * 100; // Estimated points
          _scanProgress = (wallCount / 4).clamp(0.0, 1.0); // Estimate: 4 walls = 100%
          _scanStatus = 'Scanning... ($wallCount walls detected)';
          _scanInstruction = 'Move slowly around the room';
        });
      }
    }, onError: (error) {
      if (!mounted) return;

      setState(() {
        _isScanning = false;
        _scanStatus = 'Error: $error';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan error: $error')),
      );
    });
  }

  Future<void> _startScanning() async {
    if (!_isLidarAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('LiDAR is not available on this device'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _scanStatus = 'Starting scan...';
    });

    try {
      // Configure scan settings with real-time updates enabled
      const configuration = ScanConfiguration(
        enableRealtimeUpdates: true,
        detectDoors: true,
        detectWindows: true,
      );

      // Start scanning with RoomPlanScanner
      final result = await _roomScanner.startScanning(configuration: configuration);

      if (result != null && mounted) {
        // Scan completed successfully
        setState(() {
          _isScanning = false;
          _scanStatus = 'Scan complete';
          _scanProgress = 1.0;
          _currentScanResult = result;
        });

        // Process and save the scan result
        _handleScanResult(result);
      } else if (mounted) {
        // Scan was canceled or failed
        setState(() {
          _isScanning = false;
          _scanStatus = 'Scan canceled';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanStatus = 'Error: $error';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start scanning: $error')),
        );
      }
    }
  }

  Future<void> _stopScanning() async {
    // Note: RoomPlanScanner's startScanning() is modal and blocks until complete
    // There's no explicit stop method - user dismisses the scanning UI natively
    // This method is called when user completes the scan
    if (_currentScanResult != null && mounted) {
      _handleScanResult(_currentScanResult!);
    }
  }

  Future<void> _handleScanResult(ScanResult result) async {
    // Extract scan metrics from RoomPlan result
    final wallCount = result.room.walls.length;
    final doorCount = result.room.doors.length;
    final windowCount = result.room.windows.length;
    final estimatedPoints = (wallCount + doorCount + windowCount) * 100;

    // Debug: Log scan data
    print('=== SCAN COMPLETED ===');
    print('Walls: $wallCount, Doors: $doorCount, Windows: $windowCount');
    print('Room dimensions: ${result.room.dimensions}');
    print('Project: ${widget.projectName}, Guest mode: ${widget.guestMode}');

    // Generate thumbnail from scan result
    final thumbnailPath = await _generateThumbnailFromScanResult(result);

    // Create scan data object
    // If no project ID is provided, treat as guest scan
    final effectiveGuestMode = widget.guestMode || widget.projectName == null;

    final scanData = ScanData(
      id: const Uuid().v4(), // Generate new scan ID
      roomName: 'Room ${DateTime.now().toString().substring(0, 16)}',
      projectId: widget.projectName,
      startedAt: DateTime.now().subtract(const Duration(minutes: 1)), // Estimate
      completedAt: DateTime.now(),
      pointsCollected: estimatedPoints,
      durationSeconds: 60, // Estimate: 1 minute scan
      isGuestMode: effectiveGuestMode,
      status: ScanStatus.completed,
    );

    if (!mounted) return;

    // Show scan complete message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ Scan complete! $wallCount walls, $doorCount doors, $windowCount windows',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    // Navigate to scan complete screen with detailed metrics and thumbnail
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScanCompleteScreen(
          scanData: scanData,
          thumbnailPath: thumbnailPath,
        ),
      ),
    );
  }

  /// Generate a thumbnail image from the scan result
  ///
  /// Creates a 2D floor plan representation based on the room's walls
  /// and saves it as a PNG file
  Future<String?> _generateThumbnailFromScanResult(ScanResult result) async {
    try {
      // Create a 2D floor plan painter from the scan result
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 400);

      // Draw the floor plan
      final paint = Paint()
        ..color = const Color(0xFFF5F1E8)
        ..style = PaintingStyle.fill;

      // Background
      canvas.drawRect(Offset.zero & size, paint);

      // Calculate bounds from walls to fit in the canvas
      if (result.room.walls.isNotEmpty) {
        // Extract wall positions to calculate bounds
        double minX = double.infinity;
        double maxX = double.negativeInfinity;
        double minZ = double.infinity;
        double maxZ = double.negativeInfinity;

        for (final wall in result.room.walls) {
          final transform = wall.transform;
          if (transform == null) continue;

          final x = transform[12]; // Translation X
          final z = transform[14]; // Translation Z

          minX = math.min(minX, x);
          maxX = math.max(maxX, x);
          minZ = math.min(minZ, z);
          maxZ = math.max(maxZ, z);
        }

        final roomWidth = maxX - minX;
        final roomDepth = maxZ - minZ;
        final scale = math.min(350 / roomWidth, 350 / roomDepth);
        final centerX = size.width / 2;
        final centerY = size.height / 2;

        // Draw walls
        final wallPaint = Paint()
          ..color = Colors.grey.shade700
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;

        for (final wall in result.room.walls) {
          final transform = wall.transform;
          final dimensions = wall.dimensions;
          if (transform == null || dimensions == null) continue;

          final x = transform[12];
          final z = transform[14];
          final width = dimensions.width;

          final screenX = centerX + (x - minX - roomWidth / 2) * scale;
          final screenY = centerY + (z - minZ - roomDepth / 2) * scale;
          final screenWidth = width * scale;

          // Draw wall as a line
          canvas.drawLine(
            Offset(screenX - screenWidth / 2, screenY),
            Offset(screenX + screenWidth / 2, screenY),
            wallPaint,
          );
        }

        // Draw doors
        final doorPaint = Paint()
          ..color = Colors.blue.shade400
          ..style = PaintingStyle.fill;

        for (final door in result.room.doors) {
          final transform = door.transform;
          if (transform == null) continue;

          final x = transform[12];
          final z = transform[14];

          final screenX = centerX + (x - minX - roomWidth / 2) * scale;
          final screenY = centerY + (z - minZ - roomDepth / 2) * scale;

          // Draw door as a small rectangle
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(screenX, screenY),
              width: 30,
              height: 8,
            ),
            doorPaint,
          );
        }

        // Draw windows
        final windowPaint = Paint()
          ..color = Colors.cyan.shade300
          ..style = PaintingStyle.fill;

        for (final window in result.room.windows) {
          final transform = window.transform;
          if (transform == null) continue;

          final x = transform[12];
          final z = transform[14];

          final screenX = centerX + (x - minX - roomWidth / 2) * scale;
          final screenY = centerY + (z - minZ - roomDepth / 2) * scale;

          // Draw window as a small rectangle
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(screenX, screenY),
              width: 25,
              height: 6,
            ),
            windowPaint,
          );
        }
      }

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 400);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        print('Failed to generate thumbnail: byteData is null');
        return null;
      }

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final thumbnailDir = Directory(p.join(directory.path, 'thumbnails'));
      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      final filename = 'thumbnail_${const Uuid().v4()}.png';
      final file = File(p.join(thumbnailDir.path, filename));
      await file.writeAsBytes(byteData.buffer.asUint8List());

      print('Thumbnail saved to: ${file.path}');
      return file.path;
    } catch (e, stackTrace) {
      print('Error generating thumbnail: $e');
      print(stackTrace);
      return null;
    }
  }

  void _saveScan() {
    // Stop scanning will automatically call _handleScanResult
    _stopScanning();
  }

  void _resetScan() {
    setState(() {
      _isScanning = false;
      _scanProgress = 0.0;
      _pointsCollected = 0;
      _scanStatus = 'Ready to scan';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LiDAR Scan',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${widget.projectName ?? "Marketing Analytics"} • Room layout',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      body: _isCheckingLidar
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox.shrink(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _scanStatus,
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: Colors.blue.shade700,
                        unselectedLabelColor: Colors.blue.shade300,
                        dividerColor: Colors.transparent,
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: const [
                          Tab(text: 'Live LiDAR preview'),
                          Tab(text: 'Depth + mesh'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Camera preview / Scan view
                    Container(
                      height: 400,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D3B4F),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            // Camera placeholder
                            _buildCameraPlaceholder(),

                            // Crosshair overlay
                            if (!_isScanning)
                              Center(
                                child: CustomPaint(
                                  size: const Size(200, 200),
                                  painter: CrosshairPainter(),
                                ),
                              ),

                            // Scanning animation
                            if (_isScanning)
                              AnimatedBuilder(
                                animation: AlwaysStoppedAnimation(_scanProgress),
                                builder: (context, child) {
                                  return CustomPaint(
                                    size: Size.infinite,
                                    painter: ScanningOverlayPainter(progress: _scanProgress),
                                  );
                                },
                              ),

                            // Instructions overlay
                            if (_isScanning)
                              Positioned(
                                bottom: 40,
                                left: 20,
                                right: 20,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Point at walls and slowly move around\nKeep the room edges inside the frame',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Scanning coverage
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Scanning coverage',
                          style: TextStyle(
                            color: Colors.blue.shade400,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(_scanProgress * 100).toInt()}%',
                          style: TextStyle(
                            color: Colors.blue.shade400,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _scanProgress,
                        backgroundColor: Colors.blue.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade400,
                        ),
                        minHeight: 8,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Reset button (shown when there's progress)
                        if (_scanProgress > 0 && !_isScanning)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ElevatedButton.icon(
                              onPressed: _resetScan,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),

                        // Start/Stop button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLidarAvailable
                                ? (_isScanning ? _stopScanning : _startScanning)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isScanning
                                  ? Colors.red.shade400
                                  : Colors.blue.shade600,
                              disabledBackgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isScanning ? Icons.stop : Icons.play_arrow,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _isScanning ? 'Stop scanning' : 'Start scanning',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Save button (shown when scan is complete)
                        if (_scanProgress >= 1.0 && !_isScanning)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: ElevatedButton.icon(
                              onPressed: _saveScan,
                              icon: const Icon(Icons.save),
                              label: const Text('Save'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Instructions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Move slowly and keep your device pointed at surfaces.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Scanning Tips'),
                                content: const Text(
                                  '• Hold your device at eye level\n'
                                  '• Move slowly around the room\n'
                                  '• Point at walls and corners\n'
                                  '• Keep room edges in frame\n'
                                  '• Ensure good lighting',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Got it'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(
                            'View tips',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // LiDAR availability warning
                    if (!_isLidarAvailable) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.shade200,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LiDAR not available on this device',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'On devices without a LiDAR sensor, the LiDAR scan button will be disabled. You can still browse projects and products normally.',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'LiDAR scanning disabled',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCameraPlaceholder() {
    if (!Platform.isIOS || !_isLidarAvailable) {
      return Container(
        color: const Color(0xFF0D3B4F),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_outlined,
                size: 80,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'RoomPlan not available',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Use UiKitView to embed the native RoomCaptureView
    return Stack(
      children: [
        UiKitView(
          viewType: 'com.vron.mobile/room_plan_view',
          creationParamsCodec: const StandardMessageCodec(),
        ),
        // Show scanning instruction overlay
        if (_scanInstruction.isNotEmpty)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _scanInstruction,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Custom painter for crosshair overlay
class CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final gridSize = 60.0;

    // Vertical lines
    canvas.drawLine(
      Offset(centerX - gridSize, 0),
      Offset(centerX - gridSize, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + gridSize, 0),
      Offset(centerX + gridSize, size.height),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(0, centerY - gridSize),
      Offset(size.width, centerY - gridSize),
      paint,
    );
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      paint,
    );
    canvas.drawLine(
      Offset(0, centerY + gridSize),
      Offset(size.width, centerY + gridSize),
      paint,
    );

    // Center circle
    final circlePaint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX, centerY),
      40,
      circlePaint,
    );

    // Center icon (simplified target)
    final iconPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(
      Offset(centerX, centerY),
      15,
      iconPaint,
    );

    // Corner brackets
    final cornerLength = 20.0;
    final corners = [
      // Top-left
      [Offset(10, 10), Offset(10 + cornerLength, 10)],
      [Offset(10, 10), Offset(10, 10 + cornerLength)],
      // Top-right
      [Offset(size.width - 10, 10), Offset(size.width - 10 - cornerLength, 10)],
      [Offset(size.width - 10, 10), Offset(size.width - 10, 10 + cornerLength)],
      // Bottom-left
      [Offset(10, size.height - 10), Offset(10 + cornerLength, size.height - 10)],
      [Offset(10, size.height - 10), Offset(10, size.height - 10 - cornerLength)],
      // Bottom-right
      [Offset(size.width - 10, size.height - 10), Offset(size.width - 10 - cornerLength, size.height - 10)],
      [Offset(size.width - 10, size.height - 10), Offset(size.width - 10, size.height - 10 - cornerLength)],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// Custom painter for scanning overlay animation
class ScanningOverlayPainter extends CustomPainter {
  final double progress;

  ScanningOverlayPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Green border indicating active scanning
    final borderPaint = Paint()
      ..color = Colors.green.withOpacity(0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderPaint,
    );

    // Animated scan line
    final scanY = size.height * progress;
    final scanLinePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(0, scanY),
      Offset(size.width, scanY),
      scanLinePaint,
    );

    // Gradient overlay to show scanned area
    final gradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.green.withOpacity(0.1),
          Colors.transparent,
        ],
        stops: [progress, progress],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      gradient,
    );
  }

  @override
  bool shouldRepaint(ScanningOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
