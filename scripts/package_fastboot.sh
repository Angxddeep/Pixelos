#!/bin/bash
#
# fastboot_package.sh - Create a fastboot-flashable package for PixelOS
#
# Usage: bash scripts/package_fastboot.sh
#
# Requirements:
# - Must be run in the Android build environment (after 'lunch')
# - Requires 'm target-files-package' to be completed
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Configuration
# =============================================================================

# Check if variables are set
if [[ -z "$PRODUCT_OUT" ]]; then
    print_error "PRODUCT_OUT not set. Run 'lunch' first."
    exit 1
fi

if [[ -z "$HOST_OUT_EXECUTABLES" ]]; then
    print_error "HOST_OUT_EXECUTABLES not set. Run 'lunch' first."
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d-%H%M)
OUTPUT_ZIP="${PRODUCT_OUT}/PixelOS_${DEVICE_CODENAME:-xaga}_Fastboot_${TIMESTAMP}.zip"
FB_GEN_DIR="${PRODUCT_OUT}/fastboot_gen_${TIMESTAMP}"
TARGET_FILES_DIR="${PRODUCT_OUT}/obj/PACKAGING/target_files_intermediates/${TARGET_PRODUCT}-target_files"

# Fastboot tools location
# Priority: 
# 1. $REPO_ROOT/fastboot (if exists)
# 2. scripts/../fastboot relative to this script
REPO_ROOT=$(pwd)
FASTBOOT_TOOLS_DIR="${REPO_ROOT}/fastboot"

if [[ ! -d "$FASTBOOT_TOOLS_DIR" ]]; then
    print_warn "Fastboot tools not found at $FASTBOOT_TOOLS_DIR"
    # Try relative to script
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    FASTBOOT_TOOLS_DIR="$(dirname "$SCRIPT_DIR")/fastboot"
    if [[ ! -d "$FASTBOOT_TOOLS_DIR" ]]; then
        print_error "Could not find fastboot tools directory!"
        exit 1
    fi
fi

print_info "Using fastboot tools from: $FASTBOOT_TOOLS_DIR"

# Images to include
IMAGES=(
    "apusys.img" "audio_dsp.img" "boot.img" "ccu.img" "dpm.img" "dtbo.img"
    "gpueb.img" "gz.img" "lk.img" "mcf_ota.img" "mcupm.img" "md1img.img"
    "mvpu_algo.img" "pi_img.img" "scp.img" "spmfw.img" "sspm.img" "tee.img"
    "vcp.img" "vbmeta.img" "vbmeta_system.img" "vbmeta_vendor.img"
    "vendor_boot.img" "super.img" "unsparse_super_empty.img"
)

# =============================================================================
# Main Logic
# =============================================================================

print_info "Starting Fastboot Package generation..."
print_info "Output: $OUTPUT_ZIP"

# 1. Prepare Staging Directory
rm -rf "$FB_GEN_DIR"
mkdir -p "$FB_GEN_DIR/images"
mkdir -p "$FB_GEN_DIR/tools"

# 2. Check/Build super.img
if [[ ! -f "$PRODUCT_OUT/super.img" ]]; then
    print_info "super.img not found in PRODUCT_OUT, building it..."
    
    BUILD_SUPER_IMAGE="${HOST_OUT_EXECUTABLES}/build_super_image"
    if [[ ! -f "$BUILD_SUPER_IMAGE" ]]; then
        print_error "build_super_image tool not found at $BUILD_SUPER_IMAGE"
        print_error "Make sure you have built 'otatools' or a full build."
        exit 1
    fi

    if [[ ! -d "$TARGET_FILES_DIR" ]]; then
        print_error "Target files directory not found: $TARGET_FILES_DIR"
        print_error "Did you run 'm target-files-package'?"
        exit 1
    fi

    print_info "Building super.img from $TARGET_FILES_DIR..."
    "$BUILD_SUPER_IMAGE" -v "$TARGET_FILES_DIR" "$PRODUCT_OUT/super.img"
    
    if [[ $? -eq 0 ]]; then
        print_success "super.img built successfully!"
    else
        print_error "Failed to build super.img"
        exit 1
    fi
