import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// Integration test for generateNavmesh_v1 platform channel (T155)
///
/// Tests platform channel communication for navmesh generation
/// Validates iOS Recast Navigation integration and Android fallback
///
/// **Platform Channel Contract**:
/// - Channel: 'com.vron.asset_converter/methods'
/// - Method: 'generateNavmesh_v1'
/// - Arguments: {glbPath, navmeshPath, agentHeight, agentRadius, maxSlope}
/// - Returns: {success, vertexCount, triangleCount, errorMessage}
///
/// **Test Coverage**:
/// - iOS: Successful navmesh generation with Recast
/// - iOS: Invalid input handling
/// - iOS: Performance validation (<15s)
/// - Android: UNSUPPORTED_PLATFORM error
/// - Platform channel error handling

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.vron.asset_converter/methods');

  group('T155: generateNavmesh_v1 Platform Channel Integration', () {
    test('generates navmesh successfully on iOS', () async {
      // Skip on Android
      if (Platform.isAndroid) {
        return;
      }

      // Given: Valid GLB file path
      final glbPath = '/tmp/test_room.glb';
      final navmeshPath = '/tmp/test_navmesh.glb';

      // When: Call generateNavmesh_v1 platform method
      final result = await methodChannel.invokeMethod<Map>('generateNavmesh_v1', {
        'glbPath': glbPath,
        'navmeshPath': navmeshPath,
        'agentHeight': 1.8,
        'agentRadius': 0.4,
        'maxSlope': 45.0,
      });

      // Then: Should return success
      expect(result, isNotNull);
      expect(result!['success'], isTrue);
      expect(result['vertexCount'], greaterThan(0));
      expect(result['triangleCount'], greaterThan(0));
      
      // Verify navmesh file was created
      final navmeshFile = File(navmeshPath);
      expect(await navmeshFile.exists(), isTrue);
      
      print('iOS Navmesh generation: ${result['vertexCount']} vertices, ${result['triangleCount']} triangles');
    });

    test('validates agent parameters on iOS', () async {
      if (Platform.isAndroid) return;

      // Test invalid agent height
      try {
        await methodChannel.invokeMethod('generateNavmesh_v1', {
          'glbPath': '/tmp/test.glb',
          'navmeshPath': '/tmp/navmesh.glb',
          'agentHeight': 0.1, // Too short
          'agentRadius': 0.4,
          'maxSlope': 45.0,
        });
        fail('Should throw error for invalid agent height');
      } on PlatformException catch (e) {
        expect(e.code, equals('INVALID_PARAMETERS'));
        expect(e.message, contains('agent height'));
      }

      // Test invalid agent radius
      try {
        await methodChannel.invokeMethod('generateNavmesh_v1', {
          'glbPath': '/tmp/test.glb',
          'navmeshPath': '/tmp/navmesh.glb',
          'agentHeight': 1.8,
          'agentRadius': 5.0, // Too large
          'maxSlope': 45.0,
        });
        fail('Should throw error for invalid agent radius');
      } on PlatformException catch (e) {
        expect(e.code, equals('INVALID_PARAMETERS'));
        expect(e.message, contains('agent radius'));
      }
    });

    test('handles missing GLB file on iOS', () async {
      if (Platform.isAndroid) return;

      // Given: Non-existent GLB file
      try {
        await methodChannel.invokeMethod('generateNavmesh_v1', {
          'glbPath': '/tmp/nonexistent.glb',
          'navmeshPath': '/tmp/navmesh.glb',
          'agentHeight': 1.8,
          'agentRadius': 0.4,
          'maxSlope': 45.0,
        });
        fail('Should throw error for missing file');
      } on PlatformException catch (e) {
        expect(e.code, equals('FILE_NOT_FOUND'));
        expect(e.message, contains('not found'));
      }
    });

    test('handles invalid GLB format on iOS', () async {
      if (Platform.isAndroid) return;

      // Given: Invalid GLB file
      final invalidFile = File('/tmp/invalid.glb');
      await invalidFile.writeAsString('not a valid GLB file');

      try {
        await methodChannel.invokeMethod('generateNavmesh_v1', {
          'glbPath': invalidFile.path,
          'navmeshPath': '/tmp/navmesh.glb',
          'agentHeight': 1.8,
          'agentRadius': 0.4,
          'maxSlope': 45.0,
        });
        fail('Should throw error for invalid GLB');
      } on PlatformException catch (e) {
        expect(e.code, equals('INVALID_GLB_FORMAT'));
      } finally {
        await invalidFile.delete();
      }
    });

    test('completes navmesh generation within performance target (<15s) on iOS', () async {
      if (Platform.isAndroid) return;

      // Given: Typical room GLB (~2000 vertices)
      final glbPath = '/tmp/typical_room.glb';
      final navmeshPath = '/tmp/typical_navmesh.glb';

      // When: Measure generation time
      final stopwatch = Stopwatch()..start();
      
      final result = await methodChannel.invokeMethod<Map>('generateNavmesh_v1', {
        'glbPath': glbPath,
        'navmeshPath': navmeshPath,
        'agentHeight': 1.8,
        'agentRadius': 0.4,
        'maxSlope': 45.0,
      });
      
      stopwatch.stop();

      // Then: Should complete in <15 seconds (FR-013 requirement)
      expect(result!['success'], isTrue);
      expect(stopwatch.elapsed.inSeconds, lessThan(15));
      
      print('Navmesh generation time: ${stopwatch.elapsed.inSeconds}s');
    });

    test('returns UNSUPPORTED_PLATFORM error on Android', () async {
      // Only run on Android
      if (Platform.isIOS) {
        return;
      }

      // When: Call generateNavmesh_v1 on Android
      try {
        await methodChannel.invokeMethod('generateNavmesh_v1', {
          'glbPath': '/tmp/test.glb',
          'navmeshPath': '/tmp/navmesh.glb',
          'agentHeight': 1.8,
          'agentRadius': 0.4,
          'maxSlope': 45.0,
        });
        fail('Should throw UNSUPPORTED_PLATFORM error on Android');
      } on PlatformException catch (e) {
        // Then: Should return unsupported platform error
        expect(e.code, equals('UNSUPPORTED_PLATFORM'));
        expect(e.message, contains('iOS only'));
      }
      
      print('Android correctly returns UNSUPPORTED_PLATFORM');
    });

    test('handles empty geometry GLB on iOS', () async {
      if (Platform.isAndroid) return;

      // Given: GLB with no geometry
      final emptyGlbPath = '/tmp/empty.glb';
      
      try {
        await methodChannel.invokeMethod('generateNavmesh_v1', {
          'glbPath': emptyGlbPath,
          'navmeshPath': '/tmp/navmesh.glb',
          'agentHeight': 1.8,
          'agentRadius': 0.4,
          'maxSlope': 45.0,
        });
        fail('Should throw error for empty geometry');
      } on PlatformException catch (e) {
        expect(e.code, equals('NO_GEOMETRY'));
        expect(e.message, contains('no walkable geometry'));
      }
    });

    test('supports custom agent parameters on iOS', () async {
      if (Platform.isAndroid) return;

      // Given: Custom agent parameters (wheelchair dimensions)
      final glbPath = '/tmp/test_room.glb';
      final navmeshPath = '/tmp/wheelchair_navmesh.glb';

      // When: Generate with custom parameters
      final result = await methodChannel.invokeMethod<Map>('generateNavmesh_v1', {
        'glbPath': glbPath,
        'navmeshPath': navmeshPath,
        'agentHeight': 1.2, // Seated height
        'agentRadius': 0.8, // Wheelchair clearance
        'maxSlope': 30.0, // ADA compliant max slope
      });

      // Then: Should generate with custom parameters
      expect(result!['success'], isTrue);
      expect(result['vertexCount'], greaterThan(0));
    });

    test('handles multiple concurrent navmesh generation requests on iOS', () async {
      if (Platform.isAndroid) return;

      // When: Generate multiple navmeshes concurrently
      final futures = List.generate(
        3,
        (i) => methodChannel.invokeMethod<Map>('generateNavmesh_v1', {
          'glbPath': '/tmp/room_$i.glb',
          'navmeshPath': '/tmp/navmesh_$i.glb',
          'agentHeight': 1.8,
          'agentRadius': 0.4,
          'maxSlope': 45.0,
        }),
      );

      // Then: All should complete successfully
      final results = await Future.wait(futures);
      for (final result in results) {
        expect(result!['success'], isTrue);
      }
    });

    test('provides progress callbacks during generation on iOS', () async {
      if (Platform.isAndroid) return;

      final progressUpdates = <double>[];
      
      // Setup event channel for progress
      const eventChannel = EventChannel('com.vron.asset_converter/navmesh_progress');
      final subscription = eventChannel.receiveBroadcastStream().listen((progress) {
        progressUpdates.add(progress as double);
      });

      try {
        // Start generation
        await methodChannel.invokeMethod('generateNavmesh_v1', {
          'glbPath': '/tmp/test_room.glb',
          'navmeshPath': '/tmp/navmesh.glb',
          'agentHeight': 1.8,
          'agentRadius': 0.4,
          'maxSlope': 45.0,
        });

        // Verify progress updates
        expect(progressUpdates, isNotEmpty);
        expect(progressUpdates.first, greaterThanOrEqualTo(0.0));
        expect(progressUpdates.last, equals(1.0));
      } finally {
        await subscription.cancel();
      }
    });

    test('exports navmesh with correct vertex count on iOS', () async {
      if (Platform.isAndroid) return;

      // Given: Known input geometry
      final glbPath = '/tmp/known_room.glb'; // Known to have ~1000 vertices
      final navmeshPath = '/tmp/known_navmesh.glb';

      // When: Generate navmesh
      final result = await methodChannel.invokeMethod<Map>('generateNavmesh_v1', {
        'glbPath': glbPath,
        'navmeshPath': navmeshPath,
        'agentHeight': 1.8,
        'agentRadius': 0.4,
        'maxSlope': 45.0,
      });

      // Then: Verify vertex count is reasonable
      expect(result!['vertexCount'], greaterThan(100)); // At least some vertices
      expect(result['vertexCount'], lessThan(10000)); // Not excessive
      
      // Verify triangle count (should be roughly vertices / 3)
      final vertexToTriangleRatio = result['vertexCount'] / result['triangleCount'];
      expect(vertexToTriangleRatio, closeTo(3.0, 1.0));
    });

    test('cancels navmesh generation on iOS', () async {
      if (Platform.isAndroid) return;

      // Start generation
      final generationFuture = methodChannel.invokeMethod('generateNavmesh_v1', {
        'glbPath': '/tmp/large_room.glb',
        'navmeshPath': '/tmp/navmesh.glb',
        'agentHeight': 1.8,
        'agentRadius': 0.4,
        'maxSlope': 45.0,
      });

      // Cancel after 500ms
      await Future.delayed(const Duration(milliseconds: 500));
      await methodChannel.invokeMethod('cancelNavmeshGeneration');

      // Verify cancellation
      try {
        await generationFuture;
        fail('Should throw cancelled error');
      } on PlatformException catch (e) {
        expect(e.code, equals('CANCELLED'));
      }
    });
  });
}
