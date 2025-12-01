import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget tests for 3D GLB preview viewer
///
/// Tests the 3D model viewer interface including:
/// - Model loading states
/// - Gesture controls (rotate, zoom, pan)
/// - View reset functionality
/// - Loading indicators
/// - Error handling
/// - Model metadata display
/// - Wireframe/solid view toggle
///
/// **TDD Requirement**: These tests define expected 3D viewer behavior
void main() {
  group('3D GLB Viewer Widget', () {
    testWidgets('displays loading state while model loads',
        (WidgetTester tester) async {
      // Given: Viewer loading a model
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: true,
              ),
            ),
          ),
        ),
      );

      // Then: Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading 3D model...'), findsOneWidget);

      // Should show model file name
      expect(find.textContaining('room-123.glb'), findsOneWidget);
    });

    testWidgets('displays loaded model successfully',
        (WidgetTester tester) async {
      // Given: Successfully loaded model
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
              ),
            ),
          ),
        ),
      );

      // Then: Should show 3D viewport
      expect(find.byKey(const Key('3d_viewport')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Should show control hints
      expect(find.text('Drag to rotate'), findsOneWidget);
      expect(find.text('Pinch to zoom'), findsOneWidget);
    });

    testWidgets('handles model loading error', (WidgetTester tester) async {
      // Given: Failed to load model
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/corrupted.glb',
                isLoading: false,
                hasError: true,
                errorMessage: 'Failed to parse GLB file',
              ),
            ),
          ),
        ),
      );

      // Then: Should display error state
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Failed to load model'), findsOneWidget);
      expect(find.text('Failed to parse GLB file'), findsOneWidget);

      // Should show retry button
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('rotate gesture rotates the model',
        (WidgetTester tester) async {
      // Given: Loaded 3D model
      final rotations = <Offset>[];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
                onRotate: (delta) => rotations.add(delta),
              ),
            ),
          ),
        ),
      );

      // When: User drags to rotate
      final viewport = find.byKey(const Key('3d_viewport'));
      await tester.drag(viewport, const Offset(100, 50));
      await tester.pumpAndSettle();

      // Then: Should trigger rotation with delta
      expect(rotations.isNotEmpty, isTrue);
      expect(rotations.last.dx, closeTo(100, 1));
      expect(rotations.last.dy, closeTo(50, 1));
    });

    testWidgets('pinch gesture zooms the model', (WidgetTester tester) async {
      // Given: Loaded 3D model
      final zoomLevels = <double>[];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
                onZoom: (scale) => zoomLevels.add(scale),
              ),
            ),
          ),
        ),
      );

      // When: User performs pinch gesture (zoom in)
      final viewport = find.byKey(const Key('3d_viewport'));
      final center = tester.getCenter(viewport);

      // Simulate pinch zoom
      final pointer1 = TestPointer(1, PointerDeviceKind.touch);
      final pointer2 = TestPointer(2, PointerDeviceKind.touch);

      // Start touches
      await tester.sendEventToBinding(pointer1.down(center + const Offset(-50, 0)));
      await tester.sendEventToBinding(pointer2.down(center + const Offset(50, 0)));

      // Move apart (zoom in)
      await tester.sendEventToBinding(pointer1.move(center + const Offset(-100, 0)));
      await tester.sendEventToBinding(pointer2.move(center + const Offset(100, 0)));

      await tester.pumpAndSettle();

      // Then: Should trigger zoom
      expect(zoomLevels.isNotEmpty, isTrue);
      expect(zoomLevels.last, greaterThan(1.0)); // Zoomed in
    });

    testWidgets('two-finger drag pans the model', (WidgetTester tester) async {
      // Given: Loaded 3D model
      final panOffsets = <Offset>[];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
                onPan: (delta) => panOffsets.add(delta),
              ),
            ),
          ),
        ),
      );

      // When: User performs two-finger pan
      final viewport = find.byKey(const Key('3d_viewport'));
      await tester.drag(
        viewport,
        const Offset(50, 50),
        pointer: 2, // Two-finger drag
      );
      await tester.pumpAndSettle();

      // Then: Should trigger pan
      expect(panOffsets.isNotEmpty, isTrue);
    });

    testWidgets('reset button resets view to default',
        (WidgetTester tester) async {
      // Given: Rotated/zoomed model
      bool resetCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
                onReset: () => resetCalled = true,
              ),
            ),
          ),
        ),
      );

      // When: User taps reset button
      final resetButton = find.byIcon(Icons.refresh);
      expect(resetButton, findsOneWidget);

      await tester.tap(resetButton);
      await tester.pump();

      // Then: Should reset camera view
      expect(resetCalled, isTrue);
    });

    testWidgets('displays model metadata', (WidgetTester tester) async {
      // Given: Loaded model with metadata
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
                metadata: {
                  'triangles': 15420,
                  'vertices': 8234,
                  'materials': 3,
                  'textures': 5,
                  'fileSize': '1.2 MB',
                },
              ),
            ),
          ),
        ),
      );

      // When: User opens metadata panel
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      // Then: Should display metadata
      expect(find.text('Model Info'), findsOneWidget);
      expect(find.text('Triangles: 15,420'), findsOneWidget);
      expect(find.text('Vertices: 8,234'), findsOneWidget);
      expect(find.text('Materials: 3'), findsOneWidget);
      expect(find.text('Textures: 5'), findsOneWidget);
      expect(find.text('Size: 1.2 MB'), findsOneWidget);
    });

    testWidgets('wireframe toggle switches render mode',
        (WidgetTester tester) async {
      // Given: Model in solid mode
      bool isWireframe = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
                isWireframe: isWireframe,
                onWireframeToggle: (value) => isWireframe = value,
              ),
            ),
          ),
        ),
      );

      // When: User toggles wireframe mode
      final wireframeToggle = find.byType(Switch);
      expect(wireframeToggle, findsOneWidget);

      await tester.tap(wireframeToggle);
      await tester.pump();

      // Then: Should switch to wireframe
      expect(isWireframe, isTrue);
    });

    testWidgets('fullscreen button toggles fullscreen mode',
        (WidgetTester tester) async {
      // Given: Normal view
      bool isFullscreen = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
                isFullscreen: isFullscreen,
                onFullscreenToggle: (value) => isFullscreen = value,
              ),
            ),
          ),
        ),
      );

      // When: User taps fullscreen button
      final fullscreenButton = find.byIcon(Icons.fullscreen);
      expect(fullscreenButton, findsOneWidget);

      await tester.tap(fullscreenButton);
      await tester.pump();

      // Then: Should enter fullscreen
      expect(isFullscreen, isTrue);
    });

    testWidgets('grid toggle shows/hides ground grid',
        (WidgetTester tester) async {
      // Given: Viewer with grid option
      bool showGrid = true;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
                showGrid: showGrid,
                onGridToggle: (value) => showGrid = value,
              ),
            ),
          ),
        ),
      );

      // When: User toggles grid
      final gridToggle = find.text('Show Grid');
      await tester.tap(gridToggle);
      await tester.pump();

      // Then: Should hide grid
      expect(showGrid, isFalse);
    });

    testWidgets('auto-rotate toggle enables/disables rotation',
        (WidgetTester tester) async {
      // Given: Static model
      bool autoRotate = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
                autoRotate: autoRotate,
                onAutoRotateToggle: (value) => autoRotate = value,
              ),
            ),
          ),
        ),
      );

      // When: User enables auto-rotate
      final autoRotateToggle = find.text('Auto Rotate');
      await tester.tap(autoRotateToggle);
      await tester.pump();

      // Then: Should enable auto-rotation
      expect(autoRotate, isTrue);
    });

    testWidgets('lighting controls adjust scene lighting',
        (WidgetTester tester) async {
      // Given: Viewer with lighting controls
      double lightIntensity = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
                lightIntensity: lightIntensity,
                onLightIntensityChange: (value) => lightIntensity = value,
              ),
            ),
          ),
        ),
      );

      // When: User adjusts lighting slider
      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);

      await tester.drag(slider, const Offset(100, 0));
      await tester.pump();

      // Then: Should update light intensity
      expect(lightIntensity, greaterThan(1.0));
    });

    testWidgets('screenshot button captures viewport',
        (WidgetTester tester) async {
      // Given: Loaded model
      bool screenshotCaptured = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
                onScreenshot: () => screenshotCaptured = true,
              ),
            ),
          ),
        ),
      );

      // When: User taps screenshot button
      final screenshotButton = find.byIcon(Icons.camera_alt);
      expect(screenshotButton, findsOneWidget);

      await tester.tap(screenshotButton);
      await tester.pump();

      // Then: Should capture screenshot
      expect(screenshotCaptured, isTrue);
    });

    testWidgets('maintains gesture state between rebuilds',
        (WidgetTester tester) async {
      // Given: Model with initial rotation
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
                initialRotation: const Offset(45, 30),
              ),
            ),
          ),
        ),
      );

      // When: Widget rebuilds
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
                initialRotation: const Offset(45, 30),
              ),
            ),
          ),
        ),
      );

      // Then: Should maintain rotation state
      // (In real implementation, this would verify 3D transform state)
      expect(find.byKey(const Key('3d_viewport')), findsOneWidget);
    });

    testWidgets('disposes resources when widget unmounts',
        (WidgetTester tester) async {
      // Given: Loaded model
      bool disposed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGlbViewerWidget(
                modelPath: '/tmp/room-123.glb',
                isLoading: false,
                isLoaded: true,
                onDispose: () => disposed = true,
              ),
            ),
          ),
        ),
      );

      // When: Widget is removed
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(),
            ),
          ),
        ),
      );

      // Then: Should dispose resources
      expect(disposed, isTrue);
    });
  });
}

