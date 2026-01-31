#!/bin/bash
#
# PixelOS Build Script for Xaga (MT6895)
# Uses xiaomi-mt6895-devs trees + MIUI Camera from XagaForge
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# =============================================================================
# Configuration
# =============================================================================

# Device
DEVICE_CODENAME="xaga"
DEVICE_MANUFACTURER="xiaomi"

# ROM
ROM_NAME="PixelOS"
ROM_MANIFEST="https://github.com/PixelOS-AOSP/android_manifest.git"
ROM_BRANCH="${ROM_BRANCH:-sixteen-qpr1}"

# Build
BUILD_TYPE="${BUILD_TYPE:-userdebug}"
BUILD_DIR="${BUILD_DIR:-$HOME/pixelos}"
JOBS="${JOBS:-$(nproc --all)}"

# Source repositories - xiaomi-mt6895-devs (lineage-23.1 branch)
DEVICE_TREE_BRANCH="lineage-23.1"

# =============================================================================
# Functions
# =============================================================================

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Build PixelOS for Xaga (POCO X4 GT / Redmi K50i / Redmi Note 11T Pro+)

Options:
  --sync-only       Only sync sources, don't build
  --build-only      Only build (assumes sources already synced)
  --clean           Clean build (removes out/)
  --user            Build user variant (release)
  --userdebug       Build userdebug variant (default)
  --jobs=N          Number of parallel jobs (default: all cores)
  --dir=PATH        Build directory (default: ~/pixelos)
  -h, --help        Show this help

Examples:
  # Full build
  $(basename "$0")

  # Sync only (for testing)
  $(basename "$0") --sync-only

  # Clean user build
  $(basename "$0") --clean --user

EOF
}

SYNC_ONLY=false
BUILD_ONLY=false
CLEAN_BUILD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --sync-only) SYNC_ONLY=true ;;
        --build-only) BUILD_ONLY=true ;;
        --clean) CLEAN_BUILD=true ;;
        --user) BUILD_TYPE="user" ;;
        --userdebug) BUILD_TYPE="userdebug" ;;
        --jobs=*) JOBS="${1#*=}" ;;
        --dir=*) BUILD_DIR="${1#*=}" ;;
        -h|--help) show_help; exit 0 ;;
        *) print_error "Unknown option: $1"; show_help; exit 1 ;;
    esac
    shift
done

# =============================================================================
# Build Info
# =============================================================================

echo ""
print_info "=========================================="
print_info "🚀 PixelOS Build for Xaga"
print_info "=========================================="
print_info "ROM:           $ROM_NAME ($ROM_BRANCH)"
print_info "Device:        $DEVICE_CODENAME"
print_info "Build Type:    $BUILD_TYPE"
print_info "Build Dir:     $BUILD_DIR"
print_info "Jobs:          $JOBS"
print_info "Device Trees:  xiaomi-mt6895-devs ($DEVICE_TREE_BRANCH)"
print_info "MIUI Camera:   XagaForge"
print_info "=========================================="
echo ""

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# =============================================================================
# Step 1: Initialize & Sync ROM
# =============================================================================

