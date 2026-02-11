# Stage 2: Clone/update device trees, vendor, kernel, MediaTek and Lineage hardware
# Run from BUILD_DIR.

_STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -n "$REPO_ROOT" ]] || REPO_ROOT="$(cd "$_STAGE_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/lib/common.sh"

print_step "3/6 - Cloning device trees from $DEVICE_TREE_ORG..."

clone_or_update() {
    local dir="$1"
    local url="$2"
    local branch="$3"
    if [[ -d "$dir" ]]; then
        print_info "Updating $dir..."
        (cd "$dir" && git checkout . 2>/dev/null || true; git clean -fd 2>/dev/null || true; git fetch origin && git reset --hard "origin/$branch")
    else
        git clone --depth=1 -b "$branch" "$url" "$dir"
    fi
}

# Device tree - xaga (reset local changes for clean breakfast)
if [[ -d "device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME" ]]; then
    print_info "Updating device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME..."
    (cd "device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME" && git checkout . 2>/dev/null || true; git clean -fd 2>/dev/null || true; git fetch origin && git reset --hard origin/$DEVICE_TREE_BRANCH)
else
    git clone --depth=1 -b "$DEVICE_TREE_BRANCH" \
        "${GITHUB_DEVICE_BASE}/android_device_xiaomi_xaga.git" \
        "device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME"
fi

clone_or_update "device/$DEVICE_MANUFACTURER/mt6895-common" \
    "${GITHUB_DEVICE_BASE}/android_device_xiaomi_mt6895-common.git" "$DEVICE_TREE_BRANCH"
clone_or_update "vendor/$DEVICE_MANUFACTURER/mt6895-common" \
    "${GITHUB_DEVICE_BASE}/proprietary_vendor_xiaomi_mt6895-common.git" "$DEVICE_TREE_BRANCH"
clone_or_update "vendor/$DEVICE_MANUFACTURER/$DEVICE_CODENAME" \
    "$VENDOR_XAGA_GITLAB" "$DEVICE_TREE_BRANCH"
clone_or_update "kernel/$DEVICE_MANUFACTURER/mt6895" \
    "${GITHUB_DEVICE_BASE}/android_kernel_xiaomi_mt6895.git" "$DEVICE_TREE_BRANCH"

# MediaTek SEPolicy & Hardware (replace)
rm -rf device/mediatek/sepolicy_vndr 2>/dev/null || true
git clone --depth=1 -b "$DEVICE_TREE_BRANCH" \
    "${GITHUB_DEVICE_BASE}/android_device_mediatek_sepolicy-vndr.git" \
    device/mediatek/sepolicy_vndr

rm -rf hardware/mediatek 2>/dev/null || true
git clone --depth=1 -b "$DEVICE_TREE_BRANCH" \
    "${GITHUB_DEVICE_BASE}/android_hardware_mediatek.git" \
    hardware/mediatek

# Xiaomi hardware (vendor blobs)
rm -rf hardware/xiaomi 2>/dev/null || true
git clone --depth=1 "$XIAOMI_HARDWARE_REPO" hardware/xiaomi

# LineageOS hardware interfaces
if [[ ! -d "hardware/lineage/interfaces" ]]; then
    print_info "Cloning LineageOS hardware interfaces..."
    mkdir -p hardware/lineage
    git clone --depth=1 -b "$LINEAGE_INTERFACES_BRANCH" "$LINEAGE_INTERFACES_REPO" hardware/lineage/interfaces
fi
