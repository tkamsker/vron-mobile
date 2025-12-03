import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:roomplan_flutter/roomplan_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database.dart';
import '../../scan/models/scan_data.dart';
import '../../scan/screens/scan_complete_screen.dart';

/// Project detail screen with tabs
///
/// Shows project details with three tabs:
/// - Viewer: 3D/VR viewer
/// - Project data: Edit project information
/// - Products: Project products
class ProjectDetailScreen extends ConsumerStatefulWidget {
  final Project project;

  const ProjectDetailScreen({
    Key? key,
    required this.project,
  }) : super(key: key);

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  // Controllers for editable fields
  late TextEditingController _nameController;
  late TextEditingController _slugController;
  late TextEditingController _descriptionController;

  // LiDAR / RoomPlan availability state (for gating "Add Room Scan" button)
  bool _isCheckingLidar = true;

  /// True if this device hardware + iOS version support RoomPlan / LiDAR
  bool _deviceSupportsLidar = false;

  /// True if the user has granted camera permission
  bool _hasCameraPermission = false;

  bool get _canScanWithLidar =>
      Platform.isIOS && _deviceSupportsLidar && _hasCameraPermission;

  bool _isScanning = false;
  late final RoomPlanScanner _roomScanner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _nameController = TextEditingController(text: widget.project.name);
    _slugController = TextEditingController(text: widget.project.slug);
    _descriptionController = TextEditingController(text: '');

    _roomScanner = RoomPlanScanner();

    // Proactively check LiDAR + camera availability on iOS so we can
    // enable/disable the "Add Room Scan" button appropriately.
    _checkLidarAvailabilityForProject();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _roomScanner.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When returning from background (e.g., after user changed permissions in Settings),
    // re-check LiDAR hardware + camera permission and update the "Add Room Scan" button.
    if (state == AppLifecycleState.resumed) {
      _checkLidarAvailabilityForProject();
    }
  }

  /// Check if this device can perform LiDAR room scans for this project.
  ///
          /// Mirrors the logic used in the main scan entry:
  /// - Only runs on iOS
  /// - Uses `RoomPlanScanner.isSupported()` to detect LiDAR hardware + RoomPlan
  /// - If hardware is supported, checks/requests camera permission (required for RoomPlan)
  Future<void> _checkLidarAvailabilityForProject() async {
    if (!Platform.isIOS) {
      setState(() {
        _isCheckingLidar = false;
        _deviceSupportsLidar = false;
        _hasCameraPermission = false;
      });
      return;
    }

    try {
      // Step 1: Check if this device has LiDAR and supports RoomPlan
      final hardwareSupported = await RoomPlanScanner.isSupported();

      if (!mounted) return;

      if (!hardwareSupported) {
        setState(() {
          _isCheckingLidar = false;
          _deviceSupportsLidar = false;
          _hasCameraPermission = false;
        });

        // Educate user if device lacks LiDAR hardware
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'LiDAR scanning requires iPhone 12 Pro or newer, or iPad Pro (2020) or newer.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Device supports LiDAR - Step 2: ensure camera permission
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        final result = await Permission.camera.request();
        status = result;
      }

      final granted = status.isGranted;

      if (!mounted) return;

      setState(() {
        _isCheckingLidar = false;
        _deviceSupportsLidar = true;
        _hasCameraPermission = granted;
      });

      if (!granted) {
        // Inform the user why the button is disabled
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Camera permission is required to scan rooms with LiDAR. '
              'You can enable it later in Settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                openAppSettings();
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingLidar = false;
        _deviceSupportsLidar = false;
        _hasCameraPermission = false;
      });
    }
  }

  Future<void> _startRoomScanForProject(BuildContext context) async {
    if (!_canScanWithLidar || _isScanning) return;

    setState(() {
      _isScanning = true;
    });

    try {
      // Double-check camera permission before starting RoomPlan
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        final result = await Permission.camera.request();
        status = result;
      }

      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Camera permission is required to start LiDAR scanning.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      const configuration = ScanConfiguration(
        enableRealtimeUpdates: false,
        detectDoors: true,
        detectWindows: true,
      );

      final result = await _roomScanner.startScanning(configuration: configuration);

      if (!mounted) return;

      if (result != null) {
        final now = DateTime.now();
        final durationSeconds = result.metadata.scanDuration.inSeconds.toDouble();
        final startedAt = now.subtract(Duration(seconds: durationSeconds.toInt()));

        final scanData = ScanData(
          id: const Uuid().v4(),
          projectId: widget.project.id,
          projectName: widget.project.name,
          startedAt: startedAt,
          completedAt: now,
          pointsCollected: (result.room.walls.length +
                  result.room.doors.length +
                  result.room.windows.length) *
              100,
          durationSeconds: durationSeconds,
          isGuestMode: false,
          status: ScanStatus.completed,
        );

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ScanCompleteScreen(
              scanData: scanData,
              thumbnailPath: null,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scan was cancelled'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during scan: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Show menu
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Project Detail',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Workspace • Updated 2h ago',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(50),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(50),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade600,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Viewer'),
                Tab(text: 'Project data'),
                Tab(text: 'Products'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildViewerTab(context, theme),
                _buildProjectDataTab(context, theme),
                _buildProductsTab(context, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewerTab(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '3D / VR viewer',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // VR Viewer placeholder
          Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade900,
                  Colors.blue.shade700,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.8),
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.view_in_ar,
                      color: Colors.white.withOpacity(0.8),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'VR scene will load here',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Embedded via secure iFrame viewer',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Open VR viewer
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('VR viewer - Coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('View project'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Share link
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Share link - Coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share link'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Add Room Scan button (iOS only)
          if (Platform.isIOS) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (!_isCheckingLidar && _canScanWithLidar)
                    ? () => _startRoomScanForProject(context)
                    : null,
                icon: const Icon(Icons.view_in_ar),
                label: const Text('Add Room Scan'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Shareable link
          Text(
            'Shareable link',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'https://app.example.com/p/${widget.project.slug}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: 'https://app.example.com/p/${widget.project.slug}',
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Copy'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectDataTab(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Project master data',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Tap fields to edit',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Name field
          Text(
            'Name',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade200,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: theme.textTheme.bodyLarge,
          ),

          const SizedBox(height: 20),

          // Slug field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Slug',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Used in share links',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _slugController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Description field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Description',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Optional',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Save button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Last edited 3 min ago',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Save changes
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Saved successfully'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text('Save changes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Products',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