if [[ "$BUILD_ONLY" != "true" ]]; then
    print_step "1/6 - Initializing PixelOS manifest..."
    
    if [[ ! -d ".repo" ]]; then
        repo init -u "$ROM_MANIFEST" -b "$ROM_BRANCH" --git-lfs --depth=1
    else
        print_info "Repo already initialized, skipping..."
    fi

    print_step "2/6 - Syncing ROM source (this takes a while)..."
    repo sync -c --no-tags --no-clone-bundle --optimized-fetch --prune --force-sync -j"$JOBS" || \
    repo sync -c --no-tags --no-clone-bundle --optimized-fetch --prune --force-sync -j4

    # =============================================================================
    # Step 2: Clone Device Trees from xiaomi-mt6895-devs
    # =============================================================================

    print_step "3/6 - Cloning device trees from xiaomi-mt6895-devs..."

    # Device tree - xaga
    if [[ -d "device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME" ]]; then
        print_info "Updating device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME..."
        cd "device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME"
        git fetch origin && git reset --hard origin/$DEVICE_TREE_BRANCH
        cd "$BUILD_DIR"
    else
        git clone --depth=1 -b "$DEVICE_TREE_BRANCH" \
            https://github.com/xiaomi-mt6895-devs/android_device_xiaomi_xaga.git \
            device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME
    fi

    # Device tree - mt6895-common
    if [[ -d "device/$DEVICE_MANUFACTURER/mt6895-common" ]]; then
        print_info "Updating device/$DEVICE_MANUFACTURER/mt6895-common..."
        cd "device/$DEVICE_MANUFACTURER/mt6895-common"
        git fetch origin && git reset --hard origin/$DEVICE_TREE_BRANCH
        cd "$BUILD_DIR"
    else
        git clone --depth=1 -b "$DEVICE_TREE_BRANCH" \
            https://github.com/xiaomi-mt6895-devs/android_device_xiaomi_mt6895-common.git \
            device/$DEVICE_MANUFACTURER/mt6895-common
    fi

    # Vendor - mt6895-common
    if [[ -d "vendor/$DEVICE_MANUFACTURER/mt6895-common" ]]; then
        print_info "Updating vendor/$DEVICE_MANUFACTURER/mt6895-common..."
        cd "vendor/$DEVICE_MANUFACTURER/mt6895-common"
        git fetch origin && git reset --hard origin/$DEVICE_TREE_BRANCH
        cd "$BUILD_DIR"
    else
        git clone --depth=1 -b "$DEVICE_TREE_BRANCH" \
            https://github.com/xiaomi-mt6895-devs/proprietary_vendor_xiaomi_mt6895-common.git \
            vendor/$DEVICE_MANUFACTURER/mt6895-common
    fi

    # Vendor - xaga (device-specific blobs from GitLab)
    if [[ -d "vendor/$DEVICE_MANUFACTURER/$DEVICE_CODENAME" ]]; then
        print_info "Updating vendor/$DEVICE_MANUFACTURER/$DEVICE_CODENAME..."
        cd "vendor/$DEVICE_MANUFACTURER/$DEVICE_CODENAME"
        git fetch origin && git reset --hard origin/$DEVICE_TREE_BRANCH
        cd "$BUILD_DIR"
    else
        git clone --depth=1 -b "$DEVICE_TREE_BRANCH" \
            https://gitlab.com/ItsVixano-dev/Android/xiaomi-mt6895-devs/proprietary_vendor_xiaomi_xaga.git \
            vendor/$DEVICE_MANUFACTURER/$DEVICE_CODENAME
    fi

    # Kernel
    if [[ -d "kernel/$DEVICE_MANUFACTURER/mt6895" ]]; then
        print_info "Updating kernel..."
        cd "kernel/$DEVICE_MANUFACTURER/mt6895"
        git fetch origin && git reset --hard origin/$DEVICE_TREE_BRANCH
        cd "$BUILD_DIR"
    else
        git clone --depth=1 -b "$DEVICE_TREE_BRANCH" \
            https://github.com/xiaomi-mt6895-devs/android_kernel_xiaomi_mt6895.git \
            kernel/$DEVICE_MANUFACTURER/mt6895
    fi

    # MediaTek SEPolicy
    rm -rf device/mediatek/sepolicy_vndr 2>/dev/null || true
    git clone --depth=1 -b "$DEVICE_TREE_BRANCH" \
        https://github.com/xiaomi-mt6895-devs/android_device_mediatek_sepolicy-vndr.git \
        device/mediatek/sepolicy_vndr

    # MediaTek Hardware
    rm -rf hardware/mediatek 2>/dev/null || true
    git clone --depth=1 -b "$DEVICE_TREE_BRANCH" \
        https://github.com/xiaomi-mt6895-devs/android_hardware_mediatek.git \
        hardware/mediatek

    # Xiaomi Hardware (required by vendor blobs) - from XagaForge
    rm -rf hardware/xiaomi 2>/dev/null || true
    git clone --depth=1 \
        https://github.com/XagaForge/android_hardware_xiaomi.git \
        hardware/xiaomi

    # LineageOS Hardware Interfaces (required for livedisplay HAL)
    # The device tree depends on LineageOS-specific interfaces
    if [[ ! -d "hardware/lineage/interfaces" ]]; then
        print_info "Cloning LineageOS hardware interfaces..."
        mkdir -p hardware/lineage
        git clone --depth=1 -b lineage-22.1 \
            https://github.com/AresOS-UDC/android_hardware_lineage_interfaces.git \
            hardware/lineage/interfaces
    fi

    # =============================================================================
    # Step 3: Clone MIUI Camera from XagaForge
    # =============================================================================

    print_step "4/6 - Cloning MIUI Camera from XagaForge..."

    # MIUI Camera (16.1 branch for sixteen-qpr1)
    rm -rf vendor/$DEVICE_MANUFACTURER/miuicamera-xaga 2>/dev/null || true
    git clone --depth=1 -b 16.1 \
        https://gitlab.com/priiii1808/proprietary_vendor_xiaomi_miuicamera-xaga.git \
        vendor/$DEVICE_MANUFACTURER/miuicamera-xaga

    # =============================================================================
    # Step 4: Apply Required Patches
    # =============================================================================

    print_step "5/6 - Applying wpa_supplicant_8 patches..."

    cd external/wpa_supplicant_8

    # First, clean up any previous failed patch attempts
    print_info "Cleaning up any previous patch state..."
    git checkout -- . 2>/dev/null || true
    git cherry-pick --abort 2>/dev/null || true
    git reset --hard HEAD 2>/dev/null || true

    # Patch 1: MediaTek changes for wpa_supplicant_8
    print_info "Applying MediaTek wpa_supplicant_8 patch..."
    if git fetch --depth=1 https://github.com/Nothing-2A/android_external_wpa_supplicant_8 39200b6c7b1f9ff1c1c6a6a5e4cd08c6f526d048 2>/dev/null; then
        if ! git cherry-pick 39200b6c7b1f9ff1c1c6a6a5e4cd08c6f526d048 2>/dev/null; then
            print_warn "Patch 1 failed to apply cleanly, skipping..."
            git cherry-pick --abort 2>/dev/null || true
            git checkout -- . 2>/dev/null || true
        else
            print_success "Patch 1 applied successfully!"
        fi
    else
        print_warn "Could not fetch patch 1, skipping..."
    fi

    # Patch 2: Enable WAPI for wpa_supplicant_8
    print_info "Applying WAPI enablement patch..."
    if git fetch --depth=1 https://github.com/Nothing-2A/android_external_wpa_supplicant_8 37a6e255d9d68fb483d12db550028749b280509b 2>/dev/null; then
        if ! git cherry-pick 37a6e255d9d68fb483d12db550028749b280509b 2>/dev/null; then
            print_warn "Patch 2 failed to apply cleanly, skipping..."
            git cherry-pick --abort 2>/dev/null || true
            git checkout -- . 2>/dev/null || true
        else
            print_success "Patch 2 applied successfully!"
        fi
    else
        print_warn "Could not fetch patch 2, skipping..."
    fi

    cd "$BUILD_DIR"

    # =============================================================================
    # Step 5: Create PixelOS Product Makefile
    # =============================================================================

    print_step "5.5/6 - Creating PixelOS product makefile..."

    # The xiaomi-mt6895-devs device tree is for LineageOS (lineage_xaga.mk)
    # We need to create an aosp_xaga.mk for PixelOS
    cat > device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk << 'EOFMK'
