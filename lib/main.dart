import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// VRON Mobile Companion App
/// Flutter mobile app for real estate project scanning and management
///
/// Environment configuration is loaded from .env file
/// State management via Riverpod
/// Local storage via Hive and Drift

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Hive for local caching
  await Hive.initFlutter();

  runApp(
    const ProviderScope(
      child: VronMobileApp(),
    ),
  );
}

class VronMobileApp extends StatelessWidget {
  const VronMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VRON Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3), // VRON Blue
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const SetupCompletePage(),
    );
  }
}

/// Temporary page showing Phase 1 setup is complete
/// This will be replaced with proper routing in Phase 2
class SetupCompletePage extends StatelessWidget {
  const SetupCompletePage({super.key});

  @override
  Widget build(BuildContext context) {
    final env = dotenv.env['ENV'] ?? 'unknown';
    final endpoint = dotenv.env['GRAPHQL_ENDPOINT'] ?? 'not configured';

    return Scaffold(
      appBar: AppBar(
        title: const Text('VRON Mobile'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              const Text(
                'Phase 1: Setup Complete ✓',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Flutter project initialized successfully',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Environment Configuration:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Environment: $env'),
                    const SizedBox(height: 4),
                    Text(
                      'GraphQL Endpoint:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      endpoint,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Next: Phase 2 - Foundational Infrastructure',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
