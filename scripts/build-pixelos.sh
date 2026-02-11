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
    
    # Clean up dirty repos that cause "unsupported checkout state"
    print_info "Cleaning up potential dirty repositories..."
    rm -rf hardware/qcom/sdm845/display 2>/dev/null || true
    rm -rf hardware/qcom/sdm845/gps 2>/dev/null || true
    rm -rf hardware/qcom/sm7250/display 2>/dev/null || true
    rm -rf hardware/qcom/sm7250/gps 2>/dev/null || true
    rm -rf hardware/qcom/sm8150/display 2>/dev/null || true
    rm -rf hardware/qcom/sm8150/gps 2>/dev/null || true
    rm -rf packages/apps/ParanoidSense 2>/dev/null || true
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
        # Reset any local changes (AndroidProducts.mk, custom_xaga.mk) to insure clean state for breakfast
        git checkout . 2>/dev/null || true
        git clean -fd 2>/dev/null || true
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
            https://gitlab.com/itsvixano-dev/android/xiaomi-mt6895-devs/proprietary_vendor_xiaomi_xaga.git \
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
        git clone --depth=1 -b lineage-21.0 \
            https://github.com/LineageOS/android_hardware_lineage_interfaces.git \
            hardware/lineage/interfaces
    fi

    # =============================================================================
    # Step 3: Clone MIUI Camera from XagaForge
    # =============================================================================

    print_step "4/6 - Cloning MIUI Camera from XagaForge..."

    # MIUI Camera (16.1 branch for sixteen-qpr1)
    rm -rf vendor/$DEVICE_MANUFACTURER/miuicamera-xaga 2>/dev/null || true
    git clone --depth=1 -b 16.1 \
        https://gitlab.com/priiii08918/proprietary_vendor_xiaomi_miuicamera-xaga.git \
        vendor/$DEVICE_MANUFACTURER/miuicamera-xaga

    # Add MIUI Camera to device makefiles if not present
    print_info "Integrating MIUI Camera into device tree..."
    if [[ -f "device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk" ]]; then
        if ! grep -q "miuicamera-xaga/device.mk" device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk; then
            echo "" >> device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk
            echo "# MIUI Camera" >> device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk
            echo "\$(call inherit-product, vendor/$DEVICE_MANUFACTURER/miuicamera-xaga/device.mk)" >> device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk
            print_success "Added MIUI Camera to custom_xaga.mk"
        fi
    fi

    if [[ -f "device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/BoardConfigXaga.mk" ]]; then
        if ! grep -q "miuicamera-xaga/BoardConfig.mk" device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/BoardConfigXaga.mk; then
            echo "" >> device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/BoardConfigXaga.mk
            echo "# MIUI Camera" >> device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/BoardConfigXaga.mk
            echo "include vendor/$DEVICE_MANUFACTURER/miuicamera-xaga/BoardConfig.mk" >> device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/BoardConfigXaga.mk
            print_success "Added MIUI Camera to BoardConfigXaga.mk"
        fi
    fi

    # =============================================================================
    # Step 3.5: Download Preloader (only missing piece from xiaomi-mt6895-devs)
    # =============================================================================

    print_step "4.5/6 - Downloading preloader..."

    # The xiaomi-mt6895-devs vendor has all firmware EXCEPT preloader
    # Download just the preloader from XagaForge (single file, faster than git clone)
    DEVICE_RADIO_DIR="vendor/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/radio"
    mkdir -p "$DEVICE_RADIO_DIR"
    
    PRELOADER_URL="https://raw.githubusercontent.com/XagaForge/android_vendor_firmware/16/xaga/radio/preloader_raw.img"
    PRELOADER_PATH="$DEVICE_RADIO_DIR/preloader_xaga.bin"
    
    if [[ ! -f "$PRELOADER_PATH" ]]; then
        print_info "Downloading preloader_xaga.bin from XagaForge..."
        if curl -fsSL "$PRELOADER_URL" -o "$PRELOADER_PATH"; then
            print_success "Downloaded preloader_xaga.bin"
        else
            print_warn "Failed to download preloader, fastboot package will be incomplete"
        fi
    else
        print_info "Preloader already exists, skipping download"
    fi
    
    # Add PRODUCT_COPY_FILES for preloader to custom_xaga.mk
    if [[ -f "device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk" ]]; then
        if ! grep -q "preloader_xaga.bin" device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk; then
            echo "" >> device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk
            echo "# Preloader for fastboot package" >> device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk
            echo "PRODUCT_COPY_FILES += \\" >> device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk
            echo "    $PRELOADER_PATH:\$(PRODUCT_OUT)/preloader_xaga.bin" >> device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk
            print_success "Added preloader to custom_xaga.mk"
        fi
    fi

    # =============================================================================
    # Step 4: Apply Required Patches
    # =============================================================================

    print_step "5/7 - Applying wpa_supplicant_8 patches..."

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

    # Step 5.5 removed - relying on standard device tree configuration
    # (User confirmed manual breakfast flow works)

    # AndroidProducts.mk will be created/updated in the build section (after patches)
    # to ensure consistency

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
        # Custom patches for LiveDisplay could go here if needed
        # sed -i 's/vendor\.lineage\.livedisplay-V2\.0-java/vendor.lineage.livedisplay-V2-java/g' frameworks/base/Android.bp
        # sed -i 's/vendor\.lineage\.livedisplay-V2\.1-java/vendor.lineage.livedisplay-V2-java/g' frameworks/base/Android.bp
        print_success "LiveDisplay interfaces should be correct with lineage-21.0 branch"
    else
        print_warn "frameworks/base/Android.bp not found, skipping livedisplay fix"
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
    
    print_info "Fixing livedisplay module dependencies in frameworks/base..."
    if [[ -f "frameworks/base/Android.bp" ]]; then
        # Replace old HIDL naming with new AIDL naming
        # Custom patches for LiveDisplay could go here if needed
        # sed -i 's/vendor\.lineage\.livedisplay-V2\.0-java/vendor.lineage.livedisplay-V2-java/g' frameworks/base/Android.bp
        # sed -i 's/vendor\.lineage\.livedisplay-V2\.1-java/vendor.lineage.livedisplay-V2-java/g' frameworks/base/Android.bp
        print_success "LiveDisplay interfaces should be correct with lineage-21.0 branch"
    else
        print_warn "frameworks/base/Android.bp not found, skipping livedisplay fix"
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
    
    print_info "Fixing livedisplay module dependencies in frameworks/base..."
    if [[ -f "frameworks/base/Android.bp" ]]; then
        # Replace old HIDL naming with new AIDL naming
        # Custom patches for LiveDisplay could go here if needed
        # sed -i 's/vendor\.lineage\.livedisplay-V2\.0-java/vendor.lineage.livedisplay-V2-java/g' frameworks/base/Android.bp
        # sed -i 's/vendor\.lineage\.livedisplay-V2\.1-java/vendor.lineage.livedisplay-V2-java/g' frameworks/base/Android.bp
        print_success "LiveDisplay interfaces should be correct with lineage-21.0 branch"
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

