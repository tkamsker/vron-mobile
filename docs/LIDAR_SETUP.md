# LiDAR Scanning Setup and Requirements

This document explains how LiDAR scanning is configured and how camera permissions work in the VRON Mobile app.

## Overview

The app uses Apple's RoomPlan framework for LiDAR scanning. Camera permission is explicitly requested when the scan screen loads using the `permission_handler` package.

## How It Works

### 1. Hardware Detection

When the scan screen loads, the app:
1. Requests camera permission (required for RoomPlan)
2. Checks if the device supports LiDAR

```dart
final cameraStatus = await Permission.camera.status;
if (!cameraStatus.isGranted) {
  final result = await Permission.camera.request();
}

final available = await RoomPlanScanner.isSupported();
```

RoomPlanScanner.isSupported() checks for:
- iOS 16.0 or later
- LiDAR sensor (iPhone 12 Pro+, iPad Pro 2020+)
- ARKit support

### 2. Scan Button State

The "Start Scanning" button is:
- **Enabled** if both camera permission is granted AND LiDAR hardware is available
- **Disabled** if either is missing

```dart
ElevatedButton(
  onPressed: _isLidarAvailable
      ? (_isScanning ? _stopScanning : _startScanning)
      : null,  // Disabled when LiDAR not available or permission denied
  ...
)
```

### 3. Permission Request Flow

When the scan screen opens:
1. App checks camera permission status
2. If not granted, shows iOS permission dialog automatically
3. User grants/denies permission
4. If granted, checks LiDAR hardware availability
5. Updates UI accordingly

## iOS Configuration

### Required: Info.plist

File: `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>VRON Mobile needs camera access to scan rooms using LiDAR and create 3D models.</string>
```

**IMPORTANT**: This key must be present BEFORE the app is installed. If you add it after installation, you must **uninstall and reinstall** the app for iOS to recognize the permission.

### Required: pubspec.yaml

```yaml
dependencies:
  permission_handler: ^11.0.0
  roomplan_flutter: ^0.1.4
```

### Device Requirements

- **iPhone**: 12 Pro, 12 Pro Max, 13 Pro, 13 Pro Max, 14 Pro, 14 Pro Max, 15 Pro, 15 Pro Max, or newer Pro models
- **iPad**: iPad Pro 11-inch (2nd gen+), iPad Pro 12.9-inch (4th gen+)
- **iOS Version**: 16.0 or later

## Implementation Details

### File: `lib/features/scan/screens/scan_screen.dart`

#### Check LiDAR Availability (lines 67-156)

```dart
Future<void> _checkLidarAvailability() async {
  if (!Platform.isIOS) {
    setState(() {
      _isLidarAvailable = false;
      _isCheckingLidar = false;
    });
    return;
  }

  try {
    // Step 1: Check and request camera permission
    final cameraStatus = await Permission.camera.status;

    if (!cameraStatus.isGranted) {
      final result = await Permission.camera.request();

      if (!result.isGranted) {
        // Permission denied - show message with Settings link
        setState(() {
          _isLidarAvailable = false;
          _isCheckingLidar = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Camera permission is required for LiDAR scanning. Please enable it in Settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
    }

    // Step 2: Check if device has LiDAR hardware
    final available = await RoomPlanScanner.isSupported();

    setState(() {
      _isLidarAvailable = available;
      _isCheckingLidar = false;
    });

    // Step 3: Show message if no LiDAR hardware
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'LiDAR scanning requires iPhone 12 Pro or newer, or iPad Pro (2020) or newer',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    print('Error checking LiDAR availability: $e');

    setState(() {
      _isLidarAvailable = false;
      _isCheckingLidar = false;
    });
  }
}
```

## User Flow

1. **Open Scan Screen**
   - App requests camera permission automatically (first time only)
   - iOS shows permission dialog

2. **User Grants Permission**
   - App checks if device has LiDAR hardware
   - Button enabled if LiDAR available
   - Ready to scan

3. **User Denies Permission**
   - Error message shown with Settings button
   - Scan button disabled
   - User must enable in Settings to proceed

