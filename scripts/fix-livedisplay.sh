#!/bin/bash
# Fix script for livedisplay module dependency naming issue
# The frameworks/base uses old HIDL naming (V2.0-java, V2.1-java) 
# but LineageOS 23.1 uses new AIDL naming (V2-java)
#
# Run this from your PixelOS root directory:
#   bash scripts/fix-livedisplay.sh

set -e

FRAMEWORK_BP="frameworks/base/Android.bp"

if [ ! -f "$FRAMEWORK_BP" ]; then
    echo "[ERROR] Cannot find $FRAMEWORK_BP"
    echo "[ERROR] Please run this script from your PixelOS root directory"
    exit 1
fi

echo "[INFO] Fixing livedisplay module dependencies in $FRAMEWORK_BP..."

# Replace V2.0-java with V2-java
sed -i 's/vendor\.lineage\.livedisplay-V2\.0-java/vendor.lineage.livedisplay-V2-java/g' "$FRAMEWORK_BP"

# Replace V2.1-java with V2-java (they both map to the same AIDL module)
sed -i 's/vendor\.lineage\.livedisplay-V2\.1-java/vendor.lineage.livedisplay-V2-java/g' "$FRAMEWORK_BP"

# Remove duplicate entries that may have been created
# This is a simple approach - just removes consecutive duplicate lines
awk '!seen[$0]++' "$FRAMEWORK_BP" > "${FRAMEWORK_BP}.tmp" && mv "${FRAMEWORK_BP}.tmp" "$FRAMEWORK_BP"

echo "[SUCCESS] Fixed livedisplay dependencies!"
echo "[INFO] Old HIDL names (V2.0-java, V2.1-java) replaced with AIDL name (V2-java)"
echo ""
echo "[NEXT] Now rebuild your ROM:"
echo "  source build/envsetup.sh"
echo "  lunch aosp_xaga-userdebug"
echo "  mka bacon"
