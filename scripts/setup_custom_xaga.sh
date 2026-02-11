#!/bin/bash
#
# Setup custom_xaga.mk for PixelOS builds
# Creates the product makefile and updates AndroidProducts.mk
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

DEVICE_CODENAME="xaga"
DEVICE_MANUFACTURER="xiaomi"
DEVICE_DIR="device/$DEVICE_MANUFACTURER/$DEVICE_CODENAME"

# Check if we're in the right directory
if [[ ! -d "build" ]] || [[ ! -d "vendor/custom" ]]; then
    print_error "Run this script from the PixelOS source root (~/pixelos)"
    exit 1
fi

# Check if device directory exists
if [[ ! -d "$DEVICE_DIR" ]]; then
    print_error "Device directory not found: $DEVICE_DIR"
    print_error "Make sure you've synced sources with: repo sync"
    exit 1
fi

# Check if BoardConfig exists
BOARDCONFIG_MK="$DEVICE_DIR/BoardConfig.mk"
BOARDCONFIG_XAGA_MK="$DEVICE_DIR/BoardConfigXaga.mk"
if [[ ! -f "$BOARDCONFIG_MK" ]] && [[ ! -f "$BOARDCONFIG_XAGA_MK" ]]; then
    print_warn "BoardConfig.mk or BoardConfigXaga.mk not found in $DEVICE_DIR"
    print_warn "The device tree might not be synced properly"
fi

print_info "Setting up custom_xaga.mk for PixelOS..."

# Create custom_xaga.mk
CUSTOM_MK="$DEVICE_DIR/custom_xaga.mk"

if [[ -f "$CUSTOM_MK" ]]; then
    print_warn "$CUSTOM_MK already exists. Backing up..."
    cp "$CUSTOM_MK" "${CUSTOM_MK}.bak"
fi

print_info "Creating $CUSTOM_MK..."

cat > "$CUSTOM_MK" << 'EOFMK'
# PixelOS product configuration for xaga
# Inherits from PixelOS common configuration

# Inherit device configuration first (sets up architecture, etc.)
$(call inherit-product, device/xiaomi/mt6895-common/mt6895.mk)
$(call inherit-product, device/xiaomi/xaga/device.mk)

# Inherit PixelOS common full phone configuration
$(call inherit-product, vendor/custom/config/common_full_phone.mk)

# Product name
PRODUCT_NAME := custom_xaga
PRODUCT_DEVICE := xaga
PRODUCT_BRAND := Xiaomi
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_MODEL := POCO X4 GT

# Product properties
PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.name=xaga \
    ro.product.device=xaga \
    ro.product.model=POCO X4 GT

# Enable GMS
$(call inherit-product-if-exists, vendor/gms/gms.mk)
EOFMK

print_success "Created $CUSTOM_MK"

# Update AndroidProducts.mk
PRODUCTS_MK="$DEVICE_DIR/AndroidProducts.mk"

if [[ ! -f "$PRODUCTS_MK" ]]; then
    print_info "Creating $PRODUCTS_MK..."
    cat > "$PRODUCTS_MK" << 'EOFPRODUCTS'
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/custom_xaga.mk \
    $(LOCAL_DIR)/lineage_xaga.mk

COMMON_LUNCH_CHOICES := \
    custom_xaga-userdebug \
    custom_xaga-user \
    lineage_xaga-userdebug \
    lineage_xaga-user
EOFPRODUCTS
    print_success "Created $PRODUCTS_MK"
