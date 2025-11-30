#!/bin/bash

# VRON Mobile - iOS Quick Launch Script
# Launches app on iOS simulator or physical device

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
echo -e "${BLUE}║               VRON Mobile - iOS Quick Launch                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode is not installed"
    echo "Install Xcode from the App Store"
    exit 1
fi

# Check if specific device was requested
DEVICE_NAME="$1"

# Get list of iOS devices
print_status "Checking iOS devices..."
DEVICES=$(flutter devices --machine | grep -o '"id":"ios.*"' || true)

if [ -z "$DEVICES" ]; then
    print_warning "No iOS devices or simulators found"
    print_status "Launching default iOS simulator..."

    # Open Simulator app
    open -a Simulator

    # Wait for simulator to boot
    echo -n "Waiting for simulator to boot"
    for i in {1..30}; do
        echo -n "."
        sleep 1
        DEVICES=$(flutter devices --machine | grep -o '"id":"ios.*"' || true)
        if [ -n "$DEVICES" ]; then
            echo ""
            print_success "Simulator ready"
            break
        fi
    done

    if [ -z "$DEVICES" ]; then
        echo ""
        print_error "Simulator failed to start"
        exit 1
    fi
fi

echo ""

# If specific device name provided, try to find it
if [ -n "$DEVICE_NAME" ]; then
    print_status "Looking for device: $DEVICE_NAME"

    DEVICE_ID=$(flutter devices --machine | grep "$DEVICE_NAME" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$DEVICE_ID" ]; then
        print_error "Device '$DEVICE_NAME' not found"
        echo ""
        print_status "Available iOS devices:"
        flutter devices | grep "ios"
        exit 1
    fi

    print_success "Found device: $DEVICE_NAME ($DEVICE_ID)"
    echo ""

    # Run on specific device
    print_status "Launching app on $DEVICE_NAME..."
    flutter run -d "$DEVICE_ID"
else
    # Run on first available iOS device
    print_status "Launching app on first available iOS device..."
    flutter run
fi

print_success "App launched successfully"