#
# Copyright (C) 2023 The LineageOS Project
# Copyright (C) 2024-2026 PixelOS
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from xaga device
$(call inherit-product, device/xiaomi/xaga/device.mk)

# Inherit some common PixelOS stuff.
$(call inherit-product, vendor/custom/config/common_full_phone.mk)

PRODUCT_BRAND := POCO
PRODUCT_DEVICE := xaga
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_MODEL := 22041216G
PRODUCT_NAME := custom_xaga
PRODUCT_SYSTEM_NAME := xaga_global

PRODUCT_GMS_CLIENTID_BASE := android-xiaomi

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="xaga_global-user 14 UP1A.231005.007 OS2.0.3.0.ULOMIXM release-keys" \
    BuildFingerprint=POCO/xaga_global/xaga:14/UP1A.231005.007/OS2.0.3.0.ULOMIXM:user/release-keys \
    DeviceProduct=$(PRODUCT_SYSTEM_NAME)
EOFMK

    # Also need to add custom_xaga to AndroidProducts.mk if not present
    ANDROID_PRODUCTS="device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/AndroidProducts.mk"
    if ! grep -q "custom_xaga" "$ANDROID_PRODUCTS" 2>/dev/null; then
        print_info "Adding custom_xaga to AndroidProducts.mk..."
        # Check if file exists and what format it uses
        if [[ -f "$ANDROID_PRODUCTS" ]]; then
            # Append custom_xaga.mk to PRODUCT_MAKEFILES
            sed -i '/PRODUCT_MAKEFILES/a\    $(LOCAL_DIR)/custom_xaga.mk \\' "$ANDROID_PRODUCTS"
        else
            # Create new AndroidProducts.mk
            cat > "$ANDROID_PRODUCTS" << 'EOFAP'
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/custom_xaga.mk \
    $(LOCAL_DIR)/lineage_xaga.mk

