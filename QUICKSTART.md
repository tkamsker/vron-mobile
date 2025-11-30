# VRON Mobile - Quick Start Guide

Get up and running with VRON Mobile Companion in minutes.

## Prerequisites

- **Flutter 3.24+** (currently using 3.38.2)
- **iOS:** macOS with Xcode 14+
- **Android:** Android Studio with SDK 26+ (Android 8.0+)

## 1. First-Time Setup

Run the automated setup script:

```bash
./scripts/setup.sh
```

This will:
- ✓ Check Flutter installation
- ✓ Install all dependencies
- ✓ Generate code
- ✓ Run analyzer and tests
- ✓ Verify everything works

**Manual setup (if preferred):**
```bash
# 1. Create environment file
cp .env.example .env
nano .env  # Edit with your API endpoints

# 2. Install dependencies
flutter pub get

# 3. Generate code
dart run build_runner build --delete-conflicting-outputs

# 4. Verify setup
flutter analyze
flutter test
```

---

## 2. Launch the App

### iOS Simulator (macOS only)

```bash
./scripts/run_ios.sh
```

**Or manually:**
```bash
open -a Simulator
flutter run
```

### Android Emulator

```bash
./scripts/run_android.sh
```

**Or manually:**
```bash
flutter emulators --launch Pixel_7_Pro_API_34
flutter run
```

### Physical Device

**iOS:**
```bash
# 1. Connect iPhone via USB
# 2. Trust computer on device
# 3. Run
flutter run

# Or use wireless debugging (after USB connect once)
flutter run -d <device-name>
```

**Android:**
```bash
# 1. Enable Developer Options (tap Build number 7x)
# 2. Enable USB debugging
# 3. Connect device
# 4. Accept debugging authorization
# 5. Run
flutter run
```

---

## 3. Development Workflow

### Make Code Changes

```bash
# Edit files in lib/
# Press 'r' for hot reload (fast, preserves state)
# Press 'R' for hot restart (full restart)
# Press 'q' to quit
```

### Run Tests After Changes

```bash
./scripts/test.sh
```

This runs:
- Flutter analyzer
- All tests
- Coverage report

### Continuous Testing (Watch Mode)

```bash
./scripts/watch.sh
```

Automatically runs tests when you save files. Perfect for TDD!

**Requirements:** Install `fswatch` first
```bash
# macOS
brew install fswatch

# Linux
sudo apt-get install fswatch
```

---

## 4. Common Commands

```bash
# Run all tests
./scripts/test.sh

# Quick analysis
./scripts/analyze.sh

# Clean build
./scripts/clean.sh

# Launch iOS
./scripts/run_ios.sh

# Launch Android
./scripts/run_android.sh

# First-time setup
./scripts/setup.sh

# Watch mode
./scripts/watch.sh
```

---

## 5. Testing Checklist

Before committing code:

```bash
# 1. Run analyzer
./scripts/analyze.sh

# 2. Run tests
./scripts/test.sh

# 3. Test on simulator/device
./scripts/run_ios.sh
# or
./scripts/run_android.sh
```

**One-liner:**
```bash
./scripts/test.sh && git commit -m "your message"
```

---

## 6. Project Structure

```
vron-mobile/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── core/                        # Core infrastructure
│   │   ├── auth/                    # Authentication
│   │   ├── cache/                   # Cache management
│   │   ├── database/                # Local database (Drift)
│   │   ├── errors/                  # Custom exceptions
│   │   └── utils/                   # Utilities
│   └── features/                    # Feature modules
│       ├── auth/                    # Auth screens
│       ├── projects/                # Project management
│       ├── rooms/                   # Room scanning
│       └── viewer/                  # 3D viewer
├── packages/                        # Local packages
│   └── vron_graphql_client/        # GraphQL client
├── test/                            # Tests
├── scripts/                         # Development scripts
├── .env                             # Environment config
└── pubspec.yaml                     # Dependencies
```

---

## 7. Environment Configuration

Edit `.env` file:

```bash
# API Endpoints
GRAPHQL_ENDPOINT=https://api.vron.stage.motorenflug.at/graphql
GRAPHQL_WS_ENDPOINT=wss://api.vron.stage.motorenflug.at/graphql

# Environment
ENV=development
DEBUG=true
```

---

## 8. Troubleshooting

### "No devices found"

```bash
# iOS
open -a Simulator

# Android
flutter emulators
flutter emulators --launch <emulator-id>
```

### Build fails

```bash
./scripts/clean.sh
./scripts/setup.sh
```

### Tests fail

```bash
# Regenerate code
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test
```

### Hot reload not working

```bash
# Press 'R' for full restart
# Or restart: flutter run --hot
```

---

## 9. Key Features

### Offline-First Architecture
- GraphQL cache with 24-hour TTL
- Local Drift database
- Automatic background sync
- Optimistic updates

### Authentication
- Base64-encoded JWT tokens per vron.one spec
- Secure storage (iOS Keychain, Android KeyStore)
- Auto token refresh

### Error Handling
- Custom exception types
- Retry strategy with exponential backoff (1s, 2s, 4s)
- Detailed error messages

### Testing
- Unit tests
- Widget tests
- Integration tests
- Code coverage reports

---

## 10. Next Steps

1. **Read Documentation**
   - [TESTING.md](TESTING.md) - Complete testing guide
   - [scripts/README.md](scripts/README.md) - Script documentation

2. **Explore Codebase**
   ```bash
   # View project structure
   tree lib/ -L 2

   # Search for specific functionality
   grep -r "AuthState" lib/
   ```

3. **Make Your First Change**
   - Pick a task from issues
   - Create feature branch
   - Make changes with hot reload
   - Run tests
   - Commit and push

4. **Join Development**
   - See CONTRIBUTING.md for guidelines
   - Check open issues
   - Ask questions in discussions

---

## Quick Command Reference

```bash
# Setup & Installation
./scripts/setup.sh                    # First-time setup
flutter pub get                       # Install dependencies
dart run build_runner build          # Generate code

# Running
./scripts/run_ios.sh                  # Launch iOS
./scripts/run_android.sh              # Launch Android
flutter run                           # Run (auto-detect device)
flutter run -d <device-id>           # Run on specific device

# Testing
./scripts/test.sh                     # Full test suite
./scripts/analyze.sh                  # Quick analysis
./scripts/watch.sh                    # Continuous testing
flutter test                          # Run tests only
flutter test --coverage              # With coverage

# Maintenance
./scripts/clean.sh                    # Clean build
flutter doctor                        # Check setup
flutter devices                       # List devices
flutter emulators                     # List emulators

# Development
flutter run --hot                     # Hot reload mode
flutter run --profile                # Profile mode
flutter run --release                # Release mode
```

---

## Support

- **Documentation:** See TESTING.md for comprehensive guide
- **Issues:** Report bugs via GitHub issues
- **Questions:** Use GitHub discussions
- **API Docs:** https://api.vron.stage.motorenflug.at/graphql

---

**Ready to start? Run `./scripts/setup.sh` and you're good to go! 🚀**
