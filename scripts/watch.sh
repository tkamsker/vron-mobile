#!/bin/bash

# VRON Mobile - Watch Mode Script
# Continuously runs tests when files change

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
echo -e "${BLUE}║            VRON Mobile - Watch Mode (Continuous Test)        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_warning "This script uses fswatch to monitor file changes"
echo ""

# Check if fswatch is installed
if ! command -v fswatch &> /dev/null; then
    print_warning "fswatch is not installed"
    echo ""
    echo "Install fswatch:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  brew install fswatch"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "  sudo apt-get install fswatch"
    fi
    echo ""
    echo "Alternative: Use IDE's built-in watch mode"
    exit 1
fi

print_success "fswatch found"
echo ""

# Function to run tests
run_tests() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S') - Running tests...${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Run analyzer first
    if flutter analyze --no-fatal-infos; then
        print_success "Analyzer passed"
        echo ""

        # Run tests
        if flutter test; then
            print_success "All tests passed"
        else
            print_warning "Some tests failed"
        fi
    else
        print_warning "Analyzer found issues"
    fi

    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Watching for changes... (Press Ctrl+C to stop)${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
}

# Run tests once at startup
run_tests

# Watch for file changes
fswatch -o \
    --exclude='.*\.g\.dart$' \
    --exclude='.*\.freezed\.dart$' \
    --exclude='.*\.mocks\.dart$' \
    --exclude='build/' \
    --exclude='.dart_tool/' \
    --exclude='coverage/' \
    lib/ test/ | while read f; do
    run_tests
done