COMMON_LUNCH_CHOICES := \
    custom_xaga-userdebug \
    custom_xaga-user \
    lineage_xaga-userdebug
EOFAP
        fi
    fi

    # =============================================================================
    # Step 6: Clean up broken symlinks (Qualcomm repos not needed for MediaTek)
    # =============================================================================

    print_info "Removing broken Qualcomm hardware symlinks (not needed for MediaTek)..."
    rm -rf hardware/qcom/sdm845 2>/dev/null || true
    rm -rf hardware/qcom/sm7250 2>/dev/null || true
    rm -rf hardware/qcom/sm8150 2>/dev/null || true
    rm -rf hardware/qcom/sm8250 2>/dev/null || true
    rm -rf hardware/qcom/sm8350 2>/dev/null || true

    # Remove incompatible livedisplay HIDL services (they expect @2.0 but repo has AIDL V2)
    # LiveDisplay is not essential - display works fine without it
    print_info "Removing incompatible livedisplay HIDL services..."
    rm -rf hardware/lineage/livedisplay/sdm 2>/dev/null || true
    rm -rf hardware/lineage/livedisplay/sysfs 2>/dev/null || true

    # =============================================================================
    # Step 7: Fix livedisplay module naming in frameworks/base
    # =============================================================================
    # The LineageOS 23.1 hardware/lineage/interfaces uses AIDL (vendor.lineage.livedisplay-V2-java)
    # but PixelOS frameworks/base still references old HIDL names (V2.0-java, V2.1-java)
    
    print_info "Fixing livedisplay module dependencies in frameworks/base..."
    if [[ -f "frameworks/base/Android.bp" ]]; then
        # Replace old HIDL naming with new AIDL naming
        sed -i 's/vendor\.lineage\.livedisplay-V2\.0-java/vendor.lineage.livedisplay-V2-java/g' frameworks/base/Android.bp
        sed -i 's/vendor\.lineage\.livedisplay-V2\.1-java/vendor.lineage.livedisplay-V2-java/g' frameworks/base/Android.bp
        print_success "Livedisplay dependencies fixed!"
    else
        print_warn "frameworks/base/Android.bp not found, skipping livedisplay fix"
    fi

    print_success "Sources ready!"
