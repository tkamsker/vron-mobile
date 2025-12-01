import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asset_converter/src/asset_converter_channel.dart';

/// Test suite for USDZ to GLB conversion logic
///
/// Tests the AssetConverterChannel's ability to:
/// - Check conversion capabilities
/// - Convert USDZ files to GLB format
/// - Extract navigation meshes
/// - Handle conversion options
/// - Report progress
/// - Handle errors (file not found, too large, conversion failures)
///
/// **TDD Requirement**: These tests define the contract and must pass first
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('USDZ to GLB Conversion', () {
    late AssetConverterChannel channel;
    late List<MethodCall> methodCallLog;

    setUp(() {
      channel = AssetConverterChannel();
      methodCallLog = [];

      // Reset method call handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/asset_converter'),
        null,
      );

      // Reset event channel handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const EventChannel('one.vron.mobile/asset_converter_events'),
        null,
      );
    });

    tearDown(() {
      // Clean up handlers
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('one.vron.mobile/asset_converter'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const EventChannel('one.vron.mobile/asset_converter_events'),
        null,
      );
    });

    // =========================================================================
    // Test Group: Conversion Capabilities
    // =========================================================================

    group('Conversion Capabilities', () {
      test('isConversionSupported returns true on iOS with Model I/O', () async {
        // Given: iOS device with Model I/O framework
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'isConversionSupported') {
              return true; // Model I/O available
            }
            return null;
          },
        );

        // When: Checking conversion support
        final result = await channel.isConversionSupported();

        // Then: Should return true
        expect(result, isTrue);
        expect(methodCallLog.length, 1);
        expect(methodCallLog[0].method, 'isConversionSupported');
      });

      test('isConversionSupported returns false on unsupported devices',
          () async {
        // Given: Device without conversion support
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'isConversionSupported') {
              return false; // Not supported
            }
            return null;
          },
        );

        // When: Checking conversion support
        final result = await channel.isConversionSupported();

        // Then: Should return false
        expect(result, isFalse);
      });

      test('getCapabilities returns device capabilities', () async {
        // Given: Device with conversion capabilities
        final expectedCapabilities = {
          'supportsUSDZ': true,
          'supportsGLB': true,
          'supportsNavmesh': true,
          'maxFileSize': 52428800, // 50MB
          'supportedFormats': ['usdz', 'usd', 'usda', 'glb', 'gltf'],
        };

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'getCapabilities') {
              return expectedCapabilities;
            }
            return null;
          },
        );

        // When: Getting capabilities
        final result = await channel.getCapabilities();

        // Then: Should return capabilities map
        expect(result['supportsUSDZ'], isTrue);
        expect(result['supportsGLB'], isTrue);
        expect(result['supportsNavmesh'], isTrue);
        expect(result['maxFileSize'], 52428800);
        expect(result['supportedFormats'], isA<List>());
      });

      test('getCapabilities handles null response', () async {
        // Given: Platform returns null
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'getCapabilities') {
              return null; // Null response
            }
            return null;
          },
        );

        // When: Getting capabilities
        final result = await channel.getCapabilities();

        // Then: Should return empty map
        expect(result, isEmpty);
      });
    });

    // =========================================================================
    // Test Group: USDZ to GLB Conversion
    // =========================================================================

    group('USDZ to GLB Conversion', () {
      test('convertUsdzToGlb succeeds with valid paths', () async {
        // Given: Valid USDZ file and output path
        const usdzPath = '/tmp/scans/room-123.usdz';
        const glbPath = '/tmp/converted/room-123.glb';

        final expectedResult = {
          'glbPath': glbPath,
          'fileSize': 1024000,
          'durationMs': 2500,
          'metadata': {
            'textureCount': 5,
            'materialCount': 3,
            'meshCount': 12,
          },
        };

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'convertUsdzToGlb') {
              final args = methodCall.arguments as Map;
              expect(args['usdzPath'], usdzPath);
              expect(args['glbPath'], glbPath);

              return expectedResult;
            }
            return null;
          },
        );

        // When: Converting USDZ to GLB
        final result = await channel.convertUsdzToGlb(
          usdzPath: usdzPath,
          glbPath: glbPath,
        );

        // Then: Should return conversion result
        expect(result.glbPath, glbPath);
        expect(result.fileSize, 1024000);
        expect(result.durationMs, 2500);
        expect(result.metadata['textureCount'], 5);
        expect(methodCallLog.length, 1);
      });

      test('convertUsdzToGlb includes conversion options', () async {
        // Given: Conversion with custom options
        const usdzPath = '/tmp/scans/room-123.usdz';
        const glbPath = '/tmp/converted/room-123.glb';

        const options = ConversionOptions(
          optimizeSize: true,
          includeMaterials: true,
          maxTextureSize: 2048,
          compressionLevel: 7,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'convertUsdzToGlb') {
              final args = methodCall.arguments as Map;
              final optionsMap = args['options'] as Map;

              expect(optionsMap['optimizeSize'], isTrue);
              expect(optionsMap['includeMaterials'], isTrue);
              expect(optionsMap['maxTextureSize'], 2048);
              expect(optionsMap['compressionLevel'], 7);

              return {
                'glbPath': glbPath,
                'fileSize': 512000, // Smaller due to optimization
                'durationMs': 3000,
                'metadata': {},
              };
            }
            return null;
          },
        );

        // When: Converting with options
        final result = await channel.convertUsdzToGlb(
          usdzPath: usdzPath,
          glbPath: glbPath,
          options: options,
        );

        // Then: Should apply options and return optimized result
        expect(result.glbPath, glbPath);
        expect(result.fileSize, lessThan(1024000)); // Optimized size
      });

      test('convertUsdzToGlb throws FileNotFoundException when file missing',
          () async {
        // Given: Non-existent USDZ file
        const usdzPath = '/tmp/scans/missing.usdz';
        const glbPath = '/tmp/converted/missing.glb';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'convertUsdzToGlb') {
              throw PlatformException(
                code: 'FILE_NOT_FOUND',
                message: 'Input file does not exist',
              );
            }
            return null;
          },
        );

        // When/Then: Should throw FileNotFoundException
        expect(
          () => channel.convertUsdzToGlb(
            usdzPath: usdzPath,
            glbPath: glbPath,
          ),
          throwsA(
            isA<FileNotFoundException>()
                .having((e) => e.filePath, 'filePath', usdzPath),
          ),
        );
      });

      test('convertUsdzToGlb throws FileTooLargeException for large files',
          () async {
        // Given: USDZ file larger than 50MB
        const usdzPath = '/tmp/scans/huge-room.usdz';
        const glbPath = '/tmp/converted/huge-room.glb';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'convertUsdzToGlb') {
              throw PlatformException(
                code: 'FILE_TOO_LARGE',
                message: 'File size exceeds 50MB limit',
              );
            }
            return null;
          },
        );

        // When/Then: Should throw FileTooLargeException
        expect(
          () => channel.convertUsdzToGlb(
            usdzPath: usdzPath,
            glbPath: glbPath,
          ),
          throwsA(isA<FileTooLargeException>()),
        );
      });

      test('convertUsdzToGlb throws ConversionFailedException on error',
          () async {
        // Given: Corrupted USDZ file
        const usdzPath = '/tmp/scans/corrupted.usdz';
        const glbPath = '/tmp/converted/corrupted.glb';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'convertUsdzToGlb') {
              throw PlatformException(
                code: 'CONVERSION_FAILED',
                message: 'Failed to parse USDZ file',
              );
            }
            return null;
          },
        );

        // When/Then: Should throw ConversionFailedException
        expect(
          () => channel.convertUsdzToGlb(
            usdzPath: usdzPath,
            glbPath: glbPath,
          ),
          throwsA(isA<ConversionFailedException>()),
        );
      });

      test('convertUsdzToGlb throws exception on null result', () async {
        // Given: Platform returns null
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'convertUsdzToGlb') {
              return null; // Null result
            }
            return null;
          },
        );

        // When/Then: Should throw AssetConverterException
        expect(
          () => channel.convertUsdzToGlb(
            usdzPath: '/tmp/test.usdz',
            glbPath: '/tmp/test.glb',
          ),
          throwsA(
            isA<AssetConverterException>().having(
              (e) => e.message,
              'message',
              contains('null result'),
            ),
          ),
        );
      });
    });

    // =========================================================================
    // Test Group: Navmesh Extraction
    // =========================================================================

    group('Navmesh Extraction', () {
      test('extractNavmesh succeeds with valid paths', () async {
        // Given: Valid USDZ file
        const usdzPath = '/tmp/scans/room-123.usdz';
        const navmeshPath = '/tmp/navmeshes/room-123-navmesh.glb';

        final expectedResult = {
          'navmeshPath': navmeshPath,
          'fileSize': 102400,
          'triangleCount': 850,
          'surfaceArea': 42.5,
        };

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'extractNavmesh') {
              final args = methodCall.arguments as Map;
              expect(args['usdzPath'], usdzPath);
              expect(args['navmeshPath'], navmeshPath);

              return expectedResult;
            }
            return null;
          },
        );

        // When: Extracting navmesh
        final result = await channel.extractNavmesh(
          usdzPath: usdzPath,
          navmeshPath: navmeshPath,
        );

        // Then: Should return navmesh result
        expect(result.navmeshPath, navmeshPath);
        expect(result.fileSize, 102400);
        expect(result.triangleCount, 850);
        expect(result.surfaceArea, 42.5);
      });

      test('extractNavmesh includes navmesh options', () async {
        // Given: Navmesh extraction with custom options
        const usdzPath = '/tmp/scans/room-123.usdz';
        const navmeshPath = '/tmp/navmeshes/room-123-navmesh.glb';

        const options = NavmeshOptions(
          simplificationLevel: 0.7,
          minSurfaceArea: 0.5,
          maxSlopeAngle: 30.0,
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'extractNavmesh') {
              final args = methodCall.arguments as Map;
              final optionsMap = args['options'] as Map;

              expect(optionsMap['simplificationLevel'], 0.7);
              expect(optionsMap['minSurfaceArea'], 0.5);
              expect(optionsMap['maxSlopeAngle'], 30.0);

              return {
                'navmeshPath': navmeshPath,
                'fileSize': 81920, // Smaller due to simplification
                'triangleCount': 680, // Fewer triangles
                'surfaceArea': 42.5,
              };
            }
            return null;
          },
        );

        // When: Extracting with options
        final result = await channel.extractNavmesh(
          usdzPath: usdzPath,
          navmeshPath: navmeshPath,
          options: options,
        );

        // Then: Should apply options and return simplified navmesh
        expect(result.triangleCount, lessThan(850)); // Simplified
      });

      test('extractNavmesh throws NavmeshExtractionFailedException on error',
          () async {
        // Given: USDZ with no valid surfaces
        const usdzPath = '/tmp/scans/empty-room.usdz';
        const navmeshPath = '/tmp/navmeshes/empty-room-navmesh.glb';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'extractNavmesh') {
              throw PlatformException(
                code: 'NAVMESH_EXTRACTION_FAILED',
                message: 'No walkable surfaces found',
              );
            }
            return null;
          },
        );

        // When/Then: Should throw NavmeshExtractionFailedException
        expect(
          () => channel.extractNavmesh(
            usdzPath: usdzPath,
            navmeshPath: navmeshPath,
          ),
          throwsA(isA<NavmeshExtractionFailedException>()),
        );
      });
    });

    // =========================================================================
    // Test Group: Conversion Progress
    // =========================================================================

    group('Conversion Progress', () {
      test('ConversionProgress.fromMap parses all stages correctly', () {
        // Given: Progress updates for different stages
        final loadingProgress = ConversionProgress.fromMap({
          'percentage': 0.1,
          'stage': 'loading',
          'message': 'Loading USDZ file...',
        });

        final parsingProgress = ConversionProgress.fromMap({
          'percentage': 0.3,
          'stage': 'parsing',
          'message': 'Parsing scene graph...',
        });

        final convertingProgress = ConversionProgress.fromMap({
          'percentage': 0.6,
          'stage': 'converting',
          'message': 'Converting to GLB format...',
        });

        final savingProgress = ConversionProgress.fromMap({
          'percentage': 0.9,
          'stage': 'saving',
          'message': 'Saving GLB file...',
        });

        final completeProgress = ConversionProgress.fromMap({
          'percentage': 1.0,
          'stage': 'complete',
          'message': 'Conversion complete!',
        });

        // Then: Should parse all stages correctly
        expect(loadingProgress.stage, ConversionStage.loading);
        expect(parsingProgress.stage, ConversionStage.parsing);
        expect(convertingProgress.stage, ConversionStage.converting);
        expect(savingProgress.stage, ConversionStage.saving);
        expect(completeProgress.stage, ConversionStage.complete);
        expect(completeProgress.percentage, 1.0);
      });

      test('ConversionProgress.fromMap handles unknown stage', () {
        // Given: Progress with invalid stage
        final progress = ConversionProgress.fromMap({
          'percentage': 0.5,
          'stage': 'invalid_stage',
          'message': 'Processing...',
        });

        // Then: Should default to unknown
        expect(progress.stage, ConversionStage.unknown);
      });
    });

    // =========================================================================
    // Test Group: Conversion Cancellation
    // =========================================================================

    group('Conversion Cancellation', () {
      test('cancelConversion completes without error', () async {
        // Given: Active conversion
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'cancelConversion') {
              return null; // Success
            }
            return null;
          },
        );

        // When: Canceling conversion
        await channel.cancelConversion();

        // Then: Should complete without error
        expect(methodCallLog.length, 1);
        expect(methodCallLog[0].method, 'cancelConversion');
      });

      test('cancelConversion throws exception on platform error', () async {
        // Given: Platform error during cancel
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('one.vron.mobile/asset_converter'),
          (MethodCall methodCall) async {
            methodCallLog.add(methodCall);

            if (methodCall.method == 'cancelConversion') {
              throw PlatformException(
                code: 'CANCEL_FAILED',
                message: 'No active conversion to cancel',
              );
            }
            return null;
          },
        );

        // When/Then: Should throw AssetConverterException
        expect(
          () => channel.cancelConversion(),
          throwsA(
            isA<AssetConverterException>().having(
              (e) => e.message,
              'message',
              contains('Failed to cancel conversion'),
            ),
          ),
        );
      });
    });

    // =========================================================================
    // Test Group: Data Model Serialization
    // =========================================================================

    group('Data Model Serialization', () {
      test('ConversionOptions.toMap serializes correctly', () {
        // Given: ConversionOptions with all fields
        const options = ConversionOptions(
          optimizeSize: true,
          includeMaterials: false,
          maxTextureSize: 1024,
          compressionLevel: 8,
        );

        // When: Converting to map
        final map = options.toMap();

        // Then: Should include all fields
        expect(map['optimizeSize'], isTrue);
        expect(map['includeMaterials'], isFalse);
        expect(map['maxTextureSize'], 1024);
        expect(map['compressionLevel'], 8);
      });

      test('ConversionOptions.toMap omits null maxTextureSize', () {
        // Given: ConversionOptions without maxTextureSize
        const options = ConversionOptions();

        // When: Converting to map
        final map = options.toMap();

        // Then: Should not include maxTextureSize
        expect(map.containsKey('maxTextureSize'), isFalse);
      });

      test('NavmeshOptions.toMap serializes correctly', () {
        // Given: NavmeshOptions
        const options = NavmeshOptions(
          simplificationLevel: 0.8,
          minSurfaceArea: 0.2,
          maxSlopeAngle: 35.0,
        );

        // When: Converting to map
        final map = options.toMap();

        // Then: Should include all fields
        expect(map['simplificationLevel'], 0.8);
        expect(map['minSurfaceArea'], 0.2);
        expect(map['maxSlopeAngle'], 35.0);
      });

      test('ConversionResult.fromMap deserializes correctly', () {
        // Given: Result map
        final resultMap = {
          'glbPath': '/tmp/output.glb',
          'fileSize': 1024000,
          'durationMs': 2500,
          'metadata': {
            'textureCount': 5,
            'materialCount': 3,
          },
        };

        // When: Creating ConversionResult from map
        final result = ConversionResult.fromMap(resultMap);

        // Then: Should deserialize all fields
        expect(result.glbPath, '/tmp/output.glb');
        expect(result.fileSize, 1024000);
        expect(result.durationMs, 2500);
        expect(result.metadata['textureCount'], 5);
      });

      test('NavmeshResult.fromMap deserializes correctly', () {
        // Given: Navmesh result map
        final resultMap = {
          'navmeshPath': '/tmp/navmesh.glb',
          'fileSize': 102400,
          'triangleCount': 850,
          'surfaceArea': 42.5,
        };

        // When: Creating NavmeshResult from map
        final result = NavmeshResult.fromMap(resultMap);

        // Then: Should deserialize all fields
        expect(result.navmeshPath, '/tmp/navmesh.glb');
        expect(result.fileSize, 102400);
        expect(result.triangleCount, 850);
        expect(result.surfaceArea, 42.5);
      });
    });
  });
}
