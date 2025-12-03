import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/projects/screens/projects_list_screen.dart';
import '../../features/scan/screens/scan_complete_screen.dart';
import '../../features/scan/screens/scan_sessions_screen.dart';
import '../../features/scan/models/scan_data.dart';
import '../auth/auth_notifier.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:roomplan_flutter/roomplan_flutter.dart';
import 'package:uuid/uuid.dart';

/// Main navigation screen with bottom navigation bar
///
/// Provides 4 main navigation tabs:
/// - Home: Dashboard/overview
/// - Projects: Project list
/// - AR/3D: AR scanning and 3D visualization
/// - Profile: User profile and settings
class MainNavigationScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex; // Use the provided initial index

    // Initialize screens with ScanSessionsScreen that shows all sessions
    _screens = [
      const ScanSessionsScreen(
        projectId: null, // Show all sessions, not filtered by project
        projectName: 'All Sessions',
      ),
      const ProjectsListScreen(),
      const _ARScreen(),
      const _ProfileScreen(),
    ];
  }

  // Navigation screens
  late final List<Widget> _screens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
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
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                // From Sessions tab, switch to the Scan tab so the user
                // always starts scans from a single entry screen.
                setState(() {
                  _currentIndex = 2; // Scan tab
                });
              },
              child: const Icon(Icons.add),
            )
          : _currentIndex == 1
              ? FloatingActionButton(
                  onPressed: () {
                    // TODO: Implement create new project
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Create new project - Coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Icon(Icons.add),
                )
              : null,
    );
  }
}

/// AR/3D screen with scan functionality
///
/// This mirrors the RoomPlan example app:
/// - Checks `RoomPlanScanner.isSupported()` once on load
/// - Shows a clear status message about hardware support
/// - Uses a single "Start Room Scan" entry point that opens the native RoomPlan dialog
class _ARScreen extends ConsumerStatefulWidget {
  const _ARScreen();

  @override
  ConsumerState<_ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends ConsumerState<_ARScreen> {
  bool _isCheckingSupport = true;
  bool _isRoomPlanSupported = false;
  bool _isScanning = false;
  late final RoomPlanScanner _roomScanner;

  @override
  void initState() {
    super.initState();
    _roomScanner = RoomPlanScanner();
    _checkRoomPlanSupport();
  }

  @override
  void dispose() {
    _roomScanner.dispose();
    super.dispose();
  }

  Future<void> _checkRoomPlanSupport() async {
    try {
      final supported = await RoomPlanScanner.isSupported();
      if (!mounted) return;
      setState(() {
        _isRoomPlanSupported = supported;
        _isCheckingSupport = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRoomPlanSupported = false;
        _isCheckingSupport = false;
      });
    }
  }

  Future<void> _startRoomScan({String? projectId, String? projectName, required bool isGuest}) async {
    if (!_isRoomPlanSupported || _isCheckingSupport || _isScanning) return;

    setState(() {
      _isScanning = true;
    });

    try {
      // Ensure camera permission before starting RoomPlan
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

      // Use a simple configuration similar to the example app
      const configuration = ScanConfiguration(
        enableRealtimeUpdates: false,
        detectDoors: true,
        detectWindows: true,
      );

      final result = await _roomScanner.startScanning(configuration: configuration);

      if (!mounted) return;

      if (result != null) {
        // Create ScanData from the RoomPlan scan result
        final now = DateTime.now();
        final durationSeconds = result.metadata.scanDuration.inSeconds.toDouble();
        final startedAt = now.subtract(Duration(seconds: durationSeconds.toInt()));

        final scanData = ScanData(
          id: const Uuid().v4(),
          projectId: projectId,
          projectName: projectName,
          startedAt: startedAt,
          completedAt: now,
          pointsCollected: (result.room.walls.length +
                  result.room.doors.length +
                  result.room.windows.length) *
              100,
          durationSeconds: durationSeconds,
          isGuestMode: isGuest,
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
        // Scan was cancelled by user
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

  /// Debug helper: call RoomPlan directly with minimal checks,
  /// mirroring the example app behaviour as closely as possible.
  Future<void> _startRoomScanDebug() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
    });

    try {
      final result = await _roomScanner.startScanning();
      debugPrint('🔍 Debug RoomPlan startScanning result: $result');
    } catch (e, st) {
      debugPrint('❌ Debug RoomPlan startScanning error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debug start scan error: $e'),
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
    final authState = ref.watch(authNotifierProvider);
    final isGuest = !authState.isAuthenticated;

    final statusText = _isCheckingSupport
        ? 'Checking RoomPlan compatibility...'
        : _isRoomPlanSupported
            ? 'RoomPlan is supported on this device.'
            : 'RoomPlan is NOT supported on this device. Requires iOS 16+ and LiDAR.';

    final statusColor = _isCheckingSupport
        ? theme.colorScheme.onSurfaceVariant
        : _isRoomPlanSupported
            ? Colors.green.shade700
            : Colors.red.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AR/3D Scanning'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.view_in_ar,
              size: 120,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 32),
            Text(
              'Room Scanning',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Capture precise measurements of your environment using LiDAR and ARKit.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Start scan button (disabled when RoomPlan is not supported)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isRoomPlanSupported && !_isCheckingSupport && !_isScanning)
                    ? () => _startRoomScan(
                          projectId: null,
                          projectName: null,
                          isGuest: isGuest,
                        )
                    : null,
                icon: const Icon(Icons.play_arrow, size: 28),
                label: const Text(
                  'Start Room Scan',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Temporary debug button to call RoomPlan directly,
            // useful to compare behaviour with the example app.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isScanning ? null : _startRoomScanDebug,
                child: const Text('Debug: Start Room Scan (direct)'),
              ),
            ),

            // Guest mode info
            if (isGuest)
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
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Guest Mode: Scans are saved locally only. Sign in to sync to cloud.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // Features list
            _FeatureItem(
              icon: Icons.camera_alt_outlined,
              title: 'LiDAR Scanning',
              description: 'High-precision room measurement',
            ),
            const SizedBox(height: 16),
            _FeatureItem(
              icon: Icons.threed_rotation,
              title: '3D Model Generation',
              description: 'Automatic 3D reconstruction',
            ),
            const SizedBox(height: 16),
            _FeatureItem(
              icon: Icons.cloud_upload_outlined,
              title: 'Cloud Sync',
              description: isGuest
                  ? 'Sign in to enable cloud storage'
                  : 'Automatic cloud backup',
              disabled: isGuest,
            ),
          ],
        ),
      ),
    );
  }
}

/// Feature item widget
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool disabled;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opacity = disabled ? 0.5 : 1.0;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1 * opacity),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.primary.withOpacity(opacity),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: disabled
                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                      : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: disabled
                      ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Profile screen with logout
class _ProfileScreen extends ConsumerWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Profile header
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  authState.userEmail ?? 'User',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  authState.userId ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Settings section
          Text(
            'Settings',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifications - Coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('Privacy & Security'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy & Security - Coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Language'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'English',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Language settings - Coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Account section
          Text(
            'Account',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Help & Support - Coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('About - Coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Logout',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    // Show confirmation dialog
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(
                              'Logout',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && context.mounted) {
                      await ref.read(authNotifierProvider.notifier).signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (route) => false,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