fi

# Exit if sync only
if [[ "$SYNC_ONLY" == "true" ]]; then
    print_success "Sync complete! Run without --sync-only to build."
    exit 0
fi

# =============================================================================
# Step 5: Build ROM
# =============================================================================

print_step "6/6 - Building PixelOS..."

# =============================================================================
# Fix livedisplay module dependencies (always runs, even with --build-only)
# =============================================================================
# Problem: PixelOS frameworks/base references livedisplay modules, but:
# - Old HIDL names (V2.0-java, V2.1-java) don't exist
# - New AIDL (V2-java) is unfrozen and incompatible with frozen framework-internal-utils
# Solution: Remove livedisplay dependencies entirely (not essential for device function)

print_info "Removing livedisplay dependencies from frameworks/base..."
if [[ -f "frameworks/base/Android.bp" ]]; then
    # Remove any livedisplay-related static_libs entries
    # This handles V2.0, V2.1, V2, V1 etc
    if grep -q "vendor\.lineage\.livedisplay" frameworks/base/Android.bp 2>/dev/null; then
        sed -i '/vendor\.lineage\.livedisplay/d' frameworks/base/Android.bp
        print_success "Livedisplay dependencies removed from frameworks/base!"
    else
        print_info "No livedisplay dependencies found in frameworks/base"
    fi
else
    print_warn "frameworks/base/Android.bp not found"
fi

# =============================================================================
# Remove incompatible modules for MediaTek builds
# =============================================================================

# Remove Qualcomm vibrator (not needed for MediaTek, has missing dependencies)
if [[ -d "vendor/qcom/opensource/vibrator" ]]; then
    print_info "Removing Qualcomm vibrator (not needed for MediaTek)..."
    rm -rf vendor/qcom/opensource/vibrator
fi

# Remove incompatible livedisplay HIDL implementations (they use @2.0 but we have AIDL)
print_info "Removing incompatible livedisplay HIDL services..."
rm -rf hardware/lineage/livedisplay/legacymm 2>/dev/null || true
rm -rf hardware/lineage/livedisplay/sdm 2>/dev/null || true
rm -rf hardware/lineage/livedisplay/sysfs 2>/dev/null || true

# =============================================================================
# Remove ParanoidSense (conflicts with Xiaomi's megvii library)
# =============================================================================
if [[ -d "packages/apps/ParanoidSense" ]]; then
    print_info "Removing ParanoidSense (conflicts with Xiaomi megvii)..."
    rm -rf packages/apps/ParanoidSense
fi

# Remove ParanoidSense from PixelOS common config
if grep -q "ParanoidSense" vendor/custom/config/common.mk 2>/dev/null; then
    print_info "Removing ParanoidSense from PRODUCT_PACKAGES..."
    sed -i '/ParanoidSense/d' vendor/custom/config/common.mk
fi

# Remove ParanoidSense biometrics dependency from frameworks/base
if grep -q "vendor.aospa.biometrics.face" frameworks/base/services/core/Android.bp 2>/dev/null; then
    print_info "Removing ParanoidSense biometrics from frameworks/base..."
    sed -i '/vendor\.aospa\.biometrics\.face/d' frameworks/base/services/core/Android.bp
fi

# =============================================================================
# Remove Qualcomm vibrator references from device tree (wrong for MediaTek)
# =============================================================================
print_info "Removing Qualcomm vibrator references from device tree..."
sed -i '/vendor.qti.hardware.vibrator/d' device/$DEVICE_MANUFACTURER/mt6895-common/mt6895.mk 2>/dev/null || true
sed -i '/excluded-input-devices.xml/d' device/$DEVICE_MANUFACTURER/mt6895-common/mt6895.mk 2>/dev/null || true
sed -i '/vendor.qti.hardware.vibrator/d' device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk 2>/dev/null || true

# Clean if requested
if [[ "$CLEAN_BUILD" == "true" ]]; then
    print_info "Cleaning out/ directory..."
    rm -rf out/
