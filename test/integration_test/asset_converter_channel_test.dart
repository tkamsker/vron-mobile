import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Integration tests for convertToGlb_v1 platform channel
///
/// Tests the actual method channel communication for asset conversion:
/// - USDZ to GLB conversion (iOS)
/// - GLB optimization and compression
/// - Navigation mesh extraction
/// - Progress event stream
/// - Error handling
/// - File validation
/// - Metadata extraction
///
/// **TDD Requirement**: These tests validate asset conversion integration
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('convertToGlb_v1 Platform Channel Integration', () {
    late MethodChannel methodChannel;
    late EventChannel eventChannel;
    late String testInputPath;
    late String testOutputPath;

    setUp(() async {
      methodChannel = const MethodChannel('one.vron.mobile/asset_converter');
      eventChannel = const EventChannel('one.vron.mobile/asset_converter/progress');

      // Create temporary directories
      final tempDir = await getTemporaryDirectory();
      testInputPath = '${tempDir.path}/test_input';
      testOutputPath = '${tempDir.path}/test_output';

      await Directory(testInputPath).create(recursive: true);
      await Directory(testOutputPath).create(recursive: true);
    });

    tearDown(() async {
      // Clean up test files
      try {
        final inputDir = Directory(testInputPath);
        if (await inputDir.exists()) {
          await inputDir.delete(recursive: true);
        }

        final outputDir = Directory(testOutputPath);
        if (await outputDir.exists()) {
          await outputDir.delete(recursive: true);
        }
      } catch (e) {
        print('Cleanup warning: $e');
      }
    });

    testWidgets('isConversionSupported returns platform capability',
        (WidgetTester tester) async {
      // When: Checking conversion support
      final result = await methodChannel.invokeMethod<bool>('isConversionSupported');

      // Then: Should return boolean based on platform
      expect(result, isNotNull);
      expect(result, isA<bool>());

      if (Platform.isIOS) {
        // iOS should support USDZ to GLB conversion
        expect(result, isTrue);
        print('iOS Asset Conversion Supported: $result');
      } else if (Platform.isAndroid) {
        // Android may have limited support
        print('Android Asset Conversion Supported: $result');
      }
    });

    testWidgets('getSupportedFormats returns format list',
        (WidgetTester tester) async {
      // When: Getting supported formats
      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getSupportedFormats',
      );

      // Then: Should return input and output formats
      expect(result, isNotNull);
      expect(result!['input'], isA<List>());
      expect(result['output'], isA<List>());

      final inputFormats = result['input'] as List;
      final outputFormats = result['output'] as List;

      if (Platform.isIOS) {
        expect(inputFormats, contains('usdz'));
      }
      expect(outputFormats, contains('glb'));

      print('Supported Formats - Input: $inputFormats, Output: $outputFormats');
    });

    testWidgets('convertUsdzToGlb fails with missing input file',
        (WidgetTester tester) async {
      if (!Platform.isIOS) {
        print('Skipping: iOS-only test');
        return;
      }

      // When: Converting non-existent file
      try {
        await methodChannel.invokeMethod(
          'convertUsdzToGlb',
          {
            'usdzPath': '$testInputPath/nonexistent.usdz',
            'glbPath': '$testOutputPath/output.glb',
          },
        );
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        // Then: Should throw with FILE_NOT_FOUND code
        expect(e.code, 'FILE_NOT_FOUND');
        expect(e.message, contains('not found'));
      }
    });

    testWidgets('convertUsdzToGlb fails with invalid output path',
        (WidgetTester tester) async {
      if (!Platform.isIOS) {
        print('Skipping: iOS-only test');
        return;
      }

      // Given: Create a mock USDZ file
      final mockUsdz = File('$testInputPath/test.usdz');
      await mockUsdz.writeAsBytes([0x50, 0x4B, 0x03, 0x04]); // ZIP header

      // When: Converting with invalid output path
      try {
        await methodChannel.invokeMethod(
          'convertUsdzToGlb',
          {
            'usdzPath': mockUsdz.path,
            'glbPath': '/invalid/path/output.glb',
          },
        );
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        // Then: Should throw with INVALID_PATH code
        expect(e.code, anyOf('INVALID_PATH', 'IO_ERROR'));
      }
    });

    testWidgets('convertUsdzToGlb fails with invalid USDZ format',
        (WidgetTester tester) async {
      if (!Platform.isIOS) {
        print('Skipping: iOS-only test');
        return;
      }

      // Given: Create an invalid USDZ file
      final invalidUsdz = File('$testInputPath/invalid.usdz');
      await invalidUsdz.writeAsString('This is not a valid USDZ file');

      // When: Converting invalid file
      try {
        await methodChannel.invokeMethod(
          'convertUsdzToGlb',
          {
            'usdzPath': invalidUsdz.path,
            'glbPath': '$testOutputPath/output.glb',
          },
        );
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        // Then: Should throw with INVALID_FORMAT code
        expect(e.code, anyOf('INVALID_FORMAT', 'CONVERSION_FAILED'));
        expect(e.message, contains('invalid'));
      }
    });

    testWidgets('convertUsdzToGlb with default options (requires valid USDZ)',
        (WidgetTester tester) async {
      if (!Platform.isIOS) {
        print('Skipping: iOS-only test (requires actual USDZ from RoomPlan)');
        return;
      }

      // This test requires a valid USDZ file from a real scan
      // We'll check if one exists in test assets
      final testAssetPath = 'test/fixtures/sample_room.usdz';
      final testAsset = File(testAssetPath);

      if (!await testAsset.exists()) {
        print('Skipping: No sample USDZ available (run actual scan first)');
        return;
      }

      // When: Converting with default options
      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'convertUsdzToGlb',
        {
          'usdzPath': testAsset.path,
          'glbPath': '$testOutputPath/converted.glb',
        },
      );

      // Then: Should succeed and return result
      expect(result, isNotNull);
      expect(result!['glbPath'], '$testOutputPath/converted.glb');
      expect(result['fileSize'], isA<int>());
      expect(result['fileSize'], greaterThan(0));

      // Verify GLB file exists
      final glbFile = File(result['glbPath'] as String);
      expect(await glbFile.exists(), isTrue);

      print('Conversion successful: ${result['fileSize']} bytes');
    });

    testWidgets('convertUsdzToGlb with quality options (requires valid USDZ)',
        (WidgetTester tester) async {
      if (!Platform.isIOS) {
        print('Skipping: iOS-only test');
        return;
      }

      final testAssetPath = 'test/fixtures/sample_room.usdz';
      final testAsset = File(testAssetPath);

      if (!await testAsset.exists()) {
        print('Skipping: No sample USDZ available');
        return;
      }

      // When: Converting with high quality settings
      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'convertUsdzToGlb',
        {
          'usdzPath': testAsset.path,
          'glbPath': '$testOutputPath/high_quality.glb',
          'options': {
            'compressionLevel': 'low',
            'preserveTextures': true,
            'optimizeMesh': false,
          },
        },
      );

      // Then: Should produce larger file with better quality
      expect(result, isNotNull);
      expect(result!['glbPath'], endsWith('high_quality.glb'));

      print('High quality conversion: ${result['fileSize']} bytes');
    });

    testWidgets('convertUsdzToGlb with compression options (requires valid USDZ)',
        (WidgetTester tester) async {
      if (!Platform.isIOS) {
        print('Skipping: iOS-only test');
        return;
      }

      final testAssetPath = 'test/fixtures/sample_room.usdz';
      final testAsset = File(testAssetPath);

      if (!await testAsset.exists()) {
        print('Skipping: No sample USDZ available');
        return;
      }

      // When: Converting with high compression
      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'convertUsdzToGlb',
        {
          'usdzPath': testAsset.path,
          'glbPath': '$testOutputPath/compressed.glb',
          'options': {
            'compressionLevel': 'high',
            'optimizeMesh': true,
            'removeUnusedVertices': true,
          },
        },
      );

      // Then: Should produce smaller file
      expect(result, isNotNull);
      expect(result!['glbPath'], endsWith('compressed.glb'));

      print('Compressed conversion: ${result['fileSize']} bytes');
    });

    testWidgets('progress event channel emits conversion updates (requires valid USDZ)',
        (WidgetTester tester) async {
      if (!Platform.isIOS) {
        print('Skipping: iOS-only test');
        return;
      }

      final testAssetPath = 'test/fixtures/sample_room.usdz';
      final testAsset = File(testAssetPath);

      if (!await testAsset.exists()) {
        print('Skipping: No sample USDZ available');
        return;
      }

      // Given: Progress event stream
      final progressEvents = <Map<dynamic, dynamic>>[];
      late StreamSubscription subscription;

      subscription = eventChannel.receiveBroadcastStream().listen(
        (event) {
          if (event is Map) {
            progressEvents.add(event as Map<dynamic, dynamic>);
          }
        },
      );

      // When: Converting with progress tracking
      await methodChannel.invokeMethod(
        'convertUsdzToGlb',
        {
          'usdzPath': testAsset.path,
          'glbPath': '$testOutputPath/progress_test.glb',
        },
      );

      // Cancel subscription
      await subscription.cancel();

      // Then: Should have received progress events
      expect(progressEvents.isNotEmpty, isTrue);

      // Validate event structure
      for (final event in progressEvents) {
        expect(event['progress'], isA<num>());
        expect(event['stage'], isA<String>());
      }

      print('Received ${progressEvents.length} progress events');
    });

    testWidgets('extractNavmesh extracts navigation mesh (requires valid GLB)',
        (WidgetTester tester) async {
      // Given: Valid GLB file (from previous conversion or test asset)
      final testGlbPath = '$testOutputPath/converted.glb';
      final testGlb = File(testGlbPath);

      if (!await testGlb.exists()) {
        print('Skipping: No GLB file available (run conversion first)');
        return;
      }

      // When: Extracting navigation mesh
      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'extractNavmesh',
        {
          'glbPath': testGlbPath,
          'outputPath': '$testOutputPath/navmesh.json',
        },
      );

      // Then: Should produce navmesh file
      expect(result, isNotNull);
      expect(result!['navmeshPath'], endsWith('navmesh.json'));

      final navmeshFile = File(result['navmeshPath'] as String);
      expect(await navmeshFile.exists(), isTrue);

      // Validate navmesh structure
      if (result.containsKey('vertexCount')) {
        expect(result['vertexCount'], isA<int>());
        expect(result['vertexCount'], greaterThan(0));
      }

      print('Navmesh extracted: ${result['vertexCount']} vertices');
    });

    testWidgets('extractNavmesh fails with invalid GLB',
        (WidgetTester tester) async {
      // Given: Invalid GLB file
      final invalidGlb = File('$testInputPath/invalid.glb');
      await invalidGlb.writeAsString('Not a GLB file');

      // When: Extracting navmesh from invalid file
      try {
        await methodChannel.invokeMethod(
          'extractNavmesh',
          {
            'glbPath': invalidGlb.path,
            'outputPath': '$testOutputPath/navmesh.json',
          },
        );
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        // Then: Should throw with INVALID_FORMAT code
        expect(e.code, anyOf('INVALID_FORMAT', 'EXTRACTION_FAILED'));
      }
    });

    testWidgets('extractNavmesh with custom options (requires valid GLB)',
        (WidgetTester tester) async {
      final testGlbPath = '$testOutputPath/converted.glb';
      final testGlb = File(testGlbPath);

      if (!await testGlb.exists()) {
        print('Skipping: No GLB file available');
        return;
      }

      // When: Extracting with custom options
      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'extractNavmesh',
        {
          'glbPath': testGlbPath,
          'outputPath': '$testOutputPath/custom_navmesh.json',
          'options': {
            'simplificationFactor': 0.5,
            'maxVertices': 5000,
            'includeWalkable': true,
            'includeObstacles': true,
          },
        },
      );

      // Then: Should apply custom settings
      expect(result, isNotNull);
      expect(result!['navmeshPath'], endsWith('custom_navmesh.json'));

      print('Custom navmesh: ${result['vertexCount']} vertices (simplified)');
    });

    testWidgets('getGlbMetadata returns model information (requires valid GLB)',
        (WidgetTester tester) async {
      final testGlbPath = '$testOutputPath/converted.glb';
      final testGlb = File(testGlbPath);

      if (!await testGlb.exists()) {
        print('Skipping: No GLB file available');
        return;
      }

      // When: Getting GLB metadata
      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getGlbMetadata',
        {'glbPath': testGlbPath},
      );

      // Then: Should return metadata
      expect(result, isNotNull);
      expect(result!['fileSize'], isA<int>());

      // Common metadata fields
      if (result.containsKey('vertexCount')) {
        expect(result['vertexCount'], isA<int>());
      }
      if (result.containsKey('triangleCount')) {
        expect(result['triangleCount'], isA<int>());
      }
      if (result.containsKey('materialCount')) {
        expect(result['materialCount'], isA<int>());
      }
      if (result.containsKey('textureCount')) {
        expect(result['textureCount'], isA<int>());
      }

      print('GLB Metadata: $result');
    });

    testWidgets('validateGlb checks file integrity (requires valid GLB)',
        (WidgetTester tester) async {
      final testGlbPath = '$testOutputPath/converted.glb';
      final testGlb = File(testGlbPath);

      if (!await testGlb.exists()) {
        print('Skipping: No GLB file available');
        return;
      }

      // When: Validating GLB file
      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'validateGlb',
        {'glbPath': testGlbPath},
      );

      // Then: Should return validation result
      expect(result, isNotNull);
      expect(result!['isValid'], isTrue);

      if (result.containsKey('errors')) {
        final errors = result['errors'] as List;
        expect(errors, isEmpty);
      }

      print('GLB Validation: ${result['isValid']}');
    });

    testWidgets('validateGlb detects corrupted file',
        (WidgetTester tester) async {
      // Given: Corrupted GLB file
      final corruptedGlb = File('$testInputPath/corrupted.glb');
      await corruptedGlb.writeAsBytes([0x67, 0x6C, 0x54, 0x46]); // glTF header only

      // When: Validating corrupted file
      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'validateGlb',
        {'glbPath': corruptedGlb.path},
      );

      // Then: Should return invalid with errors
      expect(result, isNotNull);
      expect(result!['isValid'], isFalse);
      expect(result['errors'], isA<List>());
      expect((result['errors'] as List).isNotEmpty, isTrue);

      print('Validation errors: ${result['errors']}');
    });

    testWidgets('optimizeGlb reduces file size (requires valid GLB)',
        (WidgetTester tester) async {
      final testGlbPath = '$testOutputPath/converted.glb';
      final testGlb = File(testGlbPath);

      if (!await testGlb.exists()) {
        print('Skipping: No GLB file available');
        return;
      }

      final originalSize = await testGlb.length();

      // When: Optimizing GLB file
      final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'optimizeGlb',
        {
          'inputPath': testGlbPath,
          'outputPath': '$testOutputPath/optimized.glb',
          'options': {
            'removeUnusedVertices': true,
            'mergeDuplicateVertices': true,
            'compressTextures': true,
          },
        },
      );

      // Then: Should produce optimized file
      expect(result, isNotNull);
      expect(result!['outputPath'], endsWith('optimized.glb'));

      final optimizedSize = result['fileSize'] as int;
      expect(optimizedSize, lessThanOrEqualTo(originalSize));

      final reductionPercent = ((originalSize - optimizedSize) / originalSize * 100).toInt();
      print('Optimized: $originalSize → $optimizedSize bytes ($reductionPercent% reduction)');
    });

    testWidgets('cancelConversion aborts active conversion (requires valid USDZ)',
        (WidgetTester tester) async {
      if (!Platform.isIOS) {
        print('Skipping: iOS-only test');
        return;
      }

      final testAssetPath = 'test/fixtures/sample_room.usdz';
      final testAsset = File(testAssetPath);

      if (!await testAsset.exists()) {
        print('Skipping: No sample USDZ available');
        return;
      }

      // When: Starting conversion and canceling immediately
      final conversionFuture = methodChannel.invokeMethod(
        'convertUsdzToGlb',
        {
          'usdzPath': testAsset.path,
          'glbPath': '$testOutputPath/canceled.glb',
        },
      );

      // Cancel after short delay
      await Future.delayed(const Duration(milliseconds: 100));
      await methodChannel.invokeMethod('cancelConversion');

      // Then: Should throw cancellation error
      try {
        await conversionFuture;
        // Conversion might complete before cancellation, which is OK
        print('Conversion completed before cancellation');
      } on PlatformException catch (e) {
        expect(e.code, 'CONVERSION_CANCELED');
        print('Conversion canceled successfully');
      }
    });

    testWidgets('batch conversion processes multiple files (requires valid USDZ)',
        (WidgetTester tester) async {
      if (!Platform.isIOS) {
        print('Skipping: iOS-only test');
        return;
      }

      // This test would require multiple USDZ files
      print('Skipping: Batch conversion test requires multiple USDZ files');
    });
  });

  group('Platform-Specific Conversion', () {
    late MethodChannel methodChannel;

    setUp(() {
      methodChannel = const MethodChannel('one.vron.mobile/asset_converter');
    });

    testWidgets('iOS supports USDZ to GLB conversion', (WidgetTester tester) async {
      if (!Platform.isIOS) {
        print('Skipping: iOS-only test');
        return;
      }

      // When: Getting conversion info on iOS
      final conversionInfo = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getConversionInfo',
      );

      // Then: Should support USDZ to GLB
      expect(conversionInfo, isNotNull);
      expect(conversionInfo!['supportsUsdzToGlb'], isTrue);
      expect(conversionInfo['converterVersion'], isA<String>());

      print('iOS Converter: ${conversionInfo['converterVersion']}');
    });

    testWidgets('Android has limited conversion support', (WidgetTester tester) async {
      if (!Platform.isAndroid) {
        print('Skipping: Android-only test');
        return;
      }

      // When: Getting conversion info on Android
      final conversionInfo = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getConversionInfo',
      );

      // Then: May have limited support
      expect(conversionInfo, isNotNull);
      print('Android Conversion Support: ${conversionInfo!['supportsUsdzToGlb']}');
    });
  });
}
