#!/bin/bash
#
# Generate fastboot package from latest build and upload to GCS
# Usage: bash scripts/upload-build.sh
# Run from ~/pixelos after a successful 'm pixelos' build
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

BUCKET="gs://pixelos-xaga-builds"
PRODUCT_OUT="out/target/product/xaga"

# Check we're in the right directory
if [[ ! -d "$PRODUCT_OUT" ]]; then
    print_error "No build output found at $PRODUCT_OUT"
    print_error "Run this from ~/pixelos after a successful build."
    exit 1
fi

# Source build env if not already done
if ! command -v m &> /dev/null; then
    print_info "Sourcing build environment..."
    source build/envsetup.sh
    breakfast xaga
fi

# =============================================================================
# Generate fastboot package
# =============================================================================

print_info "Generating fastboot package..."
m fb_package 2>&1 | tail -5

# Find the output files
ROM_ZIP=$(ls -t $PRODUCT_OUT/PixelOS_*.zip 2>/dev/null | head -1)
FB_ZIP=$(ls -t $PRODUCT_OUT/*-FASTBOOT.zip 2>/dev/null | head -1)
BOOT_IMG="$PRODUCT_OUT/boot.img"
VENDOR_BOOT_IMG="$PRODUCT_OUT/vendor_boot.img"

echo ""
print_info "==========================================="
print_info "Build outputs:"
[[ -f "$ROM_ZIP" ]] && echo "  📦 ROM:            $(basename $ROM_ZIP) ($(du -h $ROM_ZIP | cut -f1))"
[[ -f "$FB_ZIP" ]] && echo "  ⚡ Fastboot:       $(basename $FB_ZIP) ($(du -h $FB_ZIP | cut -f1))"
[[ -f "$BOOT_IMG" ]] && echo "  🥾 boot.img:       $(du -h $BOOT_IMG | cut -f1)"
[[ -f "$VENDOR_BOOT_IMG" ]] && echo "  🥾 vendor_boot:    $(du -h $VENDOR_BOOT_IMG | cut -f1)"
print_info "==========================================="

# =============================================================================
# Upload to GCS
# =============================================================================

print_info "Uploading to $BUCKET ..."

FILES_TO_UPLOAD=()
[[ -f "$ROM_ZIP" ]] && FILES_TO_UPLOAD+=("$ROM_ZIP")
[[ -f "$FB_ZIP" ]] && FILES_TO_UPLOAD+=("$FB_ZIP")
[[ -f "$BOOT_IMG" ]] && FILES_TO_UPLOAD+=("$BOOT_IMG")
[[ -f "$VENDOR_BOOT_IMG" ]] && FILES_TO_UPLOAD+=("$VENDOR_BOOT_IMG")

if [[ ${#FILES_TO_UPLOAD[@]} -eq 0 ]]; then
    print_error "No files to upload!"
    exit 1
fi

gsutil -m cp "${FILES_TO_UPLOAD[@]}" "$BUCKET/"

echo ""
print_success "==========================================="
print_success "Upload complete!"
print_success "==========================================="
echo ""
print_info "Download from: https://console.cloud.google.com/storage/browser/pixelos-xaga-builds"
echo ""