4. **No LiDAR Hardware**
   - Even with permission, button stays disabled
   - Message explains device requirements

## Testing

### Test on LiDAR Device (iPhone 12 Pro+, iPad Pro 2020+)

```bash
# 1. Uninstall the app completely (important for permission registration!)
flutter run --uninstall-first -d YOUR_DEVICE_ID

# 2. Or manually uninstall from device, then:
flutter run -d YOUR_DEVICE_ID
```

**Expected Behavior:**
1. App launches successfully
2. Navigate to scan screen
3. iOS permission dialog appears automatically
4. Grant permission → Button enabled, ready to scan
5. Deny permission → Error message with Settings button

### Test on Non-LiDAR Device (iPhone 11, iPhone SE, etc.)

**Expected Behavior:**
1. App launches successfully
2. Navigate to scan screen
3. iOS permission dialog appears
4. Grant permission → Message: "LiDAR scanning requires iPhone 12 Pro or newer..."
5. Button remains disabled

## Troubleshooting

### Camera Permission Not Showing in iOS Settings

**Problem**: App installed BEFORE NSCameraUsageDescription was added to Info.plist

**Solution**: Uninstall and reinstall the app

```bash
# Complete uninstall and reinstall
flutter run --uninstall-first -d YOUR_DEVICE_ID
```

Or manually:
1. Long-press app icon → Remove App → Delete App
2. Run `flutter run -d YOUR_DEVICE_ID`

### Permission Dialog Not Appearing

**Possible Causes:**

1. **App was previously denied permission**
   - Go to Settings → VRON Mobile → Enable Camera
   - Or use the Settings button in the error message

2. **Info.plist missing NSCameraUsageDescription**
   - Verify `ios/Runner/Info.plist` has the key
   - Uninstall and reinstall

3. **permission_handler not installed**
   - Run `flutter pub get`
   - Rebuild the app

### Scan Button Always Disabled

**Check:**

1. **Camera permission granted**
   ```bash
   # Check Settings → VRON Mobile → Camera
   ```

2. **Device has LiDAR**
   - Must be iPhone 12 Pro or newer
   - Or iPad Pro 2020 or newer

3. **iOS version is 16.0+**
   - Check Settings → General → About → Software Version

4. **Platform is iOS**
   - Ensure running on physical iOS device (not simulator)

### "Camera permission is required" Message

This means:
- Permission was denied by user, OR
- App doesn't have permission in iOS Settings

**Solution**: Tap "Settings" button in the message to open iOS Settings and enable Camera permission.

### "LiDAR hardware is not available" Message

This means:
- Device doesn't have LiDAR sensor (must be iPhone 12 Pro+ or iPad Pro 2020+), OR
- iOS version is below 16.0, OR
- ARKit is not supported

## Why This Approach

The `permission_handler` package is used to explicitly request camera permission when the scan screen loads. This provides:

1. **Clear feedback**: User knows immediately if permission is needed
2. **Direct to Settings**: Settings button for easy permission management
3. **Proper sequencing**: Permission requested before hardware check
4. **Better UX**: No confusion about why scanning isn't working

**Critical iOS Limitation**: If the app is installed BEFORE `NSCameraUsageDescription` is added to Info.plist, iOS won't register the permission. Always uninstall and reinstall after adding this key.

## Related Files

- `lib/features/scan/screens/scan_screen.dart` - Main scanning implementation
- `ios/Runner/Info.plist` - Camera permission configuration
- `pubspec.yaml` - Dependencies (permission_handler, roomplan_flutter)
- `lib/features/scan/models/scan_data.dart` - Scan data models
- `lib/features/scan/screens/scan_complete_screen.dart` - Post-scan UI

## References

- [Apple RoomPlan Documentation](https://developer.apple.com/documentation/roomplan)
- [permission_handler Package](https://pub.dev/packages/permission_handler)
- [roomplan_flutter Package](https://pub.dev/packages/roomplan_flutter)
- [iOS Permission Best Practices](https://developer.apple.com/design/human-interface-guidelines/privacy)
- [LiDAR Scanner (Apple)](https://support.apple.com/guide/iphone/iph1b5a87a8e/ios)
