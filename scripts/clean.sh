#!/bin/bash

# VRON Mobile - Clean Build Script
# Removes all build artifacts and caches

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

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Print header
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                VRON Mobile - Clean Build                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_warning "This will remove all build artifacts and caches"
read -p "Continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Clean cancelled"
    exit 0
fi

echo ""

# 1. Flutter clean
print_status "Running flutter clean..."
flutter clean
print_success "Flutter build artifacts removed"
echo ""

# 2. Remove .dart_tool
print_status "Removing .dart_tool cache..."
rm -rf .dart_tool
print_success ".dart_tool cache removed"
echo ""

# 3. Remove generated files
print_status "Removing generated files..."
find . -name "*.g.dart" -type f -delete
find . -name "*.freezed.dart" -type f -delete
find . -name "*.mocks.dart" -type f -delete
print_success "Generated files removed"
echo ""

# 4. Clean iOS build
if [ -d "ios" ]; then
    print_status "Cleaning iOS build..."
    cd ios
    rm -rf build
    rm -rf Pods
    rm -f Podfile.lock
    cd ..
    print_success "iOS build artifacts removed"
    echo ""
fi

# 5. Clean Android build
if [ -d "android" ]; then
    print_status "Cleaning Android build..."
    cd android
    ./gradlew clean > /dev/null 2>&1 || true
    rm -rf .gradle
    rm -rf build
    cd ..
    print_success "Android build artifacts removed"
    echo ""
fi

# 6. Remove coverage
if [ -d "coverage" ]; then
    print_status "Removing coverage reports..."
    rm -rf coverage
    print_success "Coverage reports removed"
    echo ""
fi

# 7. Clean packages
print_status "Cleaning packages..."
cd packages/vron_graphql_client
flutter clean > /dev/null 2>&1
cd ../..
print_success "Package artifacts removed"
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                     Clean Summary                              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo -e "${GREEN}✓ Flutter build artifacts${NC}"
echo -e "${GREEN}✓ Dart tool cache${NC}"
echo -e "${GREEN}✓ Generated files${NC}"
echo -e "${GREEN}✓ iOS build artifacts${NC}"
echo -e "${GREEN}✓ Android build artifacts${NC}"
echo -e "${GREEN}✓ Coverage reports${NC}"
echo -e "${GREEN}✓ Package artifacts${NC}"
echo ""
print_success "Clean complete!"
echo ""
echo "Next steps:"
echo "  1. flutter pub get                           # Restore dependencies"
echo "  2. dart run build_runner build              # Regenerate code"
echo "  3. flutter run                               # Launch app"
