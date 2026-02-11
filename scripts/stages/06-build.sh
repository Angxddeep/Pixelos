# Stage 6: Pre-build fixes, lunch, make target-files-package, package_fastboot
# Run from BUILD_DIR. Expects CLEAN_BUILD, BUILD_TYPE, JOBS, REPO_ROOT, BUILD_DIR, DEVICE_*.

_STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -n "$REPO_ROOT" ]] || REPO_ROOT="$(cd "$_STAGE_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/lib/common.sh"

print_step "6/7 - Building PixelOS..."

# --- Pre-build fixes (ParanoidSense, frameworks) ---
if [[ -d "packages/apps/ParanoidSense" ]]; then
    print_info "Removing ParanoidSense (conflicts with Xiaomi megvii)..."
    rm -rf packages/apps/ParanoidSense
fi
if grep -q "ParanoidSense" vendor/custom/config/common.mk 2>/dev/null; then
    print_info "Removing ParanoidSense from PRODUCT_PACKAGES..."
    sed -i '/ParanoidSense/d' vendor/custom/config/common.mk
fi
if grep -q "vendor.aospa.biometrics.face" frameworks/base/services/core/Android.bp 2>/dev/null; then
    print_info "Removing ParanoidSense biometrics from frameworks/base..."
    sed -i '/vendor\.aospa\.biometrics\.face/d' frameworks/base/services/core/Android.bp
fi
rm -rf frameworks/base/services/core/java/com/android/server/biometrics/sensors/face/sense/ 2>/dev/null || true

print_info "Fixing ParanoidSense biometrics references in FaceService/AuthService..."
if [[ -f "$REPO_ROOT/scripts/fixes/fix_sense_biometrics.py" ]]; then
    ANDROID_BUILD_TOP="$BUILD_DIR" python3 "$REPO_ROOT/scripts/fixes/fix_sense_biometrics.py" 2>/dev/null || true
fi

# Optional fastboot package makefile patch
if [[ ! -f "vendor/custom/build/tasks/fb_package.mk" ]] && [[ -f "$REPO_ROOT/scripts/apply_fb_package_patch.sh" ]]; then
    print_info "Applying optional fastboot package patch..."
    bash "$REPO_ROOT/scripts/apply_fb_package_patch.sh" 2>/dev/null || true
fi

if [[ "$CLEAN_BUILD" == "true" ]]; then
    print_info "Cleaning out/ directory..."
    rm -rf out/
fi

# --- Build ---
export USE_CCACHE=1
export CCACHE_EXEC=$(which ccache 2>/dev/null || true)
source build/envsetup.sh

DETECTED_PRODUCT=""
if [[ -f "out/target/product/$DEVICE_CODENAME/system/build.prop" ]]; then
    DETECTED_PRODUCT=$(grep "ro.product.name=" "out/target/product/$DEVICE_CODENAME/system/build.prop" | cut -d= -f2)
fi
if [[ -z "$DETECTED_PRODUCT" ]] && [[ -f "device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/AndroidProducts.mk" ]]; then
    DETECTED_PRODUCT=$(grep -oE "(pixelos|lineage|aosp|custom)_${DEVICE_CODENAME}" "device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/AndroidProducts.mk" | head -n 1)
fi
if [[ -z "$DETECTED_PRODUCT" ]]; then
    DETECTED_PRODUCT="lineage_${DEVICE_CODENAME}"
    print_warn "Defaulting to $DETECTED_PRODUCT"
fi

unset TARGET_PRODUCT TARGET_BUILD_VARIANT TARGET_BUILD_TYPE
print_info "Lunching ${DETECTED_PRODUCT}-${BUILD_TYPE}..."
if ! lunch "${DETECTED_PRODUCT}-${BUILD_TYPE}" 2>/dev/null; then
    lunch "${DETECTED_PRODUCT}-trunk_staging-${BUILD_TYPE}" || { print_error "Lunch failed."; exit 1; }
fi
print_success "Lunch successful!"

export PRODUCT_OUT HOST_OUT_EXECUTABLES TARGET_PRODUCT DEVICE_CODENAME
[[ -n "$PRODUCT_OUT" ]] || export PRODUCT_OUT="$BUILD_DIR/out/target/product/$DEVICE_CODENAME"
print_info "Build artifacts: $PRODUCT_OUT"

START_TIME=$(date +%s)
if make target-files-package -j"$JOBS" 2>&1 | tee build.log; then
    print_success "Target files build successful!"
    if [[ -f "$REPO_ROOT/scripts/package_fastboot.sh" ]]; then
        print_info "Generating fastboot package..."
        bash "$REPO_ROOT/scripts/package_fastboot.sh" && print_success "Fastboot package generated." || print_error "Fastboot package failed."
    fi
else
    print_error "Build failed."
    exit 1
fi
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
print_success "Build completed in $((DURATION / 3600))h $(((DURATION % 3600) / 60))m!"
if [[ -d "out/target/product/$DEVICE_CODENAME" ]]; then
    print_info "Output: $BUILD_DIR/out/target/product/$DEVICE_CODENAME"
    ls -lh "out/target/product/$DEVICE_CODENAME"/*.zip 2>/dev/null || true
fi
