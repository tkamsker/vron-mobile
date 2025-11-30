#!/bin/bash

# VRON Mobile - Android Quick Launch Script
# Launches app on Android emulator or physical device

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Print header
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            VRON Mobile - Android Quick Launch                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Android SDK is installed
if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
    print_error "Android SDK not found"
    echo "Set ANDROID_HOME or ANDROID_SDK_ROOT environment variable"
    exit 1
fi

# Check if specific emulator was requested
EMULATOR_ID="$1"

# Get list of Android devices
print_status "Checking Android devices..."
DEVICES=$(flutter devices --machine | grep -o '"id":"android.*"' || true)

if [ -z "$DEVICES" ]; then
    print_warning "No Android devices or emulators found"

    # Get available emulators
    print_status "Checking available emulators..."
    EMULATORS=$(flutter emulators --machine | grep -o '"id":"[^"]*"' | cut -d'"' -f4 || true)

    if [ -z "$EMULATORS" ]; then
        print_error "No Android emulators found"
        echo ""
        echo "Create an emulator using Android Studio:"
        echo "  Tools → Device Manager → Create Device"
        exit 1
    fi

    # Use specified emulator or first available
    if [ -n "$EMULATOR_ID" ]; then
        TARGET_EMULATOR="$EMULATOR_ID"
    else
        TARGET_EMULATOR=$(echo "$EMULATORS" | head -1)
    fi

    print_status "Launching emulator: $TARGET_EMULATOR"
    flutter emulators --launch "$TARGET_EMULATOR" &

    # Wait for emulator to boot
    echo -n "Waiting for emulator to boot"
    for i in {1..60}; do
        echo -n "."
        sleep 2
        DEVICES=$(flutter devices --machine | grep -o '"id":"android.*"' || true)
        if [ -n "$DEVICES" ]; then
            echo ""
            print_success "Emulator ready"
            break
        fi
    done

    if [ -z "$DEVICES" ]; then
        echo ""
        print_error "Emulator failed to start"
        print_warning "Try launching emulator manually from Android Studio"
        exit 1
    fi
fi

echo ""

# If specific emulator ID provided, try to find it
if [ -n "$EMULATOR_ID" ]; then
    print_status "Looking for emulator: $EMULATOR_ID"

    DEVICE_ID=$(flutter devices --machine | grep "$EMULATOR_ID" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$DEVICE_ID" ]; then
        print_error "Emulator '$EMULATOR_ID' not found"
        echo ""
        print_status "Available Android devices:"
        flutter devices | grep "android"
        exit 1
    fi

    print_success "Found emulator: $EMULATOR_ID ($DEVICE_ID)"
    echo ""

    # Run on specific device
    print_status "Launching app on $EMULATOR_ID..."
    flutter run -d "$DEVICE_ID"
else
    # Run on first available Android device
    print_status "Launching app on first available Android device..."
    flutter run
fi

print_success "App launched successfully"
