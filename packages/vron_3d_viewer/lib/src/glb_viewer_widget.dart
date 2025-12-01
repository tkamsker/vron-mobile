import 'package:flutter/material.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'dart:async';
import 'glb_loader.dart';
import 'pbr_renderer.dart';
import 'gesture_controller.dart';

/// GLB 3D Model Viewer Widget
///
/// A Flutter widget that displays and allows interaction with GLB 3D models.
/// 
/// Features:
/// - Load GLB files from file path
/// - PBR material rendering with realistic lighting
/// - Touch gesture controls (rotate, zoom, pan)
/// - Wireframe mode toggle
/// - Model metadata display
/// - Performance optimized with RepaintBoundary
///
/// Usage:
/// ```dart
/// GlbViewerWidget(
///   glbFilePath: '/path/to/model.glb',
///   onModelLoaded: (metadata) => print('Model loaded: $metadata'),
///   onError: (error) => print('Error: $error'),
/// )
/// ```
class GlbViewerWidget extends StatefulWidget {
  /// Path to the GLB file to load
  final String? glbFilePath;
  
  /// Callback when model is successfully loaded
  final Function(Map<String, dynamic> metadata)? onModelLoaded;
  
  /// Callback when an error occurs
  final Function(String error)? onError;
  
  /// Whether to show wireframe mode
  final bool showWireframe;
  
  /// Whether to show loading indicator
  final bool showLoadingIndicator;
  
  /// Background color
  final Color backgroundColor;
  
  /// Whether to auto-rotate the model
  final bool autoRotate;
  
  /// Auto-rotation speed (radians per frame)
  final double autoRotateSpeed;

  const GlbViewerWidget({
    Key? key,
    this.glbFilePath,
    this.onModelLoaded,
    this.onError,
    this.showWireframe = false,
    this.showLoadingIndicator = true,
    this.backgroundColor = Colors.grey,
    this.autoRotate = false,
    this.autoRotateSpeed = 0.01,
  }) : super(key: key);

  @override
  State<GlbViewerWidget> createState() => _GlbViewerWidgetState();
}

