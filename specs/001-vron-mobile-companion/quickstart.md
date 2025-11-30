# Quickstart: VRON Mobile Companion

**Feature**: 001-vron-mobile-companion
**Date**: 2025-11-30
**Purpose**: Step-by-step guide to set up development environment, run the app, and validate core workflows

## Prerequisites

**Hardware**:
- **For iOS development**: MacBook with macOS 13+ (Ventura or newer)
- **For LiDAR testing**: iPhone 12 Pro or newer with iOS 16+
- **For Android development**: Any machine with Android Studio

**Software**:
- Flutter 3.24+ ([Install Flutter](https://docs.flutter.dev/get-started/install))
- Xcode 15+ (for iOS development)
- CocoaPods 1.12+ (`sudo gem install cocoapods`)
- Android Studio with Android SDK 29+ (for Android development)
- Git 2.30+
- VS Code or Android Studio with Flutter/Dart plugins

**Accounts**:
- vron.one account (create at https://app.vron.stage.motorenflug.at/en/auth/sign-up)
- Apple Developer account (for TestFlight deployment)
- GitHub access to repository

---

## Step 1: Clone and Setup Repository

```bash
# Clone repository
git clone <repository-url>
cd vron-mobile

# Checkout feature branch
git checkout 001-vron-mobile-companion

# Install Flutter dependencies
flutter pub get

# Verify Flutter installation and connected devices
flutter doctor -v
flutter devices
```

**Expected Output**:
```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.24.0, on macOS 14.2)
[✓] Xcode - develop for iOS and macOS (Xcode 15.2)
[✓] Android Studio (version 2023.3)
[✓] Connected device (2 available)
```

---

## Step 2: Configure Environment Variables

Create `.env` file in project root:

```bash
# .env
GRAPHQL_ENDPOINT=https://api.vron.stage.motorenflug.at/graphql
GRAPHQL_WS_ENDPOINT=wss://api.vron.stage.motorenflug.at/graphql
ENV=development
```

Load environment variables in `lib/core/config/env_config.dart`:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get graphqlEndpoint => dotenv.env['GRAPHQL_ENDPOINT']!;
  static String get graphqlWsEndpoint => dotenv.env['GRAPHQL_WS_ENDPOINT']!;
  static String get environment => dotenv.env['ENV'] ?? 'development';
}
```

---

## Step 3: iOS Setup

### 3.1 Install CocoaPods Dependencies

```bash
cd ios
pod install
cd ..
```

### 3.2 Configure Xcode Project

Open `ios/Runner.xcworkspace` in Xcode:

1. **Set Bundle Identifier**: `one.vron.mobile.dev` (for dev builds)
2. **Set Team**: Select your Apple Developer team
3. **Set Deployment Target**: iOS 16.0 minimum
4. **Enable Capabilities**:
   - Camera (for LiDAR scanning)
   - Photos (for scan previews)

### 3.3 Add Privacy Permissions

Edit `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for room scanning with LiDAR.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is required to save scan previews.</string>
```

### 3.4 Run on iOS Simulator (No LiDAR)

```bash
# List available iOS simulators
flutter emulators

# Launch iOS Simulator
flutter emulators --launch apple_ios_simulator

# Run app (project management only, no scanning)
flutter run
```

### 3.5 Run on Physical Device (LiDAR Capable)

```bash
# Connect iPhone 12 Pro+ via USB
# Ensure device is unlocked and trusts your Mac

# Run on device
flutter run -d <device-id>
```

---

## Step 4: Android Setup

### 4.1 Configure Android SDK

Open Android Studio → SDK Manager:
- Install Android SDK Platform 29+ (API Level 29+)
- Install Android SDK Build-Tools 34.0.0+
- Install Android Emulator

### 4.2 Add Permissions

Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-feature android:name="android.hardware.camera.ar" android:required="false" />
```

### 4.3 Run on Android Emulator

```bash
# List available Android emulators
flutter emulators

# Launch Android Emulator
flutter emulators --launch Pixel_7_Pro_API_34

# Run app (graceful degradation: no scanning on emulator)
flutter run
```

### 4.4 Run on Physical Device

```bash
# Enable USB Debugging on Android device
# Connect via USB

# Run on device
flutter run -d <device-id>
```

---

## Step 5: Test Authentication Flow

### 5.1 Launch App

```bash
flutter run
```

### 5.2 Sign In with Test Credentials

Use test account from `req/AUTHENTICATION.md`:
- **Email**: `rusuandreicristian+10@gmail.com`
- **Password**: `QuackQuackIAmADuck`

**Expected Result**:
1. Enter credentials on login screen
2. App calls `signIn` GraphQL mutation
3. Auth token constructed and stored in `flutter_secure_storage`
4. Navigate to projects list screen
5. See list of test projects fetched from GraphQL API

**Verification**:
```bash
# Check logs for successful authentication
flutter logs | grep "signIn"

# Expected log:
# [GraphQL] Mutation signIn: Success (accessToken received)
# [Auth] Token stored securely
# [Navigation] Navigated to /projects
```

---

## Step 6: Test Offline Mode

### 6.1 Enable Airplane Mode

1. Open projects list (while online)
2. Enable Airplane Mode on device
3. Pull-to-refresh projects list

**Expected Result**:
- App displays cached projects from Hive/Drift
- Subtle notification: "Offline mode - showing cached data"
- No loading spinner (instant response from cache)

### 6.2 Edit Project Offline

1. Tap a project to view details
2. Edit project name
3. Save changes

**Expected Result**:
- Optimistic UI update (change visible immediately)
- Mutation queued in Drift `UploadQueue` table
- No error message shown to user

### 6.3 Restore Connectivity

1. Disable Airplane Mode
2. Wait for auto-sync

**Expected Result**:
- Queued mutation sent to GraphQL API
- On success: Update `synced_at` timestamp
- On failure: Retry with exponential backoff (1s, 2s, 4s)
- Notification: "Changes synced"

**Verification**:
```bash
# Check logs for sync behavior
flutter logs | grep "sync"

# Expected logs:
# [Sync] Queued mutation: updateProject
# [Sync] Network restored, processing queue
# [GraphQL] Mutation updateProject: Success
# [Sync] Queue cleared (1 mutation synced)
```

---

## Step 7: Test Room Scanning (iOS Only)

### 7.1 Navigate to Project Detail

1. Sign in to app
2. Tap a project from list
3. Verify "Add Room Scan" button is visible (iOS LiDAR devices only)

### 7.2 Initiate Room Scan

1. Tap "Add Room Scan" button
2. RoomPlan UI launches (native iOS interface)
3. Scan room by moving device around space

**Expected Result**:
- Real-time 3D mesh preview during scan
- Automatic room boundary detection
- Visual feedback for captured walls/furniture
- "Done" button enabled after sufficient data captured

### 7.3 Complete Scan

1. Tap "Done" in RoomPlan UI
2. App processes scan:
   - USDZ file saved to temp directory
   - USDZ→GLB conversion via Model I/O
   - GLB file size validation (<50MB)
   - Navigation mesh generation via Recast

**Expected Result**:
- Processing dialog shows progress: "Converting 3D model..."
- 3D preview screen displays textured GLB model
- User can rotate, zoom, pan to inspect scan
- Room auto-named: "Room - 2025-11-30 14:23"

**Verification**:
```bash
# Check logs for processing steps
flutter logs | grep "scan"

# Expected logs:
# [RoomScanner] Scan completed: /tmp/room.usdz (1234 vertices)
# [AssetConverter] Converting USDZ to GLB...
# [AssetConverter] GLB conversion completed in 8.3s (5 textures preserved)
# [NavmeshGenerator] Generating navmesh...
# [NavmeshGenerator] Navmesh generated in 12.4s (456 triangles)
# [UploadQueue] Queued upload: scene.glb (25.6MB), navmesh.glb (2.1MB)
```

---

## Step 8: Test Demo Content

### 8.1 Navigate to Demos

1. Sign in to app
2. Tap "Demos" tab in bottom navigation

### 8.2 Browse Sailing Theme

1. Tap "Sailing" category
2. Scroll through demo assets (boats, docks, nautical equipment)
3. Tap an asset to view 3D preview

**Expected Result**:
- 3D viewer loads GLB model from CDN
- PBR textures rendered correctly (albedo, normal, metallic, roughness)
- Touch controls: pinch to zoom, drag to rotate, two-finger drag to pan
- 30fps minimum rendering performance

### 8.3 Browse Aviation Theme

1. Tap "Aviation" category
2. Tap an asset (aircraft, hangar) to view 3D preview

**Expected Result**:
- Same 3D viewer behavior as sailing assets
- All textures preserved and rendered

**Verification**:
```bash
# Check logs for 3D rendering performance
flutter logs | grep "fps"

# Expected log:
# [3DViewer] Rendering at 32.4 fps (above 30fps target)
```

---

## Step 9: Run Tests

### 9.1 Unit Tests

```bash
# Run all unit tests
flutter test

# Run with coverage
flutter test --coverage

# View coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

**Expected Result**:
- All tests pass
- Coverage >80% (Constitution Principle III)

### 9.2 Widget Tests

```bash
# Run widget tests only
flutter test test/widget_test/

# Run golden tests (visual regression)
flutter test test/golden_test/
```

**Expected Result**:
- All widget tests pass
- Golden tests match baselines

### 9.3 Integration Tests

```bash
# Run integration tests on device/simulator
flutter test integration_test/

# Run specific test
flutter test integration_test/auth_flow_test.dart
```

**Expected Result**:
- All integration tests pass
- Platform channel contracts validated

---

## Step 10: Build for Release

### 10.1 iOS Release Build

```bash
# Build iOS release IPA
flutter build ios --release

# Or build with Fastlane (recommended for TestFlight)
cd ios
fastlane beta
```

**Expected Result**:
- IPA built successfully
- Uploaded to TestFlight (if using Fastlane)
- Build ID embedded from GitHub Actions run number

### 10.2 Android Release Build

```bash
# Build Android release APK
flutter build apk --release

# Or build App Bundle (recommended for Play Store)
flutter build appbundle --release
```

**Expected Result**:
- APK/AAB built successfully
- Signed with release keystore

---

## Troubleshooting

### Issue: "Camera permission denied"

**Solution**:
- iOS: Check `Info.plist` has `NSCameraUsageDescription`
- Android: Check `AndroidManifest.xml` has `CAMERA` permission
- Device: Go to Settings → [App Name] → Enable Camera

### Issue: "LiDAR unavailable"

**Solution**:
- Verify device is iPhone 12 Pro or newer
- Restart device
- Check for iOS software updates

### Issue: "GraphQL authentication failed"

**Solution**:
- Verify `.env` file has correct `GRAPHQL_ENDPOINT`
- Check network connectivity
- Verify test credentials from `req/AUTHENTICATION.md`
- Check auth token encoding (base64 format)

### Issue: "USDZ→GLB conversion failed"

**Solution**:
- Check iOS version is 16+ (Model I/O requirement)
- Verify USDZ file is not corrupted
- Try re-scanning with better lighting
- Check device storage (need 500MB+ free)

### Issue: "App exceeds 300MB memory limit"

**Solution**:
- Profile with Xcode Instruments or Android Profiler
- Check for memory leaks in 3D viewer (dispose textures)
- Reduce cached GLB files (clean up after upload)
- Use `ListView.builder` for long lists (lazy loading)

---

## Next Steps

1. **Review Plan**: Read `plan.md` for full architecture details
2. **Implement Tasks**: Use `/speckit.tasks` to generate implementation task list
3. **CI/CD Setup**: Configure GitHub Actions workflows (see `research.md` section 10)
4. **POC Sprint**: Validate USDZ→GLB conversion fidelity (HIGH-RISK component)

---

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Apple RoomPlan](https://developer.apple.com/documentation/roomplan)
- [GraphQL Flutter](https://pub.dev/packages/graphql_flutter)
- [Riverpod](https://riverpod.dev/)
- [Drift Database](https://drift.simonbinder.eu/)
- [vron.one API Docs](https://api.vron.stage.motorenflug.at/graphql)
