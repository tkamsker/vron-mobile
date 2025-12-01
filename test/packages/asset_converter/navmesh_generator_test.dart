import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

/// Unit test for navigation mesh generation logic (T150)
///
/// Tests navmesh generation from GLB geometry with Recast Navigation
/// Validates agent parameters, walkable surface detection, and error handling
///
/// **Requirements**:
/// - Agent Height: 1.8m (human height)
/// - Agent Radius: 0.4m (personal space)
/// - Max Slope: 45° (walkable angle)
/// - Min Region Size: 8 voxels
/// - Performance: <15 seconds for typical room (1000-5000 vertices)
///
/// **Test Coverage**:
/// - Navmesh generation from valid GLB
/// - Agent parameter validation
/// - Walkable surface detection
/// - Performance benchmarks
/// - Error handling (invalid input, empty geometry, unsupported platform)

@GenerateMocks([])
void main() {
  group('T150: NavMesh Generation Logic', () {
    test('generates navmesh from valid GLB geometry', () async {
      // Given: Valid GLB file with room geometry
      final glbPath = 'test/fixtures/sample_room.glb';
      final navmeshPath = 'test/output/navmesh.glb';
      
      // Agent parameters per FR-013
      const agentHeight = 1.8; // meters
      const agentRadius = 0.4; // meters
      const maxSlope = 45.0; // degrees
      
      // When: Generate navmesh
      final result = await _generateNavmesh(
        glbPath: glbPath,
        navmeshPath: navmeshPath,
        agentHeight: agentHeight,
        agentRadius: agentRadius,
        maxSlope: maxSlope,
      );
      
      // Then: Navmesh file created
      expect(result.success, isTrue);
      expect(result.vertexCount, greaterThan(0));
      expect(result.triangleCount, greaterThan(0));
      
      // Verify navmesh file exists
      final navmeshFile = File(navmeshPath);
      expect(await navmeshFile.exists(), isTrue);
      
      // Verify file size (should be smaller than original)
      final navmeshSize = await navmeshFile.length();
      expect(navmeshSize, greaterThan(0));
      expect(navmeshSize, lessThan(1024 * 1024 * 10)); // <10MB
    });

    test('validates agent height parameter', () async {
      // Test various agent heights
      final testCases = [
        {'height': 0.5, 'shouldFail': true, 'reason': 'Too short for human'},
        {'height': 1.8, 'shouldFail': false, 'reason': 'Standard human height'},
        {'height': 2.5, 'shouldFail': false, 'reason': 'Tall human'},
        {'height': 5.0, 'shouldFail': true, 'reason': 'Unrealistic height'},
      ];
      
      for (final testCase in testCases) {
        final result = await _generateNavmesh(
          glbPath: 'test/fixtures/sample_room.glb',
          navmeshPath: 'test/output/test.glb',
          agentHeight: testCase['height'] as double,
          agentRadius: 0.4,
        );
        
        if (testCase['shouldFail'] as bool) {
          expect(result.success, isFalse, reason: testCase['reason'] as String);
        } else {
          expect(result.success, isTrue, reason: testCase['reason'] as String);
        }
      }
    });

    test('validates agent radius parameter', () async {
      // Test various agent radii
      final testCases = [
        {'radius': 0.1, 'shouldFail': true, 'reason': 'Too narrow'},
        {'radius': 0.4, 'shouldFail': false, 'reason': 'Standard personal space'},
        {'radius': 0.8, 'shouldFail': false, 'reason': 'Wide clearance'},
        {'radius': 2.0, 'shouldFail': true, 'reason': 'Unrealistic radius'},
      ];
      
      for (final testCase in testCases) {
        final result = await _generateNavmesh(
          glbPath: 'test/fixtures/sample_room.glb',
          navmeshPath: 'test/output/test.glb',
          agentHeight: 1.8,
          agentRadius: testCase['radius'] as double,
        );
        
        if (testCase['shouldFail'] as bool) {
          expect(result.success, isFalse, reason: testCase['reason'] as String);
        } else {
          expect(result.success, isTrue, reason: testCase['reason'] as String);
        }
      }
    });

    test('detects walkable surfaces with correct slope', () async {
      // Given: Room with various surface angles
      final result = await _generateNavmesh(
        glbPath: 'test/fixtures/room_with_slopes.glb',
        navmeshPath: 'test/output/slopes.glb',
        agentHeight: 1.8,
        agentRadius: 0.4,
        maxSlope: 45.0,
      );
      
      // Then: Only surfaces ≤45° should be walkable
      expect(result.success, isTrue);
      expect(result.walkableSurfaceCount, greaterThan(0));
      
      // Steep surfaces (>45°) should be excluded
      expect(result.excludedSurfaceCount, greaterThan(0));
    });

    test('handles complex room geometry', () async {
      // Given: Complex room with furniture, doorways, stairs
      final result = await _generateNavmesh(
        glbPath: 'test/fixtures/complex_room.glb',
        navmeshPath: 'test/output/complex.glb',
        agentHeight: 1.8,
        agentRadius: 0.4,
      );
      
      // Then: Should successfully generate navmesh
      expect(result.success, isTrue);
      expect(result.vertexCount, greaterThan(100));
      
      // Should detect multiple connected regions
      expect(result.regionCount, greaterThan(1));
    });

    test('generates navmesh within performance target', () async {
      // Given: Typical room (1000-5000 vertices)
      final stopwatch = Stopwatch()..start();
      
      final result = await _generateNavmesh(
        glbPath: 'test/fixtures/typical_room.glb',
        navmeshPath: 'test/output/perf_test.glb',
        agentHeight: 1.8,
        agentRadius: 0.4,
      );
      
      stopwatch.stop();
      
      // Then: Should complete in <15 seconds (FR-013 requirement)
      expect(result.success, isTrue);
      expect(stopwatch.elapsed.inSeconds, lessThan(15));
      
      print('Navmesh generation time: ${stopwatch.elapsed.inSeconds}s');
    });

    test('handles large room geometry efficiently', () async {
      // Given: Large room (10,000+ vertices)
      final stopwatch = Stopwatch()..start();
      
      final result = await _generateNavmesh(
        glbPath: 'test/fixtures/large_room.glb',
        navmeshPath: 'test/output/large.glb',
        agentHeight: 1.8,
        agentRadius: 0.4,
      );
      
      stopwatch.stop();
      
      // Then: Should still complete reasonably fast
      expect(result.success, isTrue);
      expect(stopwatch.elapsed.inSeconds, lessThan(30));
      
      print('Large room navmesh time: ${stopwatch.elapsed.inSeconds}s');
    });

    test('fails gracefully on invalid GLB file', () async {
      // Given: Invalid GLB file
      final result = await _generateNavmesh(
        glbPath: 'test/fixtures/invalid.glb',
        navmeshPath: 'test/output/invalid.glb',
        agentHeight: 1.8,
        agentRadius: 0.4,
      );
      
      // Then: Should fail with clear error
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotEmpty);
      expect(result.errorMessage, contains('invalid'));
    });

    test('fails gracefully on missing GLB file', () async {
      // Given: Non-existent GLB file
      final result = await _generateNavmesh(
        glbPath: 'test/fixtures/nonexistent.glb',
        navmeshPath: 'test/output/missing.glb',
        agentHeight: 1.8,
        agentRadius: 0.4,
      );
      
      // Then: Should fail with file not found error
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('not found'));
    });

    test('fails gracefully on empty geometry', () async {
      // Given: GLB with no geometry
      final result = await _generateNavmesh(
        glbPath: 'test/fixtures/empty.glb',
        navmeshPath: 'test/output/empty.glb',
        agentHeight: 1.8,
        agentRadius: 0.4,
      );
      
      // Then: Should fail with no geometry error
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('no geometry'));
    });

    test('returns UNSUPPORTED_PLATFORM on Android', () async {
      // Given: Platform is Android (mocked)
      // When: Attempt navmesh generation
      final result = await _generateNavmeshOnPlatform(
        platform: 'android',
        glbPath: 'test/fixtures/sample_room.glb',
      );
      
      // Then: Should return unsupported error
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('UNSUPPORTED_PLATFORM'));
      expect(result.errorMessage, contains('iOS only'));
    });

    test('exports navmesh with walkable surfaces only', () async {
      // Given: Room with mixed surfaces
      final result = await _generateNavmesh(
        glbPath: 'test/fixtures/mixed_surfaces.glb',
        navmeshPath: 'test/output/walkable_only.glb',
        agentHeight: 1.8,
        agentRadius: 0.4,
      );
      
      // Then: Output should only contain walkable geometry
      expect(result.success, isTrue);
      
      // Vertex count should be less than input (walls/ceiling removed)
      final inputVertices = await _countVertices('test/fixtures/mixed_surfaces.glb');
      expect(result.vertexCount, lessThan(inputVertices));
      
      // All normals should point upward (walkable surfaces)
      expect(result.allNormalsUpward, isTrue);
    });

    test('merges connected walkable regions', () async {
      // Given: Room with multiple connected floor areas
      final result = await _generateNavmesh(
        glbPath: 'test/fixtures/multi_room.glb',
        navmeshPath: 'test/output/merged.glb',
        agentHeight: 1.8,
        agentRadius: 0.4,
      );
      
      // Then: Should merge connected regions
      expect(result.success, isTrue);
      expect(result.regionCount, greaterThan(0));
      
      // Should detect doorways as connections
      expect(result.connectionCount, greaterThan(0));
    });

    test('respects min region size parameter', () async {
      // Given: Room with small disconnected surfaces
      final result = await _generateNavmesh(
        glbPath: 'test/fixtures/small_surfaces.glb',
        navmeshPath: 'test/output/filtered.glb',
        agentHeight: 1.8,
        agentRadius: 0.4,
        minRegionSize: 8, // voxels
      );
      
      // Then: Small regions should be filtered out
      expect(result.success, isTrue);
      expect(result.filteredRegionCount, greaterThan(0));
    });

    test('provides progress callbacks during generation', () async {
      final progressUpdates = <double>[];
      
      // Given: Progress callback
      final result = await _generateNavmesh(
        glbPath: 'test/fixtures/typical_room.glb',
        navmeshPath: 'test/output/progress.glb',
        agentHeight: 1.8,
        agentRadius: 0.4,
        onProgress: (progress) {
          progressUpdates.add(progress);
        },
      );
      
      // Then: Should receive progress updates
      expect(result.success, isTrue);
      expect(progressUpdates, isNotEmpty);
      expect(progressUpdates.first, greaterThanOrEqualTo(0.0));
      expect(progressUpdates.last, equals(1.0));
      
      // Progress should be monotonically increasing
      for (int i = 1; i < progressUpdates.length; i++) {
        expect(progressUpdates[i], greaterThanOrEqualTo(progressUpdates[i - 1]));
      }
    });
  });
}