else
    print_info "Found super.img"
fi

# 3. Copy Images
print_info "Copying images..."

for img in "${IMAGES[@]}"; do
    FOUND=false
    
    # Check PRODUCT_OUT
    if [[ -f "$PRODUCT_OUT/$img" ]]; then
        cp "$PRODUCT_OUT/$img" "$FB_GEN_DIR/images/"
        print_success "  Found $img in PRODUCT_OUT"
        FOUND=true
    else
        # Check Target Files IMAGES
        if [[ -f "$TARGET_FILES_DIR/IMAGES/$img" ]]; then
            cp "$TARGET_FILES_DIR/IMAGES/$img" "$FB_GEN_DIR/images/"
            print_success "  Found $img in Target Files (IMAGES)"
            FOUND=true
        # Check Target Files RADIO
        elif [[ -f "$TARGET_FILES_DIR/RADIO/$img" ]]; then
            cp "$TARGET_FILES_DIR/RADIO/$img" "$FB_GEN_DIR/images/"
            print_success "  Found $img in Target Files (RADIO)"
            FOUND=true
        fi
    fi
    
    if [[ "$FOUND" == "false" ]]; then
        print_warn "  Could not find $img anywhere! Update might fail."
    fi
done

# 4. Handle preloader (separately as it might be named differently)
if [[ -f "$PRODUCT_OUT/preloader_xaga.bin" ]]; then
    cp "$PRODUCT_OUT/preloader_xaga.bin" "$FB_GEN_DIR/images/"
    print_success "  Found preloader_xaga.bin in PRODUCT_OUT"
elif [[ -f "$TARGET_FILES_DIR/RADIO/preloader_xaga.bin" ]]; then
    cp "$TARGET_FILES_DIR/RADIO/preloader_xaga.bin" "$FB_GEN_DIR/images/"
    print_success "  Found preloader_xaga.bin in Target Files (RADIO)"
else
    print_warn "  Could not find preloader_xaga.bin!"
fi

# 5. Copy Tools and Scripts
print_info "Copying tools and scripts..."
if [[ -d "${FASTBOOT_TOOLS_DIR}/tools" ]]; then
    cp -r "${FASTBOOT_TOOLS_DIR}/tools"/* "$FB_GEN_DIR/tools/"
else
    print_warn "tools/ directory not found in ${FASTBOOT_TOOLS_DIR}"
fi

if [[ -f "${FASTBOOT_TOOLS_DIR}/linux_installation.sh" ]]; then
    cp "${FASTBOOT_TOOLS_DIR}/linux_installation.sh" "$FB_GEN_DIR/"
    chmod +x "$FB_GEN_DIR/linux_installation.sh"
else
    print_warn "linux_installation.sh not found"
fi

if [[ -f "${FASTBOOT_TOOLS_DIR}/win_installation.bat" ]]; then
    cp "${FASTBOOT_TOOLS_DIR}/win_installation.bat" "$FB_GEN_DIR/"
else
    print_warn "win_installation.bat not found"
fi

# 6. Zip It Up
print_info "Creating ZIP package..."
cd "$FB_GEN_DIR"
zip -r "$OUTPUT_ZIP" . >/dev/null
cd "$REPO_ROOT"

# 7. Cleanup and Symlink
print_info "Cleaning up..."
rm -rf "$FB_GEN_DIR"

LATEST_LINK="${PRODUCT_OUT}/latest-fastboot.zip"
ln -sf "$(basename "$OUTPUT_ZIP")" "$LATEST_LINK"

print_success "========================================================"
print_success "Fastboot Package Created!"
print_success "Zip: $OUTPUT_ZIP"
print_success "Link: $LATEST_LINK"
print_success "========================================================"
