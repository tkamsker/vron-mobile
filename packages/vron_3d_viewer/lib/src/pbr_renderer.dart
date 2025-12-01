import 'package:three_dart/three_dart.dart' as three;

/// PBR (Physically Based Rendering) material renderer for VRON 3D viewer
///
/// Handles rendering of PBR materials with support for:
/// - Albedo (base color) maps
/// - Normal maps for surface detail
/// - Metallic maps for metal/non-metal surfaces
/// - Roughness maps for surface glossiness
/// - Ambient occlusion (AO) maps
/// - Emissive maps for self-illumination
class PbrRenderer {
  late three.WebGLRenderer _renderer;
  late three.Scene _scene;
  late three.PerspectiveCamera _camera;
  
  /// Initialize the PBR renderer with scene and camera
  void initialize({
    required three.WebGLRenderer renderer,
    required three.Scene scene,
    required three.PerspectiveCamera camera,
  }) {
    _renderer = renderer;
    _scene = scene;
    _camera = camera;
    
    // Configure renderer for PBR
    _renderer.physicallyCorrectLights = true;
    _renderer.toneMapping = three.ACESFilmicToneMapping;
    _renderer.toneMappingExposure = 1.0;
    _renderer.outputEncoding = three.sRGBEncoding;
  }

  /// Setup default PBR lighting for the scene
  void setupLighting() {
    // Add ambient light for base illumination
    final ambientLight = three.AmbientLight(0xffffff, 0.5);
    _scene.add(ambientLight);
    
    // Add directional light for main illumination
    final directionalLight = three.DirectionalLight(0xffffff, 0.8);
    directionalLight.position.set(5, 10, 7.5);
    directionalLight.castShadow = true;
    _scene.add(directionalLight);
    
    // Add hemisphere light for environmental lighting
    final hemisphereLight = three.HemisphereLight(0xffffff, 0x444444, 0.6);
    hemisphereLight.position.set(0, 20, 0);
    _scene.add(hemisphereLight);
  }

  /// Apply PBR material properties to a mesh
  void applyPbrMaterial(
    three.Mesh mesh, {
    three.Color? albedo,
    three.Texture? albedoMap,
    three.Texture? normalMap,
    double? metalness,
    three.Texture? metalnessMap,
    double? roughness,
    three.Texture? roughnessMap,
    three.Texture? aoMap,
    three.Color? emissive,
    three.Texture? emissiveMap,
  }) {
    final material = three.MeshStandardMaterial({
      'color': albedo?.getHex() ?? 0xffffff,
      'map': albedoMap,
      'normalMap': normalMap,
      'metalness': metalness ?? 0.0,
      'metalnessMap': metalnessMap,
      'roughness': roughness ?? 1.0,
      'roughnessMap': roughnessMap,
      'aoMap': aoMap,
      'emissive': emissive?.getHex() ?? 0x000000,
      'emissiveMap': emissiveMap,
    });
    
    mesh.material = material;
  }

  /// Update material metalness for all meshes in the model
  void updateMetalness(three.Object3D model, double metalness) {
    model.traverse((child) {
      if (child is three.Mesh) {
        final material = child.material;
        if (material is three.MeshStandardMaterial) {
          material.metalness = metalness;
          material.needsUpdate = true;
        }
      }
    });
  }

  /// Update material roughness for all meshes in the model
  void updateRoughness(three.Object3D model, double roughness) {
    model.traverse((child) {
      if (child is three.Mesh) {
        final material = child.material;
        if (material is three.MeshStandardMaterial) {
          material.roughness = roughness;
          material.needsUpdate = true;
        }
      }
    });
  }

  /// Toggle wireframe mode for all meshes
  void setWireframe(three.Object3D model, bool enabled) {
    model.traverse((child) {
      if (child is three.Mesh) {
        final material = child.material;
        if (material is three.Material) {
          material.wireframe = enabled;
          material.needsUpdate = true;
        }
      }
    });
  }

  /// Update environment map for reflections
  void updateEnvironmentMap(three.Object3D model, three.Texture? envMap) {
    model.traverse((child) {
      if (child is three.Mesh) {
        final material = child.material;
        if (material is three.MeshStandardMaterial) {
          material.envMap = envMap;
          material.needsUpdate = true;
        }
      }
    });
  }

  /// Render the scene
  void render() {
    _renderer.render(_scene, _camera);
  }

  /// Get material properties from a mesh
  Map<String, dynamic> getMaterialProperties(three.Mesh mesh) {
    final material = mesh.material;
    if (material is! three.MeshStandardMaterial) {
      return {};
    }

    return {
      'hasAlbedoMap': material.map != null,
      'hasNormalMap': material.normalMap != null,
      'hasMetalnessMap': material.metalnessMap != null,
      'hasRoughnessMap': material.roughnessMap != null,
      'hasAoMap': material.aoMap != null,
      'hasEmissiveMap': material.emissiveMap != null,
      'metalness': material.metalness,
      'roughness': material.roughness,
      'color': material.color?.getHex() ?? 0xffffff,
      'emissive': material.emissive?.getHex() ?? 0x000000,
    };
  }

  /// Count materials in the model
  int getMaterialCount(three.Object3D model) {
    final materials = <three.Material>{};
    
    model.traverse((child) {
      if (child is three.Mesh) {
        final material = child.material;
        if (material is three.Material) {
          materials.add(material);
        }
      }
    });
    
    return materials.length;
  }

  /// Dispose of renderer resources
  void dispose() {
    _renderer.dispose();
  }
}
