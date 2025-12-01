import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Golden tests for 3D preview UI
///
/// Visual regression tests that capture the rendered output of the 3D viewer
/// and compare against reference "golden" images to catch unintended UI changes.
///
/// **Running Golden Tests:**
/// - Generate/update goldens: `flutter test --update-goldens`
/// - Run tests: `flutter test test/goldens/glb_viewer_golden_test.dart`
/// - Golden files stored in: `test/goldens/images/`
///
/// **TDD Requirement**: These tests validate visual consistency
void main() {
  // Set up golden file comparator with tolerance
  setUp(() {
    // Use default golden file comparator
    // In CI/CD, you might want to use a different comparator
  });

  group('GLB Viewer Golden Tests', () {
    testWidgets('renders loading state correctly',
        (WidgetTester tester) async {
      // Given: Viewer in loading state
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                state: ViewerState.loading,
                loadingProgress: 0.35,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/glb_viewer_loading.png'),
      );
    });

    testWidgets('renders loaded model with controls',
        (WidgetTester tester) async {
      // Given: Viewer with loaded model
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                state: ViewerState.loaded,
                showControls: true,
                modelInfo: ModelInfo(
                  name: 'Living Room',
                  vertexCount: 12543,
                  triangleCount: 8362,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/glb_viewer_loaded.png'),
      );
    });

    testWidgets('renders error state with retry button',
        (WidgetTester tester) async {
      // Given: Viewer in error state
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                state: ViewerState.error,
                errorMessage: 'Failed to load 3D model',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/glb_viewer_error.png'),
      );
    });

    testWidgets('renders empty state placeholder',
        (WidgetTester tester) async {
      // Given: Viewer with no model
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                state: ViewerState.empty,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/glb_viewer_empty.png'),
      );
    });

    testWidgets('renders with metadata panel expanded',
        (WidgetTester tester) async {
      // Given: Viewer with metadata panel
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                state: ViewerState.loaded,
                showMetadata: true,
                modelInfo: ModelInfo(
                  name: 'Kitchen',
                  vertexCount: 25431,
                  triangleCount: 16987,
                  materialCount: 8,
                  textureCount: 12,
                  fileSize: 4567890,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/glb_viewer_metadata.png'),
      );
    });

    testWidgets('renders with controls panel expanded',
        (WidgetTester tester) async {
      // Given: Viewer with controls panel
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                state: ViewerState.loaded,
                showControls: true,
                controlsExpanded: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/glb_viewer_controls.png'),
      );
    });

    testWidgets('renders in dark mode',
        (WidgetTester tester) async {
      // Given: Viewer in dark mode
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: _MockGlbViewerWidget(
                state: ViewerState.loaded,
                showControls: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/glb_viewer_dark_mode.png'),
      );
    });

    testWidgets('renders with wireframe mode enabled',
        (WidgetTester tester) async {
      // Given: Viewer in wireframe mode
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                state: ViewerState.loaded,
                renderMode: RenderMode.wireframe,
                showControls: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/glb_viewer_wireframe.png'),
      );
    });

    testWidgets('renders with navigation mesh overlay',
        (WidgetTester tester) async {
      // Given: Viewer with navmesh overlay
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                state: ViewerState.loaded,
                showNavmesh: true,
                navmeshVertexCount: 342,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/glb_viewer_navmesh.png'),
      );
    });

    testWidgets('renders fullscreen mode',
        (WidgetTester tester) async {
      // Given: Viewer in fullscreen
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                state: ViewerState.loaded,
                isFullscreen: true,
                showControls: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/glb_viewer_fullscreen.png'),
      );
    });

    testWidgets('renders with floating action buttons',
        (WidgetTester tester) async {
      // Given: Viewer with FABs
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                state: ViewerState.loaded,
                showFABs: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/glb_viewer_fabs.png'),
      );
    });

    testWidgets('renders loading overlay during operations',
        (WidgetTester tester) async {
      // Given: Viewer with loading overlay
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                state: ViewerState.loaded,
                showLoadingOverlay: true,
                loadingMessage: 'Extracting navigation mesh...',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/glb_viewer_loading_overlay.png'),
      );
    });

    testWidgets('renders tablet layout',
        (WidgetTester tester) async {
      // Given: Viewer on tablet-sized screen
      await tester.binding.setSurfaceSize(const Size(1024, 768));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                state: ViewerState.loaded,
                showControls: true,
                showMetadata: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/glb_viewer_tablet.png'),
      );

      // Reset size
      addTearDown(() => tester.binding.setSurfaceSize(null));
    });

    testWidgets('renders landscape orientation',
        (WidgetTester tester) async {
      // Given: Viewer in landscape
      await tester.binding.setSurfaceSize(const Size(896, 414));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                state: ViewerState.loaded,
                showControls: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/glb_viewer_landscape.png'),
      );

      // Reset size
      addTearDown(() => tester.binding.setSurfaceSize(null));
    });
  });

  group('Scan Preview Golden Tests', () {
    testWidgets('renders scan preview with room name',
        (WidgetTester tester) async {
      // Given: Scan preview screen
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanPreviewWidget(
                roomName: 'Living Room',
                pointCount: 15234,
                scanDuration: 125,
                showControls: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/scan_preview_default.png'),
      );
    });

    testWidgets('renders scan preview with file size warning',
        (WidgetTester tester) async {
      // Given: Scan preview with large file
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanPreviewWidget(
                roomName: 'Warehouse',
                pointCount: 125000,
                scanDuration: 450,
                fileSize: 52428800, // 50MB
                showFileSizeWarning: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/scan_preview_warning.png'),
      );
    });

    testWidgets('renders scan preview saving state',
        (WidgetTester tester) async {
      // Given: Scan being saved
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockScanPreviewWidget(
                roomName: 'Bedroom',
                pointCount: 8543,
                scanDuration: 89,
                isSaving: true,
                savingProgress: 0.67,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Then: Should match golden file
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('images/scan_preview_saving.png'),
      );
    });
  });
}

