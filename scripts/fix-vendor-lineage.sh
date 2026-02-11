#!/bin/bash
#
# Fix vendor/lineage issues in PixelOS builds
# Removes or fixes vendor/lineage directory that shouldn't exist
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

VENDOR_LINEAGE="vendor/lineage"

if [[ -d "$VENDOR_LINEAGE" ]]; then
    print_warn "Found vendor/lineage directory (shouldn't exist in PixelOS build)"
    
    # Check if it's a git repo
    if [[ -d "$VENDOR_LINEAGE/.git" ]]; then
        print_info "vendor/lineage is a git repository"
        print_info "Removing vendor/lineage directory..."
        rm -rf "$VENDOR_LINEAGE"
        print_success "Removed vendor/lineage"
    else
        # Check if it's just the build/soong directory causing issues
        if [[ -f "$VENDOR_LINEAGE/build/soong/Android.bp" ]]; then
            print_info "Found problematic Android.bp file"
            print_info "Removing vendor/lineage/build directory..."
            rm -rf "$VENDOR_LINEAGE/build"
            print_success "Removed vendor/lineage/build"
            
            # If vendor/lineage is now empty, remove it
            if [[ -z "$(ls -A $VENDOR_LINEAGE 2>/dev/null)" ]]; then
                print_info "vendor/lineage is now empty, removing..."
                rmdir "$VENDOR_LINEAGE"
                print_success "Removed empty vendor/lineage directory"
            fi
        else
            print_warn "vendor/lineage exists but structure is unexpected"
            print_info "Removing entire vendor/lineage directory..."
            rm -rf "$VENDOR_LINEAGE"
            print_success "Removed vendor/lineage"
        fi
    fi
else
    print_info "vendor/lineage directory not found (good!)"
fi

# Check for any references to vendor/lineage in local_manifests
if [[ -d ".repo/local_manifests" ]]; then
    print_info "Checking local manifests for vendor/lineage references..."
    if grep -r "vendor/lineage" .repo/local_manifests/ 2>/dev/null; then
        print_warn "Found vendor/lineage references in local manifests!"
        print_warn "You may need to remove these entries"
    else
        print_info "No vendor/lineage references in local manifests"
    fi
fi

print_success "=========================================="
print_success "Fix complete!"
print_success "=========================================="
echo ""
print_info "You can now try building again:"
echo "  m pixelos_fb"
echo ""