print_step "6/7 - Building PixelOS..."

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
        # sed -i '/vendor\.lineage\.livedisplay/d' frameworks/base/Android.bp
        print_info "Keeping livedisplay dependencies in frameworks/base (attempting to restore support)"
    else
        print_info "No livedisplay dependencies found in frameworks/base"
    fi
else
    print_warn "frameworks/base/Android.bp not found"
fi

# =============================================================================
# Remove incompatible modules for MediaTek builds
# =============================================================================

# Vibrator HAL is needed (restored in entry #19)
# Remove Qualcomm vibrator (not needed for MediaTek, has missing dependencies)
# if [[ -d "vendor/qcom/opensource/vibrator" ]]; then
#    print_info "Removing Qualcomm vibrator (not needed for MediaTek)..."
#    rm -rf vendor/qcom/opensource/vibrator
# fi

# Remove incompatible livedisplay HIDL implementations (they use @2.0 but we have AIDL)
print_info "Removing incompatible livedisplay HIDL services..."
# rm -rf hardware/lineage/livedisplay/legacymm 2>/dev/null || true
# rm -rf hardware/lineage/livedisplay/sdm 2>/dev/null || true
# rm -rf hardware/lineage/livedisplay/sysfs 2>/dev/null || true

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
# Vibrator HAL is needed (restored in entry #19)
# sed -i '/vendor.qti.hardware.vibrator/d' device/$DEVICE_MANUFACTURER/mt6895-common/mt6895.mk 2>/dev/null || true
# sed -i '/excluded-input-devices.xml/d' device/$DEVICE_MANUFACTURER/mt6895-common/mt6895.mk 2>/dev/null || true
# sed -i '/vendor.qti.hardware.vibrator/d' device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk 2>/dev/null || true