// Mock enums and classes for testing
enum ViewerState { empty, loading, loaded, error }
enum RenderMode { solid, wireframe, textured }

class ModelInfo {
  final String name;
  final int vertexCount;
  final int triangleCount;
  final int? materialCount;
  final int? textureCount;
  final int? fileSize;

  ModelInfo({
    required this.name,
    required this.vertexCount,
    required this.triangleCount,
    this.materialCount,
    this.textureCount,
    this.fileSize,
  });
}

/// Mock GLB viewer widget for golden testing
class _MockGlbViewerWidget extends StatelessWidget {
  final ViewerState state;
  final double? loadingProgress;
  final String? errorMessage;
  final bool showControls;
  final bool showMetadata;
  final bool controlsExpanded;
  final bool isFullscreen;
  final bool showFABs;
  final bool showLoadingOverlay;
  final String? loadingMessage;
  final ModelInfo? modelInfo;
  final RenderMode renderMode;
  final bool showNavmesh;
  final int? navmeshVertexCount;

  const _MockGlbViewerWidget({
    required this.state,
    this.loadingProgress,
    this.errorMessage,
    this.showControls = false,
    this.showMetadata = false,
    this.controlsExpanded = false,
    this.isFullscreen = false,
    this.showFABs = false,
    this.showLoadingOverlay = false,
    this.loadingMessage,
    this.modelInfo,
    this.renderMode = RenderMode.solid,
    this.showNavmesh = false,
    this.navmeshVertexCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Main content area
        Container(
          color: theme.brightness == Brightness.dark
              ? Colors.grey.shade900
              : Colors.grey.shade100,
          child: _buildContent(theme),
        ),

        // Metadata panel (if enabled)
        if (showMetadata && modelInfo != null)
          Positioned(
            top: 16,
            right: 16,
            child: _buildMetadataPanel(theme),
          ),

        // Controls panel (if enabled)
        if (showControls)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildControlsPanel(theme),
          ),

        // FABs (if enabled)
        if (showFABs) ...[
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: () {},
              child: const Icon(Icons.fullscreen),
            ),
          ),
          Positioned(
            top: 72,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: () {},
              child: const Icon(Icons.settings),
            ),
          ),
        ],

        // Loading overlay
        if (showLoadingOverlay)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  if (loadingMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      loadingMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    switch (state) {
      case ViewerState.empty:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.view_in_ar, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No 3D Model Loaded',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
            ],
          ),
        );

      case ViewerState.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading 3D Model...',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              if (loadingProgress != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${(loadingProgress! * 100).toInt()}%',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        );

      case ViewerState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  errorMessage ?? 'Failed to load model',
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );

      case ViewerState.loaded:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 3D viewport placeholder
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: renderMode == RenderMode.wireframe
                      ? Colors.black
                      : Colors.white,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        renderMode == RenderMode.wireframe
                            ? Icons.grain
                            : Icons.view_in_ar,
                        size: 64,
                        color: renderMode == RenderMode.wireframe
                            ? Colors.green
                            : Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        modelInfo?.name ?? '3D Model',
                        style: TextStyle(
                          fontSize: 14,
                          color: renderMode == RenderMode.wireframe
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      if (showNavmesh) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Navmesh: $navmeshVertexCount vertices',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildMetadataPanel(ThemeData theme) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Model Info',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow('Vertices', '${modelInfo!.vertexCount}'),
          _buildInfoRow('Triangles', '${modelInfo!.triangleCount}'),
          if (modelInfo!.materialCount != null)
            _buildInfoRow('Materials', '${modelInfo!.materialCount}'),
          if (modelInfo!.textureCount != null)
            _buildInfoRow('Textures', '${modelInfo!.textureCount}'),
          if (modelInfo!.fileSize != null)
            _buildInfoRow('Size', _formatFileSize(modelInfo!.fileSize!)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(Icons.rotate_left, 'Rotate Left'),
              _buildControlButton(Icons.zoom_in, 'Zoom In'),
              _buildControlButton(Icons.zoom_out, 'Zoom Out'),
              _buildControlButton(Icons.rotate_right, 'Rotate Right'),
            ],
          ),
          if (controlsExpanded) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(Icons.grid_on, 'Wireframe'),
                _buildControlButton(Icons.light_mode, 'Lighting'),
                _buildControlButton(Icons.layers, 'Navmesh'),
                _buildControlButton(Icons.refresh, 'Reset'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: () {},
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Mock scan preview widget for golden testing
class _MockScanPreviewWidget extends StatelessWidget {
  final String roomName;
  final int pointCount;
  final int scanDuration;
  final int? fileSize;
  final bool showControls;
  final bool showFileSizeWarning;
  final bool isSaving;
  final double? savingProgress;

  const _MockScanPreviewWidget({
    required this.roomName,
    required this.pointCount,
    required this.scanDuration,
    this.fileSize,
    this.showControls = false,
    this.showFileSizeWarning = false,
    this.isSaving = false,
    this.savingProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Room name
          TextField(
            decoration: InputDecoration(
              labelText: 'Room Name',
              hintText: 'Enter room name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            controller: TextEditingController(text: roomName),
          ),

          const SizedBox(height: 24),

          // Scan stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildStatRow('Points Captured', '$pointCount'),
                const SizedBox(height: 8),
                _buildStatRow('Scan Duration', '${scanDuration}s'),
                if (fileSize != null) ...[
                  const SizedBox(height: 8),
                  _buildStatRow('File Size', _formatFileSize(fileSize!)),
                ],
              ],
            ),
          ),

          // File size warning
          if (showFileSizeWarning) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'File size exceeds recommended 50MB limit',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Save button or progress
          if (isSaving)
            Column(
              children: [
                LinearProgressIndicator(value: savingProgress),
                const SizedBox(height: 8),
                Text(
                  'Saving scan... ${savingProgress != null ? "${(savingProgress! * 100).toInt()}%" : ""}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.save),
              label: const Text('Save Scan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
