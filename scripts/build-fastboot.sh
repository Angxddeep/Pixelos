#!/bin/bash
#
# Quick script to build fastboot ROM for xaga
# Handles lunch/breakfast setup automatically
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if we're in the right directory
if [[ ! -d "build" ]] || [[ ! -d "vendor/custom" ]]; then
    print_error "Run this script from the PixelOS source root (~/pixelos)"
    exit 1
fi

print_info "Setting up build environment..."

# Source build environment
source build/envsetup.sh

# Try breakfast first
print_info "Trying breakfast xaga..."
if breakfast xaga 2>&1 | tee /tmp/breakfast.log; then
    print_success "breakfast xaga succeeded!"
elif grep -q "custom_xaga" /tmp/breakfast.log; then
    print_warn "breakfast failed, trying lunch lineage_xaga-userdebug..."
    if lunch lineage_xaga-userdebug; then
        print_success "lunch lineage_xaga-userdebug succeeded!"
        print_warn "Note: Using lineage product, but building PixelOS ROM"
    else
        print_error "Both breakfast and lunch failed!"
        print_error "Check the errors above"
        exit 1
    fi
else
    print_error "breakfast failed with unexpected error"
    cat /tmp/breakfast.log
    exit 1
fi

# Build fastboot ROM
print_info "Building fastboot ROM (NO recovery ROM)..."
if m pixelos_fb; then
    print_success "Fastboot ROM build complete!"
    print_info "Output: out/target/product/xaga/*.zip"
else
    print_error "Build failed!"
    exit 1
fi