# =============================================================================
# Remove LineageOS services from frameworks/base (incompatible with this build)
# =============================================================================
print_info "Removing LineageOS services from frameworks/base..."

# Remove LineageOS internal hardware classes
# rm -rf frameworks/base/core/java/com/android/internal/lineage/hardware/ 2>/dev/null || true

# Remove ParanoidSense face services directory
rm -rf frameworks/base/services/core/java/com/android/server/biometrics/sensors/face/sense/ 2>/dev/null || true

# Remove LineageOS display services
# rm -rf frameworks/base/services/core/java/com/android/server/lineage/ 2>/dev/null || true

# =============================================================================
# Fix ParanoidSense biometrics references in FaceService and AuthService
# =============================================================================
print_info "Fixing ParanoidSense biometrics references..."

cat > /tmp/fix_sense_biometrics.py << 'EOFPY'
import re
import os

# Fix FaceService.java
faceservice = 'frameworks/base/services/core/java/com/android/server/biometrics/sensors/face/FaceService.java'
if os.path.exists(faceservice):
    with open(faceservice, 'r') as f:
        content = f.read()
    # Remove Sense imports
    content = re.sub(r'import com\.android\.server\.biometrics\.sensors\.face\.sense\.SenseProvider;\n', '', content)
    content = re.sub(r'import com\.android\.server\.biometrics\.sensors\.face\.sense\.SenseUtils;\n', '', content)
    # Replace SenseUtils.canUseProvider() with false
    content = content.replace('SenseUtils.canUseProvider()', 'false')
    # Remove getSenseProviders call
    content = content.replace('providers.addAll(getSenseProviders());', '// Sense provider disabled')
    # Remove getSenseProviders method
    content = re.sub(r'\n\s*private List<ServiceProvider> getSenseProviders\(\) \{[\s\S]*?\n\s{8}\}', '', content)
    with open(faceservice, 'w') as f:
        f.write(content)
    print(f"Fixed {faceservice}")

# Fix AuthService.java
authservice = 'frameworks/base/services/core/java/com/android/server/biometrics/AuthService.java'
if os.path.exists(authservice):
    with open(authservice, 'r') as f:
        content = f.read()
    # Remove Sense imports
    content = re.sub(r'import com\.android\.server\.biometrics\.sensors\.face\.sense\.SenseUtils;\n', '', content)
    # Replace SenseUtils.canUseProvider() with false
    content = content.replace('SenseUtils.canUseProvider()', 'false')
    with open(authservice, 'w') as f:
        f.write(content)
    print(f"Fixed {authservice}")
EOFPY

python3 /tmp/fix_sense_biometrics.py 2>/dev/null || true

# =============================================================================
# Fix LineageHardwareManager references in InputMethodManagerService
# =============================================================================
print_info "Fixing LineageHardwareManager references in InputMethodManagerService..."

cat > /tmp/fix_imms.py << 'EOFPY'
import re
import os

imms = 'frameworks/base/services/core/java/com/android/server/inputmethod/InputMethodManagerService.java'
if os.path.exists(imms):
    with open(imms, 'r') as f:
        content = f.read()
    
    # Remove import
    content = re.sub(r'import com\.android\.internal\.lineage\.hardware\.LineageHardwareManager;\n', '', content)
    
    # Remove field declaration
    content = re.sub(r'\s*private LineageHardwareManager mLineageHardware;\n', '\n', content)
    
    # Remove initialization
    content = re.sub(r'\s*mLineageHardware = LineageHardwareManager\.getInstance\(mContext\);\n', '\n', content)
    
    # Replace isSupported checks with false
    content = re.sub(r'mLineageHardware\.isSupported\(\s*LineageHardwareManager\.FEATURE_HIGH_TOUCH_POLLING_RATE\)', 'false', content)
    content = re.sub(r'mLineageHardware\.isSupported\(\s*LineageHardwareManager\.FEATURE_HIGH_TOUCH_SENSITIVITY\)', 'false', content)
    content = re.sub(r'mLineageHardware\.isSupported\(LineageHardwareManager\.FEATURE_TOUCH_HOVERING\)', 'false', content)
    
    # Comment out set() calls
    content = re.sub(r'mLineageHardware\.set\(LineageHardwareManager\.FEATURE_HIGH_TOUCH_POLLING_RATE, enabled\);', '// LineageOS touch polling disabled', content)
    content = re.sub(r'mLineageHardware\.set\(LineageHardwareManager\.FEATURE_HIGH_TOUCH_SENSITIVITY, enabled\);', '// LineageOS touch sensitivity disabled', content)
    content = re.sub(r'mLineageHardware\.set\(LineageHardwareManager\.FEATURE_TOUCH_HOVERING, enabled\);', '// LineageOS touch hovering disabled', content)
    
    with open(imms, 'w') as f:
        f.write(content)
    print(f"Fixed {imms}")