class _GlbViewerWidgetState extends State<GlbViewerWidget>
    with TickerProviderStateMixin {
  // Three.js components
  late three.WebGLRenderer _renderer;
  late three.Scene _scene;
  late three.PerspectiveCamera _camera;
  three.Object3D? _model;
  
  // Custom components
  late GlbLoader _loader;
  late PbrRenderer _pbrRenderer;
  GestureController? _gestureController;
  
  // State
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  Map<String, dynamic>? _modelMetadata;
  
  // Animation
  Timer? _renderTimer;
  
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(GlbViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.glbFilePath != oldWidget.glbFilePath) {
      _loadModel();
    }
    
    if (widget.showWireframe != oldWidget.showWireframe && _model != null) {
      _pbrRenderer.setWireframe(_model!, widget.showWireframe);
    }
  }

  @override
  void dispose() {
    _renderTimer?.cancel();
    _loader.dispose(_model);
    _pbrRenderer.dispose();
    _gestureController?.dispose();
    _renderer.dispose();
    super.dispose();
  }

  /// Initialize Three.js components
  void _initialize() {
    try {
      // Create renderer
      _renderer = three.WebGLRenderer({'antialias': true});
      _renderer.setPixelRatio(MediaQuery.of(context).devicePixelRatio);
      _renderer.shadowMap.enabled = true;
      
      // Create scene
      _scene = three.Scene();
      _scene.background = three.Color.fromHex(
        widget.backgroundColor.value & 0xFFFFFF,
      );
      
      // Create camera
      _camera = three.PerspectiveCamera(
        75,
        1.0, // Will be updated in layout
        0.1,
        1000,
      );
      _camera.position.set(0, 0, 5);
      
      // Initialize custom components
      _loader = GlbLoader();
      _pbrRenderer = PbrRenderer();
      _pbrRenderer.initialize(
        renderer: _renderer,
        scene: _scene,
        camera: _camera,
      );
      _pbrRenderer.setupLighting();
      
      _isInitialized = true;
      
      // Load model if path provided
      if (widget.glbFilePath != null) {
        _loadModel();
      }
      
      // Start render loop
      _startRenderLoop();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize viewer: $e';
      });
      widget.onError?.call(_error!);
    }
  }

  /// Load GLB model from file
  Future<void> _loadModel() async {
    if (widget.glbFilePath == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Dispose of previous model
      if (_model != null) {
        _scene.remove(_model!);
        _loader.dispose(_model);
      }

      // Load new model
      _model = await _loader.loadFromFile(widget.glbFilePath!);
      
      if (_model != null) {
        // Add to scene
        _scene.add(_model!);
        
        // Center and fit model in view
        _centerModel();
        
        // Setup gesture controller
        _gestureController = GestureController(
          camera: _camera,
          target: _model!,
        );
        
        // Apply wireframe if needed
        if (widget.showWireframe) {
          _pbrRenderer.setWireframe(_model!, true);
        }
        
        // Extract metadata
        _modelMetadata = {
          'vertexCount': _loader.getVertexCount(_model!),
          'triangleCount': _loader.getTriangleCount(_model!),
          'textureCount': _loader.getTextureCount(_model!),
          'materialCount': _pbrRenderer.getMaterialCount(_model!),
        };
        
        widget.onModelLoaded?.call(_modelMetadata!);
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load model: $e';
      });
      widget.onError?.call(_error!);
    }
  }

  /// Center model in viewport
  void _centerModel() {
    if (_model == null) return;
    
    final center = _loader.getCenter(_model!);
    _model!.position.sub(center);
    
    final size = _loader.getSize(_model!);
    final maxDim = [size.x, size.y, size.z].reduce((a, b) => a > b ? a : b);
    final fov = _camera.fov * (3.14159 / 180);
    final distance = maxDim / (2 * (fov / 2).tan());
    
    _camera.position.set(0, 0, distance * 1.5);
    _camera.lookAt(_scene.position);
  }

  /// Start render loop
  void _startRenderLoop() {
    _renderTimer = Timer.periodic(
      const Duration(milliseconds: 16), // ~60fps
      (_) {
        if (!_isInitialized) return;
        
        // Auto-rotate if enabled
        if (widget.autoRotate && _model != null) {
          _model!.rotation.y += widget.autoRotateSpeed;
        }
        
        _pbrRenderer.render();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary( // T131: Add RepaintBoundary for performance
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Update camera aspect ratio
          if (_isInitialized) {
            final aspectRatio = constraints.maxWidth / constraints.maxHeight;
            _camera.aspect = aspectRatio;
            _camera.updateProjectionMatrix();
            _renderer.setSize(
              constraints.maxWidth.toInt(),
              constraints.maxHeight.toInt(),
            );
          }

          return Stack(
            children: [
              // 3D Viewport
              GestureDetector(
                onPanUpdate: _gestureController?.handleDrag,
                onPanEnd: _gestureController?.handleDragEnd,
                onScaleUpdate: _gestureController?.handleScale,
                onScaleEnd: _gestureController?.handleScaleEnd,
                child: Container(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  color: widget.backgroundColor,
                  child: CustomPaint(
                    painter: _ThreeJsPainter(_renderer),
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                ),
              ),

              // Loading indicator
              if (_isLoading && widget.showLoadingIndicator)
                const Center(
                  child: CircularProgressIndicator(),
                ),

              // Error message
              if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Custom painter for Three.js renderer
class _ThreeJsPainter extends CustomPainter {
  final three.WebGLRenderer renderer;

  _ThreeJsPainter(this.renderer);

  @override
  void paint(Canvas canvas, Size size) {
    // Three.js renders to its own canvas/WebGL context
    // This painter is mainly for layout integration
  }

  @override
  bool shouldRepaint(_ThreeJsPainter oldDelegate) => true;
}
