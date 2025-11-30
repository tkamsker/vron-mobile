#!/bin/bash

# VRON Mobile - Code Analysis Script
# Runs Flutter analyzer with detailed output

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

# Print header
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              VRON Mobile - Code Analysis                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Run analyzer
print_status "Running Flutter analyzer..."
echo ""

if flutter analyze; then
    echo ""
    print_success "Analysis complete - No issues found!"
    exit 0
else
    echo ""
    print_error "Analysis found issues"
    echo ""
    echo "Fix the issues above and run again"
    exit 1
fi
