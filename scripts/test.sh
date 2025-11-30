#!/bin/bash

# VRON Mobile - Comprehensive Test Runner
# Runs full test suite with code analysis and coverage

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          VRON Mobile - Comprehensive Test Suite               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print status
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

# Start time
START_TIME=$(date +%s)

# 1. Clean previous build artifacts
print_status "Cleaning build artifacts..."
flutter clean > /dev/null 2>&1
print_success "Clean complete"
echo ""

# 2. Get dependencies
print_status "Getting dependencies..."
flutter pub get
print_success "Dependencies installed"
echo ""

# 3. Generate code
print_status "Generating code..."
dart run build_runner build --delete-conflicting-outputs
print_success "Code generation complete"
echo ""

# 4. Run analyzer
print_status "Running Flutter analyzer..."
if flutter analyze; then
    print_success "Analyzer passed with no issues"
else
    print_error "Analyzer found issues"
    exit 1
fi
echo ""

# 5. Run tests
print_status "Running tests..."
if flutter test; then
    print_success "All tests passed"
else
    print_error "Some tests failed"
    exit 1
fi
echo ""

# 6. Generate coverage report (if tests passed)
print_status "Generating coverage report..."
if flutter test --coverage; then
    print_success "Coverage report generated"

    # Install lcov if not already installed (macOS)
    if ! command -v lcov &> /dev/null; then
        print_warning "lcov not found. Install with: brew install lcov"
    else
        # Generate HTML coverage report
        if [ -f "coverage/lcov.info" ]; then
            genhtml coverage/lcov.info -o coverage/html > /dev/null 2>&1
            print_success "HTML coverage report generated at: coverage/html/index.html"

            # Calculate coverage percentage
            COVERAGE=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines" | awk '{print $2}')
            echo -e "${GREEN}   Coverage: $COVERAGE${NC}"
        fi
    fi
else
    print_error "Coverage generation failed"
fi
echo ""

# End time and duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Print summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      Test Summary                              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo -e "${GREEN}✓ Clean build artifacts${NC}"
echo -e "${GREEN}✓ Dependencies installed${NC}"
echo -e "${GREEN}✓ Code generated${NC}"
echo -e "${GREEN}✓ Analyzer passed${NC}"
echo -e "${GREEN}✓ All tests passed${NC}"
echo -e "${GREEN}✓ Coverage report generated${NC}"
echo ""
echo -e "${BLUE}Total duration: ${DURATION}s${NC}"
echo ""
echo -e "${GREEN}All checks passed! 🎉${NC}"
echo ""

# Optional: Open coverage report
if [ -f "coverage/html/index.html" ]; then
    read -p "Open coverage report in browser? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open coverage/html/index.html
    fi
fi
