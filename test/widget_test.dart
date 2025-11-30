// Basic widget test for VRON Mobile app
// Comprehensive tests will be added in Phase 3+ per TDD requirements

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vron_mobile/main.dart';

void main() {
  setUpAll(() async {
    // Initialize dotenv for tests
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: '''
      GRAPHQL_ENDPOINT=https://api.vron.stage.motorenflug.at/graphql
      GRAPHQL_WS_ENDPOINT=wss://api.vron.stage.motorenflug.at/graphql
      ENV=test
      DEBUG=false
    ''');
  });

  testWidgets('VRON Mobile app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(
      const ProviderScope(
        child: VronMobileApp(),
      ),
    );

    // Verify that our setup complete page is displayed
    expect(find.text('Phase 1: Setup Complete ✓'), findsOneWidget);
    expect(find.text('VRON Mobile'), findsOneWidget);
    expect(find.text('Environment: test'), findsOneWidget);
  });
}
