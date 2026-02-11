# Stage 3: MIUI Camera and preloader for Xaga
# Run from BUILD_DIR.

_STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -n "$REPO_ROOT" ]] || REPO_ROOT="$(cd "$_STAGE_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/lib/common.sh"

print_step "4/6 - MIUI Camera and preloader..."

# MIUI Camera
rm -rf "vendor/$DEVICE_MANUFACTURER/miuicamera-xaga" 2>/dev/null || true
git clone --depth=1 -b "$MIUI_CAMERA_BRANCH" "$MIUI_CAMERA_GITLAB" "vendor/$DEVICE_MANUFACTURER/miuicamera-xaga"

DEVICE_MK="device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/custom_xaga.mk"
BOARD_MK="device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/BoardConfigXaga.mk"
VENDOR_MIUI="vendor/$DEVICE_MANUFACTURER/miuicamera-xaga"

if [[ -f "$DEVICE_MK" ]]; then
    grep -q "miuicamera-xaga/device.mk" "$DEVICE_MK" || {
        echo "" >> "$DEVICE_MK"
        echo "# MIUI Camera" >> "$DEVICE_MK"
        echo "\$(call inherit-product, $VENDOR_MIUI/device.mk)" >> "$DEVICE_MK"
        print_success "Added MIUI Camera to custom_xaga.mk"
    }
fi
if [[ -f "$BOARD_MK" ]]; then
    grep -q "miuicamera-xaga/BoardConfig.mk" "$BOARD_MK" || {
        echo "" >> "$BOARD_MK"
        echo "# MIUI Camera" >> "$BOARD_MK"
        echo "include $VENDOR_MIUI/BoardConfig.mk" >> "$BOARD_MK"
        print_success "Added MIUI Camera to BoardConfigXaga.mk"
    }
fi

# Preloader
DEVICE_RADIO_DIR="vendor/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/radio"
mkdir -p "$DEVICE_RADIO_DIR"
PRELOADER_PATH="$DEVICE_RADIO_DIR/preloader_xaga.bin"
if [[ ! -f "$PRELOADER_PATH" ]]; then
    print_info "Downloading preloader from XagaForge..."
    curl -fsSL "$PRELOADER_URL" -o "$PRELOADER_PATH" || print_warn "Preloader download failed; fastboot package may be incomplete."
else
    print_info "Preloader already present, skipping."
fi
if [[ -f "$DEVICE_MK" ]] && ! grep -q "preloader_xaga.bin" "$DEVICE_MK"; then
    echo "" >> "$DEVICE_MK"
    echo "# Preloader for fastboot package" >> "$DEVICE_MK"
    echo "PRODUCT_COPY_FILES += \\" >> "$DEVICE_MK"
    echo "    $PRELOADER_PATH:\$(PRODUCT_OUT)/preloader_xaga.bin" >> "$DEVICE_MK"
    print_success "Added preloader to custom_xaga.mk"
fi