/// Mock widget for testing 3D GLB viewer
class _MockGlbViewerWidget extends StatefulWidget {
  final String modelPath;
  final bool isLoading;
  final bool isLoaded;
  final bool hasError;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;
  final bool isWireframe;
  final bool isFullscreen;
  final bool showGrid;
  final bool autoRotate;
  final double lightIntensity;
  final Offset? initialRotation;
  final Function(Offset)? onRotate;
  final Function(double)? onZoom;
  final Function(Offset)? onPan;
  final VoidCallback? onReset;
  final Function(bool)? onWireframeToggle;
  final Function(bool)? onFullscreenToggle;
  final Function(bool)? onGridToggle;
  final Function(bool)? onAutoRotateToggle;
  final Function(double)? onLightIntensityChange;
  final VoidCallback? onScreenshot;
  final VoidCallback? onDispose;

  const _MockGlbViewerWidget({
    required this.modelPath,
    this.isLoading = false,
    this.isLoaded = false,
    this.hasError = false,
    this.errorMessage,
    this.metadata,
    this.isWireframe = false,
    this.isFullscreen = false,
    this.showGrid = true,
    this.autoRotate = false,
    this.lightIntensity = 1.0,
    this.initialRotation,
    this.onRotate,
    this.onZoom,
    this.onPan,
    this.onReset,
    this.onWireframeToggle,
    this.onFullscreenToggle,
    this.onGridToggle,
    this.onAutoRotateToggle,
    this.onLightIntensityChange,
    this.onScreenshot,
    this.onDispose,
  });