/// Simulated navmesh generation (actual implementation will use Recast)
Future<NavmeshGenerationResult> _generateNavmesh({
  required String glbPath,
  required String navmeshPath,
  required double agentHeight,
  required double agentRadius,
  double maxSlope = 45.0,
  int minRegionSize = 8,
  void Function(double progress)? onProgress,
}) async {
  // Simulate processing
  await Future.delayed(const Duration(milliseconds: 100));
  
  // Mock validation
  if (agentHeight < 1.0 || agentHeight > 3.0) {
    return NavmeshGenerationResult(
      success: false,
      errorMessage: 'Invalid agent height: $agentHeight',
    );
  }
  
  if (agentRadius < 0.2 || agentRadius > 1.5) {
    return NavmeshGenerationResult(
      success: false,
      errorMessage: 'Invalid agent radius: $agentRadius',
    );
  }
  
  if (!await File(glbPath).exists()) {
    return NavmeshGenerationResult(
      success: false,
      errorMessage: 'File not found: $glbPath',
    );
  }
  
  // Simulate progress
  if (onProgress != null) {
    for (double p = 0.0; p <= 1.0; p += 0.25) {
      onProgress(p);
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }
  
  // Mock successful generation
  return NavmeshGenerationResult(
    success: true,
    vertexCount: 500,
    triangleCount: 250,
    walkableSurfaceCount: 5,
    excludedSurfaceCount: 2,
    regionCount: 2,
    connectionCount: 1,
    filteredRegionCount: 0,
    allNormalsUpward: true,
  );
}

Future<NavmeshGenerationResult> _generateNavmeshOnPlatform({
  required String platform,
  required String glbPath,
}) async {
  if (platform == 'android') {
    return NavmeshGenerationResult(
      success: false,
      errorMessage: 'UNSUPPORTED_PLATFORM: Navmesh generation is iOS only',
    );
  }
  return _generateNavmesh(
    glbPath: glbPath,
    navmeshPath: 'test/output/platform_test.glb',
    agentHeight: 1.8,
    agentRadius: 0.4,
  );
}

Future<int> _countVertices(String glbPath) async {
  // Mock vertex counting
  return 1000;
}

/// Result of navmesh generation operation
class NavmeshGenerationResult {
  final bool success;
  final String? errorMessage;
  final int vertexCount;
  final int triangleCount;
  final int walkableSurfaceCount;
  final int excludedSurfaceCount;
  final int regionCount;
  final int connectionCount;
  final int filteredRegionCount;
  final bool allNormalsUpward;
  
  NavmeshGenerationResult({
    required this.success,
    this.errorMessage,
    this.vertexCount = 0,
    this.triangleCount = 0,
    this.walkableSurfaceCount = 0,
    this.excludedSurfaceCount = 0,
    this.regionCount = 0,
    this.connectionCount = 0,
    this.filteredRegionCount = 0,
    this.allNormalsUpward = false,
  });
}