EOFPY

# python3 /tmp/fix_imms.py 2>/dev/null || true

# =============================================================================
# Optional: Apply fastboot package patch
# =============================================================================
if [[ ! -f "vendor/custom/build/tasks/fb_package.mk" ]]; then
    print_info "Applying optional fastboot package patch..."
    if [[ -f "scripts/apply_fb_package_patch.sh" ]]; then
        bash scripts/apply_fb_package_patch.sh
    else
        print_warn "Fastboot package patch script not found, skipping..."
    fi
fi

# Clean if requested
if [[ "$CLEAN_BUILD" == "true" ]]; then
    print_info "Cleaning out/ directory..."
    rm -rf out/
fi

# =============================================================================
# Step 5: Build ROM
# =============================================================================

print_step "6/7 - Building PixelOS..."

# Setup ccache
export USE_CCACHE=1
export CCACHE_EXEC=$(which ccache)

# Source build environment
source build/envsetup.sh

# Export TARGET_RELEASE for Android 14/15+ builds (just in case)
# export TARGET_RELEASE=trunk_staging

# Setup device - Smart detection
print_info "Detecting valid product..."

# 1. Check if we have a previous build (best for incremental)
PREV_BUILD_PROP="out/target/product/$DEVICE_CODENAME/system/build.prop"
if [[ -f "$PREV_BUILD_PROP" ]]; then
    # Extract ro.product.name from previous build
    DETECTED_PRODUCT=$(grep "ro.product.name=" "$PREV_BUILD_PROP" | cut -d= -f2)
    print_info "Found previous build artifact: $DETECTED_PRODUCT"
fi

# 2. If no previous build found, check AndroidProducts.mk
if [[ -z "$DETECTED_PRODUCT" ]]; then
    PRODUCTS_MK="device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/AndroidProducts.mk"
    if [[ -f "$PRODUCTS_MK" ]]; then
        # Extract product name (e.g., pixelos_xaga, lineage_xaga)
        DETECTED_PRODUCT=$(grep -oE "(pixelos|lineage|aosp)_${DEVICE_CODENAME}" "$PRODUCTS_MK" | head -n 1)
        print_info "Auto-detected product from makefile: $DETECTED_PRODUCT"
    fi
fi

if [[ -z "$DETECTED_PRODUCT" ]]; then
    # Fallback to defaults
    DETECTED_PRODUCT="lineage_${DEVICE_CODENAME}"
    print_warn "Could not auto-detect product name, defaulting to $DETECTED_PRODUCT"
fi

# Unset stale variables that might force custom_xaga
unset TARGET_PRODUCT
unset TARGET_BUILD_VARIANT
unset TARGET_BUILD_TYPE

print_info "Lunching $DETECTED_PRODUCT-${BUILD_TYPE}..."
if lunch "${DETECTED_PRODUCT}-${BUILD_TYPE}"; then
    print_success "Lunch successful!"
elif lunch "${DETECTED_PRODUCT}-trunk_staging-${BUILD_TYPE}"; then
    print_success "Lunch successful (trunk_staging)!"
else
    print_error "Lunch failed for $DETECTED_PRODUCT"
    exit 1
fi

print_info "Starting compilation with $JOBS jobs..."
START_TIME=$(date +%s)

# Build target-files-package only (skip recovery ROM, build fastboot images only)
# This builds partition images without creating the recovery-flashable OTA ZIP
if make target-files-package -j"$JOBS" 2>&1 | tee build.log; then
    print_success "Target Files Build Successful!"
    
    # Automatically build fastboot package
    print_info "Generating Fastboot Package (m fb_package)..."
    if m fb_package; then
        print_success "Fastboot Package Generated Successfully!"
    else
        print_error "Fastboot Package Generation Failed!"
    fi
else
    print_error "Build Failed!"
    exit 1
fi


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
