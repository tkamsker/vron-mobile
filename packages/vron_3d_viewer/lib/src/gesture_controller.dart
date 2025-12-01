import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'dart:math' as math;

/// Gesture controller for 3D model interaction
///
/// Handles touch gestures for:
/// - Rotation: Single finger drag
/// - Zoom: Pinch gesture
/// - Pan: Two finger drag
class GestureController {
  final three.PerspectiveCamera camera;
  final three.Object3D target;
  
  // Rotation state
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  double _rotationSpeed = 0.005;
  
  // Zoom state
  double _zoom = 1.0;
  double _minZoom = 0.5;
  double _maxZoom = 3.0;
  
  // Pan state
  final three.Vector3 _panOffset = three.Vector3(0, 0, 0);
  double _panSpeed = 0.002;
  
  // Gesture tracking
  Offset? _lastDragPosition;
  double? _lastScale;
  
  GestureController({
    required this.camera,
    required this.target,
  });

  /// Configure rotation speed (default: 0.005)
  void setRotationSpeed(double speed) {
    _rotationSpeed = speed;
  }

  /// Configure zoom limits
  void setZoomLimits({double? min, double? max}) {
    if (min != null) _minZoom = min;
    if (max != null) _maxZoom = max;
  }

  /// Configure pan speed (default: 0.002)
  void setPanSpeed(double speed) {
    _panSpeed = speed;
  }

  /// Handle pan/drag gesture for rotation
  void handleDrag(DragUpdateDetails details) {
    if (_lastDragPosition == null) {
      _lastDragPosition = details.localPosition;
      return;
    }

    final delta = details.localPosition - _lastDragPosition!;
    
    // Update rotation based on drag delta
    _rotationY += delta.dx * _rotationSpeed;
    _rotationX += delta.dy * _rotationSpeed;
    
    // Clamp vertical rotation to avoid flipping
    _rotationX = _rotationX.clamp(-math.pi / 2, math.pi / 2);
    
    _updateTargetRotation();
    _lastDragPosition = details.localPosition;
  }

  /// Handle drag end
  void handleDragEnd(DragEndDetails details) {
    _lastDragPosition = null;
  }

  /// Handle scale gesture for zoom
  void handleScale(ScaleUpdateDetails details) {
    if (_lastScale == null) {
      _lastScale = details.scale;
      return;
    }

    final scaleDelta = details.scale - _lastScale!;
    _zoom = (_zoom - scaleDelta * 0.5).clamp(_minZoom, _maxZoom);
    
    _updateCamera();
    _lastScale = details.scale;
  }

  /// Handle scale end
  void handleScaleEnd(ScaleEndDetails details) {
    _lastScale = null;
  }

  /// Handle two-finger pan for translation
  void handleTwoFingerPan(Offset delta) {
    // Convert screen space delta to world space
    final right = three.Vector3(1, 0, 0);
    final up = three.Vector3(0, 1, 0);
    
    right.applyQuaternion(camera.quaternion);
    up.applyQuaternion(camera.quaternion);
    
    right.multiplyScalar(-delta.dx * _panSpeed);
    up.multiplyScalar(delta.dy * _panSpeed);
    
    _panOffset.add(right);
    _panOffset.add(up);
    
    _updateCamera();
  }

  /// Reset view to default state
  void reset() {
    _rotationX = 0.0;
    _rotationY = 0.0;
    _zoom = 1.0;
    _panOffset.set(0, 0, 0);
    _lastDragPosition = null;
    _lastScale = null;
    
    _updateTargetRotation();
    _updateCamera();
  }

  /// Update target rotation based on current rotation state
  void _updateTargetRotation() {
    target.rotation.set(_rotationX, _rotationY, 0);
  }

  /// Update camera position based on zoom and pan
  void _updateCamera() {
    // Calculate base camera position relative to target
    final distance = 5.0 / _zoom;
    
    // Position camera in front of target
    final cameraPos = three.Vector3(0, 0, distance);
    cameraPos.add(_panOffset);
    
    camera.position.copy(cameraPos);
    camera.lookAt(target.position);
  }

  /// Get current rotation angles in degrees
  Map<String, double> getRotation() {
    return {
      'x': _rotationX * 180 / math.pi,
      'y': _rotationY * 180 / math.pi,
    };
  }

  /// Get current zoom level
  double getZoom() => _zoom;

  /// Get current pan offset
  three.Vector3 getPanOffset() => _panOffset.clone();

  /// Animate rotation to specific angles
  Future<void> animateRotation({
    required double targetX,
    required double targetY,
    required Duration duration,
  }) async {
    final startX = _rotationX;
    final startY = _rotationY;
    final startTime = DateTime.now();

    while (true) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed >= duration) {
        _rotationX = targetX;
        _rotationY = targetY;
        _updateTargetRotation();
        break;
      }

      final progress = elapsed.inMilliseconds / duration.inMilliseconds;
      final eased = _easeInOutCubic(progress);

      _rotationX = startX + (targetX - startX) * eased;
      _rotationY = startY + (targetY - startY) * eased;
      _updateTargetRotation();

      await Future.delayed(const Duration(milliseconds: 16)); // ~60fps
    }
  }

  /// Animate zoom to specific level
  Future<void> animateZoom({
    required double targetZoom,
    required Duration duration,
  }) async {
    final startZoom = _zoom;
    final startTime = DateTime.now();

    while (true) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed >= duration) {
        _zoom = targetZoom.clamp(_minZoom, _maxZoom);
        _updateCamera();
        break;
      }

      final progress = elapsed.inMilliseconds / duration.inMilliseconds;
      final eased = _easeInOutCubic(progress);

      _zoom = (startZoom + (targetZoom - startZoom) * eased).clamp(_minZoom, _maxZoom);
      _updateCamera();

      await Future.delayed(const Duration(milliseconds: 16)); // ~60fps
    }
  }

  /// Ease-in-out cubic easing function
  double _easeInOutCubic(double t) {
    return t < 0.5
        ? 4 * t * t * t
        : 1 - math.pow(-2 * t + 2, 3) / 2;
  }

  /// Dispose of resources
  void dispose() {
    _lastDragPosition = null;
    _lastScale = null;
  }
}