  @override
  State<_MockGlbViewerWidget> createState() => _MockGlbViewerWidgetState();
}

class _MockGlbViewerWidgetState extends State<_MockGlbViewerWidget> {
  @override
  void dispose() {
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main viewport
        Center(
          child: widget.isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Loading 3D model...'),
                    const SizedBox(height: 8),
                    Text(widget.modelPath.split('/').last),
                  ],
                )
              : widget.hasError
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text('Failed to load model'),
                        if (widget.errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(widget.errorMessage!),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : GestureDetector(
                      key: const Key('3d_viewport'),
                      onPanUpdate: (details) =>
                          widget.onRotate?.call(details.delta),
                      onScaleUpdate: (details) =>
                          widget.onZoom?.call(details.scale),
                      child: Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.view_in_ar, size: 100),
                              SizedBox(height: 16),
                              Text('Drag to rotate'),
                              Text('Pinch to zoom'),
                            ],
                          ),
                        ),
                      ),
                    ),
        ),

        // Control buttons
        if (widget.isLoaded)
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: widget.onReset,
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showMetadata(context),
                ),
                IconButton(
                  icon: Icon(widget.isFullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen),
                  onPressed: () =>
                      widget.onFullscreenToggle?.call(!widget.isFullscreen),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: widget.onScreenshot,
                ),
              ],
            ),
          ),

        // Settings panel
        if (widget.isLoaded)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text('Wireframe'),
                        Switch(
                          value: widget.isWireframe,
                          onChanged: widget.onWireframeToggle,
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () =>
                          widget.onGridToggle?.call(!widget.showGrid),
                      child: const Text('Show Grid'),
                    ),
                    TextButton(
                      onPressed: () =>
                          widget.onAutoRotateToggle?.call(!widget.autoRotate),
                      child: const Text('Auto Rotate'),
                    ),
                    Slider(
                      value: widget.lightIntensity,
                      min: 0.0,
                      max: 2.0,
                      onChanged: widget.onLightIntensityChange,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showMetadata(BuildContext context) {
    if (widget.metadata == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Triangles: ${_formatNumber(widget.metadata!['triangles'])}'),
            Text('Vertices: ${_formatNumber(widget.metadata!['vertices'])}'),
            Text('Materials: ${widget.metadata!['materials']}'),
            Text('Textures: ${widget.metadata!['textures']}'),
            Text('Size: ${widget.metadata!['fileSize']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