else
    print_info "Updating $PRODUCTS_MK..."
    
    # Check if custom_xaga.mk is already in the file
    if grep -q "custom_xaga.mk" "$PRODUCTS_MK"; then
        print_info "custom_xaga.mk already in AndroidProducts.mk"
    else
        # Add custom_xaga.mk to PRODUCT_MAKEFILES
        if grep -q "PRODUCT_MAKEFILES" "$PRODUCTS_MK"; then
            # Add custom_xaga.mk before lineage_xaga.mk
            sed -i '/PRODUCT_MAKEFILES :=/,/lineage_xaga.mk/ {
                /lineage_xaga.mk/i\
    $(LOCAL_DIR)/custom_xaga.mk \\
            }' "$PRODUCTS_MK" || {
                # Fallback: append to PRODUCT_MAKEFILES line
                sed -i '/PRODUCT_MAKEFILES :=/a\    $(LOCAL_DIR)/custom_xaga.mk \\' "$PRODUCTS_MK"
            }
        else
            # Create PRODUCT_MAKEFILES section
            sed -i '1i\
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/custom_xaga.mk \
' "$PRODUCTS_MK"
        fi
        
        # Add lunch choices if COMMON_LUNCH_CHOICES exists
        if grep -q "COMMON_LUNCH_CHOICES" "$PRODUCTS_MK"; then
            sed -i '/COMMON_LUNCH_CHOICES :=/a\    custom_xaga-userdebug \\\n    custom_xaga-user \\' "$PRODUCTS_MK"
        else
            echo "" >> "$PRODUCTS_MK"
            echo "COMMON_LUNCH_CHOICES := \\" >> "$PRODUCTS_MK"
            echo "    custom_xaga-userdebug \\" >> "$PRODUCTS_MK"
            echo "    custom_xaga-user \\" >> "$PRODUCTS_MK"
        fi
        
        print_success "Updated $PRODUCTS_MK"
    fi
fi

# Add MIUI Camera if it exists
if [[ -d "vendor/$DEVICE_MANUFACTURER/miuicamera-xaga" ]]; then
    if ! grep -q "miuicamera-xaga/device.mk" "$CUSTOM_MK"; then
        print_info "Adding MIUI Camera to custom_xaga.mk..."
        echo "" >> "$CUSTOM_MK"
        echo "# MIUI Camera" >> "$CUSTOM_MK"
        echo "\$(call inherit-product, vendor/$DEVICE_MANUFACTURER/miuicamera-xaga/device.mk)" >> "$CUSTOM_MK"
        print_success "Added MIUI Camera"
    fi
fi

# Add preloader if it exists
PRELOADER_PATH="vendor/$DEVICE_MANUFACTURER/$DEVICE_CODENAME/radio/preloader_xaga.bin"
if [[ -f "$PRELOADER_PATH" ]]; then
    if ! grep -q "preloader_xaga.bin" "$CUSTOM_MK"; then
        print_info "Adding preloader to custom_xaga.mk..."
        echo "" >> "$CUSTOM_MK"
        echo "# Preloader for fastboot package" >> "$CUSTOM_MK"
        echo "PRODUCT_COPY_FILES += \\" >> "$CUSTOM_MK"
        echo "    $PRELOADER_PATH:\$(PRODUCT_OUT)/preloader_xaga.bin" >> "$CUSTOM_MK"
        print_success "Added preloader"
    fi
fi

# Verify BoardConfig exists
if [[ -f "$BOARDCONFIG_XAGA_MK" ]]; then
    print_info "Found BoardConfigXaga.mk"
    if ! grep -q "TARGET_SUPPORTS_64_BIT_APPS" "$BOARDCONFIG_XAGA_MK"; then
        print_warn "BoardConfigXaga.mk doesn't have TARGET_SUPPORTS_64_BIT_APPS set"
        print_warn "This may cause '32-bit-app-only product on 64-bit device' errors"
    fi
elif [[ -f "$BOARDCONFIG_MK" ]]; then
    print_info "Found BoardConfig.mk"
    if ! grep -q "TARGET_SUPPORTS_64_BIT_APPS" "$BOARDCONFIG_MK"; then
        print_warn "BoardConfig.mk doesn't have TARGET_SUPPORTS_64_BIT_APPS set"
        print_warn "This may cause '32-bit-app-only product on 64-bit device' errors"
    fi
else
    print_error "No BoardConfig found! The device tree may not be synced properly."
    print_error "Run: repo sync"
    exit 1
fi

print_success "=========================================="
print_success "Setup complete!"
print_success "=========================================="
echo ""
print_info "You can now run:"
echo "  source build/envsetup.sh"
echo "  breakfast xaga"
echo ""
print_warn "If you get '32-bit-app-only product' error, try:"
echo "  lunch custom_xaga-userdebug"
echo "  m pixelos_fb"
echo ""
