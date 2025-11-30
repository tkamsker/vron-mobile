#!/bin/bash

# VRON Mobile - Initial Setup Script
# Sets up development environment for first-time contributors

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
echo -e "${BLUE}║            VRON Mobile - Development Setup                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Check Flutter installation
print_status "Checking Flutter installation..."
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed"
    echo "Install Flutter from: https://docs.flutter.dev/get-started/install"
    exit 1
fi

FLUTTER_VERSION=$(flutter --version | head -1)
print_success "Flutter found: $FLUTTER_VERSION"
echo ""

# 2. Run Flutter doctor
print_status "Running Flutter doctor..."
flutter doctor -v
echo ""

read -p "Does flutter doctor show any critical issues? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Fix critical issues before continuing"
    exit 1
fi
echo ""

# 3. Create .env file if it doesn't exist
print_status "Setting up environment configuration..."
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_success "Created .env from .env.example"
        print_warning "Edit .env with your API endpoints"
    else
        print_error ".env.example not found"
    fi
else
    print_success ".env already exists"
fi
echo ""

# 4. Install dependencies
print_status "Installing Flutter dependencies..."
flutter pub get
print_success "Dependencies installed"
echo ""

# 5. Install package dependencies
print_status "Installing vron_graphql_client dependencies..."
cd packages/vron_graphql_client
flutter pub get
cd ../..
print_success "Package dependencies installed"
echo ""

# 6. Generate code
print_status "Generating code (this may take a minute)..."
dart run build_runner build --delete-conflicting-outputs
print_success "Code generation complete"
echo ""

# 7. Run analyzer
print_status "Running analyzer check..."
if flutter analyze; then
    print_success "Analyzer passed"
else
    print_warning "Analyzer found issues (non-critical)"
fi
echo ""

# 8. Run tests
print_status "Running tests..."
if flutter test; then
    print_success "All tests passed"
else
    print_error "Some tests failed"
fi
echo ""

# 9. Install lcov (optional, for coverage reports)
print_status "Checking for lcov (coverage reports)..."
if command -v lcov &> /dev/null; then
    print_success "lcov is installed"
else
    print_warning "lcov not found"
    echo "Install lcov for coverage reports:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  brew install lcov"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "  sudo apt-get install lcov"
    fi
fi
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Setup Complete!                             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Your development environment is ready!"
echo ""
echo "Quick start commands:"
echo ""
echo "  ${GREEN}./scripts/run_ios.sh${NC}              # Launch on iOS simulator"
echo "  ${GREEN}./scripts/run_android.sh${NC}          # Launch on Android emulator"
echo "  ${GREEN}./scripts/test.sh${NC}                 # Run comprehensive tests"
echo "  ${GREEN}./scripts/analyze.sh${NC}              # Run code analyzer"
echo "  ${GREEN}./scripts/clean.sh${NC}                # Clean build artifacts"
echo ""
echo "Documentation:"
echo "  ${BLUE}TESTING.md${NC}                     # Complete testing guide"
echo ""
print_success "Happy coding! 🚀"
