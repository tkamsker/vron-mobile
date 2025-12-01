import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart_jsm/three_dart_jsm.dart' as three_jsm;

/// GLB model loader for VRON 3D viewer
///
/// Handles loading and parsing of GLB (GL Transmission Format Binary) files
/// with support for:
/// - Geometry loading
/// - Material loading
/// - Texture loading
/// - PBR material properties
class GlbLoader {
  final three_jsm.GLTFLoader _loader;
  
  GlbLoader() : _loader = three_jsm.GLTFLoader(null);

  /// Load a GLB file from the given file path
  ///
  /// Returns a Future that resolves to a three.Object3D containing the loaded model
  Future<three.Object3D?> loadFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('GLB file not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      return await loadFromBytes(bytes);
    } catch (e) {
      print('Error loading GLB file: $e');
      rethrow;
    }
  }

  /// Load a GLB file from byte data
  ///
  /// Returns a Future that resolves to a three.Object3D containing the loaded model
  Future<three.Object3D?> loadFromBytes(Uint8List bytes) async {
    try {
      // Parse GLB data
      final gltf = await _loader.parseAsync(bytes);
      
      if (gltf == null || gltf['scene'] == null) {
        throw Exception('Failed to parse GLB data');
      }

      final scene = gltf['scene'] as three.Group;
      
      // Process materials to ensure proper rendering
      scene.traverse((child) {
        if (child is three.Mesh) {
          _processMaterial(child);
        }
      });

      return scene;
    } catch (e) {
      print('Error loading GLB from bytes: $e');
      rethrow;
    }
  }

  /// Process mesh material to ensure proper PBR rendering
  void _processMaterial(three.Mesh mesh) {
    final material = mesh.material;
    
    if (material is three.MeshStandardMaterial) {
      // Ensure proper metallic/roughness workflow
      material.metalness ??= 0.0;
      material.roughness ??= 1.0;
      material.needsUpdate = true;
    }
  }

  /// Get model bounding box for camera positioning
  three.Box3 getBoundingBox(three.Object3D model) {
    final box = three.Box3(null, null);
    box.setFromObject(model);
    return box;
  }

  /// Get model center point
  three.Vector3 getCenter(three.Object3D model) {
    final box = getBoundingBox(model);
    final center = three.Vector3.init();
    box.getCenter(center);
    return center;
  }

  /// Get model size
  three.Vector3 getSize(three.Object3D model) {
    final box = getBoundingBox(model);
    final size = three.Vector3.init();
    box.getSize(size);
    return size;
  }

  /// Extract texture count from model
  int getTextureCount(three.Object3D model) {
    final textures = <three.Texture>{};
    
    model.traverse((child) {
      if (child is three.Mesh) {
        final material = child.material;
        if (material is three.MeshStandardMaterial) {
          if (material.map != null) textures.add(material.map!);
          if (material.normalMap != null) textures.add(material.normalMap!);
          if (material.roughnessMap != null) textures.add(material.roughnessMap!);
          if (material.metalnessMap != null) textures.add(material.metalnessMap!);
          if (material.aoMap != null) textures.add(material.aoMap!);
          if (material.emissiveMap != null) textures.add(material.emissiveMap!);
        }
      }
    });
    
    return textures.length;
  }

  /// Extract vertex count from model
  int getVertexCount(three.Object3D model) {
    int count = 0;
    
    model.traverse((child) {
      if (child is three.Mesh) {
        final geometry = child.geometry;
        if (geometry is three.BufferGeometry) {
          final position = geometry.attributes['position'];
          if (position != null) {
            count += (position.count ?? 0) as int;
          }
        }
      }
    });
    
    return count;
  }

  /// Extract triangle count from model
  int getTriangleCount(three.Object3D model) {
    int count = 0;
    
    model.traverse((child) {
      if (child is three.Mesh) {
        final geometry = child.geometry;
        if (geometry is three.BufferGeometry) {
          final index = geometry.index;
          if (index != null) {
            count += ((index.count ?? 0) / 3).floor();
          } else {
            final position = geometry.attributes['position'];
            if (position != null) {
              count += (((position.count ?? 0) / 3).floor());
            }
          }
        }
      }
    });
    
    return count;
  }

  /// Dispose of loaded model and free resources
  void dispose(three.Object3D? model) {
    if (model == null) return;
    
    model.traverse((child) {
      if (child is three.Mesh) {
        child.geometry?.dispose();
        
        final material = child.material;
        if (material is three.Material) {
          material.dispose();
          
          // Dispose textures
          if (material is three.MeshStandardMaterial) {
            material.map?.dispose();
            material.normalMap?.dispose();
            material.roughnessMap?.dispose();
            material.metalnessMap?.dispose();
            material.aoMap?.dispose();
            material.emissiveMap?.dispose();
          }
        }
      }
    });
  }
}