fi

# =============================================================================
# Create PixelOS Product Makefile (always runs, even with --build-only)
# =============================================================================

print_info "Ensuring PixelOS product makefile exists..."

# The xiaomi-mt6895-devs device tree is for LineageOS (lineage_xaga.mk)
# We need to create an aosp_xaga.mk for PixelOS
if [[ ! -f "device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk" ]]; then
    print_info "Creating custom_xaga.mk..."
    cat > device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk << 'EOFMK'
#
# Copyright (C) 2023 The LineageOS Project
# Copyright (C) 2024-2026 PixelOS
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from xaga device
$(call inherit-product, device/xiaomi/xaga/device.mk)

# Inherit some common PixelOS stuff.
$(call inherit-product, vendor/custom/config/common_full_phone.mk)

PRODUCT_BRAND := POCO
PRODUCT_DEVICE := xaga
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_MODEL := 22041216G
PRODUCT_NAME := custom_xaga
PRODUCT_SYSTEM_NAME := xaga_global

PRODUCT_GMS_CLIENTID_BASE := android-xiaomi

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="xaga_global-user 14 UP1A.231005.007 OS2.0.3.0.ULOMIXM release-keys" \
    BuildFingerprint=POCO/xaga_global/xaga:14/UP1A.231005.007/OS2.0.3.0.ULOMIXM:user/release-keys \
    DeviceProduct=$(PRODUCT_SYSTEM_NAME)
EOFMK
fi

# Update AndroidProducts.mk to include custom_xaga
ANDROID_PRODUCTS="device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/AndroidProducts.mk"
if ! grep -q "custom_xaga" "$ANDROID_PRODUCTS" 2>/dev/null; then
    print_info "Updating AndroidProducts.mk..."
    if [[ -f "$ANDROID_PRODUCTS" ]]; then
        # Add custom_xaga.mk to PRODUCT_MAKEFILES and COMMON_LUNCH_CHOICES
        cp "$ANDROID_PRODUCTS" "${ANDROID_PRODUCTS}.bak"
        cat > "$ANDROID_PRODUCTS" << 'EOFAP'
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/custom_xaga.mk \
    $(LOCAL_DIR)/lineage_xaga.mk

COMMON_LUNCH_CHOICES := \
    custom_xaga-userdebug \
    custom_xaga-user \
    custom_xaga-eng \
    lineage_xaga-userdebug \
    lineage_xaga-user \
    lineage_xaga-eng
EOFAP
    fi
fi

print_success "Product makefile ready!"

# Setup ccache
export USE_CCACHE=1
export CCACHE_EXEC=$(which ccache)

# Source build environment
source build/envsetup.sh

# Setup device with breakfast (new PixelOS sixteen-qpr1 method)
# This replaces the old lunch command
print_info "Setting up device with breakfast..."
breakfast ${DEVICE_CODENAME}

print_info "Starting compilation with $JOBS jobs..."
START_TIME=$(date +%s)

# Build using new PixelOS command (replaces mka bacon)
m pixelos -j"$JOBS" 2>&1 | tee build.log


END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
HOURS=$((DURATION / 3600))
MINUTES=$(((DURATION % 3600) / 60))

# =============================================================================
# Done
# =============================================================================

echo ""
print_success "=========================================="
print_success "Build completed in ${HOURS}h ${MINUTES}m!"
print_success "=========================================="
echo ""

# Find output
OUTPUT_DIR="out/target/product/$DEVICE_CODENAME"
if [[ -d "$OUTPUT_DIR" ]]; then
    print_info "Output files in: $BUILD_DIR/$OUTPUT_DIR"
    ls -lh "$OUTPUT_DIR"/*.zip 2>/dev/null || print_warn "No zip files found"
    ls -lh "$OUTPUT_DIR"/*.img 2>/dev/null || true
fi

print_info "Build log: $BUILD_DIR/build.log"
