# VRON Mobile - Testing Guide
flutter run -d "19EA67E6-6120-45A9-8D83-1A007D0306AA"

Complete guide for testing VRON Mobile Companion app on simulators, emulators, and physical devices.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [iOS Testing](#ios-testing)
- [Android Testing](#android-testing)
- [Running Tests](#running-tests)
- [Shell Scripts](#shell-scripts)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

```bash
# Verify Flutter installation
flutter doctor -v

# Expected output:
# [✓] Flutter (Channel stable, 3.38.2+)
# [✓] Android toolchain
# [✓] Xcode (for iOS development)
# [✓] Chrome (for web debugging)
# [✓] VS Code / Android Studio
```

### Environment Setup

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Generate code:**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

3. **Configure environment variables:**
   ```bash
   # Copy .env.example to .env
   cp .env.example .env

   # Edit .env with your API endpoints
   nano .env
   ```

---

## Quick Start

### Run All Tests (Recommended)

```bash
# Use the test script for comprehensive testing
./scripts/test.sh
```

This runs:
- ✓ Flutter analyze
- ✓ Unit tests
- ✓ Widget tests
- ✓ Code coverage report

### Launch on iOS Simulator

```bash
# Quick launch
./scripts/run_ios.sh

# Or manually:
open -a Simulator
flutter run
```

### Launch on Android Emulator

```bash
# Quick launch
./scripts/run_android.sh

# Or manually:
flutter emulators --launch <emulator_id>
flutter run
```

---

## iOS Testing

### iOS Simulator Setup

1. **List available simulators:**
   ```bash
   xcrun simctl list devices
   ```

2. **Launch specific simulator:**
   ```bash
   # iPhone 15 Pro (recommended for LiDAR testing)
   open -a Simulator --args -CurrentDeviceUDID <device-id>

   # Or use convenient names:
   xcrun simctl boot "iPhone 15 Pro"
   open -a Simulator
   ```

3. **Run app on simulator:**
   ```bash
   flutter run -d <device-id>

   # Or let Flutter auto-select:
   flutter run
   ```

### iOS Physical Device Testing

#### Prerequisites
- Apple Developer Account
- Physical iPhone with iOS 14.0+
- USB cable or WiFi network

#### Steps

1. **Connect iPhone via USB**

2. **Trust computer on device:**
   - Unlock iPhone
   - Tap "Trust" when prompted

3. **Configure signing in Xcode:**
   ```bash
   open ios/Runner.xcworkspace
   ```
   - Select "Runner" target
   - Go to "Signing & Capabilities"
   - Select your Team
   - Choose automatic signing

4. **Run on device:**
   ```bash
   flutter devices  # List connected devices
   flutter run -d <device-id>
   ```

5. **Trust developer on device:**
   - Settings → General → VPN & Device Management
   - Trust your developer certificate

### iOS LiDAR Testing (Physical Device Only)

**Supported Devices:**
- iPhone 12 Pro / Pro Max
- iPhone 13 Pro / Pro Max
- iPhone 14 Pro / Pro Max
- iPhone 15 Pro / Pro Max
- iPad Pro (2020 and later)

```bash
# Check LiDAR availability at runtime
# App will detect and enable/disable scanning features
```

### iOS Wireless Debugging

1. **Enable wireless debugging:**
   - Connect device via USB
   - In Xcode: Window → Devices and Simulators
   - Select device → Check "Connect via network"

2. **Disconnect USB and run:**
   ```bash
   flutter run -d <device-name>
   ```

---

## Android Testing

### Android Emulator Setup

1. **List available emulators:**
   ```bash
   flutter emulators
   ```

2. **Create new emulator (if needed):**
   ```bash
   # Open AVD Manager
   $ANDROID_HOME/tools/bin/avdmanager create avd \
     -n "Pixel_7_Pro_API_34" \
     -k "system-images;android-34;google_apis;x86_64" \
     -d "pixel_7_pro"
   ```

3. **Launch emulator:**
   ```bash
   flutter emulators --launch <emulator_id>

   # Or directly:
   $ANDROID_HOME/emulator/emulator -avd Pixel_7_Pro_API_34
   ```

4. **Run app on emulator:**
   ```bash
   flutter run
   ```

### Android Physical Device Testing

#### Prerequisites
- Android device with Android 8.0+ (API 26+)
- USB cable
- USB debugging enabled

#### Steps

1. **Enable Developer Options on device:**
   - Settings → About phone
   - Tap "Build number" 7 times

2. **Enable USB debugging:**
   - Settings → System → Developer options
   - Enable "USB debugging"

3. **Connect device via USB:**
   ```bash
   # Verify connection
   adb devices

   # Should show:
   # List of devices attached
   # ABC123XYZ    device
   ```

4. **Accept debugging authorization:**
   - Tap "Allow" on device when prompted

5. **Run on device:**
   ```bash
   flutter run -d <device-id>
   ```

### Android Wireless Debugging (Android 11+)

1. **Enable wireless debugging:**
   - Settings → Developer options → Wireless debugging
   - Tap "Pair device with pairing code"

2. **Pair device:**
   ```bash
   # Note the IP address and port from device
   adb pair <ip>:<port>
   # Enter pairing code when prompted
   ```

3. **Connect wirelessly:**
   ```bash
   adb connect <ip>:<port>
   flutter run
   ```

---

## Running Tests

### Unit Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/unit/auth_test.dart

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Widget Tests

```bash
# Run widget tests
flutter test test/widget_test.dart

# Update golden files (for UI regression testing)
flutter test --update-goldens
```

### Integration Tests

```bash
# Run integration tests on connected device
flutter test integration_test/app_test.dart

# Run on specific device
flutter test integration_test/app_test.dart -d <device-id>
```

### Performance Profiling

```bash
# Profile mode (better performance metrics)
flutter run --profile

# Release mode (production performance)
flutter run --release

# Performance overlay
flutter run --profile --trace-skia
```

### Hot Reload & Hot Restart

While app is running:
- **Hot Reload:** Press `r` (faster, preserves state)
- **Hot Restart:** Press `R` (full restart)
- **Quit:** Press `q`

---

## Shell Scripts

All scripts are in the `scripts/` directory. Make them executable first:

```bash
chmod +x scripts/*.sh
```

### 1. `test.sh` - Comprehensive Testing

Runs full test suite with code analysis.

```bash
./scripts/test.sh
```

**What it does:**
1. Cleans build artifacts
2. Gets dependencies
3. Generates code
4. Runs analyzer
5. Runs all tests
6. Generates coverage report

**Output:**
- ✓ Analyzer results
- ✓ Test results
- ✓ Coverage percentage
- ✓ HTML coverage report

### 2. `run_ios.sh` - iOS Quick Launch

Launches app on iOS simulator.

```bash
./scripts/run_ios.sh [device-name]

# Examples:
./scripts/run_ios.sh                    # Auto-select
./scripts/run_ios.sh "iPhone 15 Pro"    # Specific device
```

### 3. `run_android.sh` - Android Quick Launch

Launches app on Android emulator.

```bash
./scripts/run_android.sh [emulator-id]

# Examples:
./scripts/run_android.sh                      # Auto-select
./scripts/run_android.sh Pixel_7_Pro_API_34   # Specific emulator
```

### 4. `analyze.sh` - Code Analysis

Runs Flutter analyzer with detailed output.

```bash
./scripts/analyze.sh
```

### 5. `clean.sh` - Clean Build

Removes all build artifacts and caches.

```bash
./scripts/clean.sh
```

**What it removes:**
- build/ directory
- .dart_tool/ cache
- Generated files (*.g.dart, *.freezed.dart)
- iOS build artifacts
- Android build artifacts
- Pub cache for project

---

## Troubleshooting

### Common Issues

#### 1. "No devices found"

**Solution:**
```bash
# Check connected devices
flutter devices

# iOS: Open simulator
open -a Simulator

# Android: Launch emulator
flutter emulators --launch <emulator-id>
```

#### 2. Build fails with "Gradle error"

**Solution:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

#### 3. iOS signing issues

**Solution:**
```bash
# Open Xcode workspace
open ios/Runner.xcworkspace

# Fix signing in Xcode UI:
# Runner → Signing & Capabilities → Select Team
```

#### 4. "Flutter doctor" shows issues

**Solution:**
```bash
flutter doctor -v

# Follow specific recommendations:
# - Install Xcode: Download from App Store
# - Install Android Studio: https://developer.android.com/studio
# - Accept licenses: flutter doctor --android-licenses
```

#### 5. Hot reload not working

**Solution:**
```bash
# Full restart
flutter run --hot

# Or press 'R' during development
```

#### 6. Tests fail with "No such file or directory"

**Solution:**
```bash
# Regenerate code
dart run build_runner build --delete-conflicting-outputs

# Run tests again
flutter test
```

#### 7. "The operation couldn't be completed" (iOS)

**Solution:**
```bash
# Reset simulator
xcrun simctl shutdown all
xcrun simctl erase all

# Restart Xcode
killall Xcode
open -a Xcode

# Clean and rebuild
flutter clean
flutter run
```

#### 8. Android emulator slow

**Solution:**
```bash
# Enable hardware acceleration (KVM on Linux, HAXM on Mac/Windows)
# Allocate more RAM to emulator (4GB+ recommended)

# In AVD Manager:
# - Edit emulator
# - Advanced Settings → RAM: 4096 MB
# - Graphics: Hardware - GLES 2.0
```

---

## Testing Workflow

### Development Iteration Cycle

1. **Make code changes**

2. **Run analyzer:**
   ```bash
   ./scripts/analyze.sh
   ```

3. **Run tests:**
   ```bash
   ./scripts/test.sh
   ```

4. **Test on simulator/device:**
   ```bash
   # iOS
   ./scripts/run_ios.sh

   # Android
   ./scripts/run_android.sh
   ```

5. **Use hot reload for rapid iteration:**
   - Make UI changes
   - Press `r` to hot reload
   - See changes instantly

6. **Commit when tests pass:**
   ```bash
   git add .
   git commit -m "feat: add user authentication"
   git push
   ```

### Pre-Commit Checklist

```bash
# Run this before every commit
./scripts/test.sh && git commit -m "your message"
```

### Continuous Testing (Watch Mode)

```bash
# Install watch tool
dart pub global activate test_watch

# Watch and re-run tests on file changes
test_watch
```

---

## CI/CD Integration

### GitHub Actions Example

See `.github/workflows/test.yml` for automated testing on push/PR.

### Local CI Simulation

```bash
# Run the same checks as CI
./scripts/test.sh
```

---

## Performance Testing

### Benchmarking

```bash
# Profile app startup
flutter run --profile --trace-startup

# Profile specific operation
flutter run --profile --trace-skia
```

### Memory Profiling

```bash
# Run with memory profiling
flutter run --profile

# In DevTools:
# - Open http://127.0.0.1:9100
# - Go to Memory tab
# - Take heap snapshot
```

### Network Profiling

```bash
# Enable network logging
flutter run --dart-define=DEBUG_NETWORK=true

# View in DevTools Network tab
```

---

## Additional Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [iOS Simulator Guide](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device)
- [Android Emulator Guide](https://developer.android.com/studio/run/emulator)
- [Flutter DevTools](https://docs.flutter.dev/tools/devtools)

---

## Quick Reference Commands

```bash
# Get devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Run tests
flutter test

# Analyze code
flutter analyze

# Clean build
flutter clean

# Generate code
dart run build_runner build --delete-conflicting-outputs

# Update dependencies
flutter pub get
flutter pub upgrade

# Check Flutter version
flutter --version

# Doctor check
flutter doctor -v
```
