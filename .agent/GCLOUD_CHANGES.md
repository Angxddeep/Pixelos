# GCloud Build Changes Log

This file tracks all modifications, deletions, and patches applied during PixelOS builds on Google Cloud.

> **Purpose**: New AI agents should read this file to understand what has been changed and why, to help debug future build errors.

> **Current Branch**: `sixteen-qpr1` (Android 16 QPR1) - Updated Jan 2026  
> **Manifest**: `https://github.com/PixelOS-AOSP/android_manifest.git` (new repo, the old `/manifest` was archived)  
> Available branches: `sixteen-qpr1` (default), `sixteen-qpr2`, `sixteen`

---

## Status Legend

| Status | Meaning |
|--------|---------|
| ✅ | Fix confirmed working |
| ⚠️ | Partial fix / workaround |
| 🔄 | Ongoing / needs monitoring |
| ❌ | Removed / reverted |

---

## Applied Changes

### 1. ✅ Created `custom_xaga.mk` Product Makefile

**Location**: `device/xiaomi/xaga/custom_xaga.mk`

**Reason**: The xiaomi-mt6895-devs device trees are built for LineageOS and only include `lineage_xaga.mk`. PixelOS sixteen-qpr1 requires a `custom_xaga.mk` file that inherits from `vendor/custom/config/common_full_phone.mk`.

> [!IMPORTANT]
> PixelOS changed naming in sixteen-qpr1:
> - Product prefix: `aosp_` → `custom_`
> - Vendor path: `vendor/aosp/` → `vendor/custom/`

**What it does**:
- Inherits PixelOS common configuration from `vendor/custom/`
- Sets correct product name (`custom_xaga`), brand, and fingerprint
- Enables GMS (Google Mobile Services)

---

### 2. ✅ Removed Livedisplay Dependencies from `frameworks/base`

**Location**: `frameworks/base/Android.bp`

**Reason**: PixelOS frameworks/base references livedisplay modules using old HIDL naming (`V2.0-java`, `V2.1-java`), but the hardware/lineage/interfaces repo uses new AIDL naming (`V2-java`). Even after fixing names, AIDL interfaces are unfrozen and incompatible with the frozen framework-internal-utils.

**What was changed**:
```bash
sed -i '/vendor\.lineage\.livedisplay/d' frameworks/base/Android.bp
```

**Impact**: LiveDisplay features (color calibration, reading mode) won't work. Core display functionality is unaffected.

---

### 3. ✅ Removed Incompatible Livedisplay HIDL Services

**Locations deleted**:
- `hardware/lineage/livedisplay/legacymm`
- `hardware/lineage/livedisplay/sdm`
- `hardware/lineage/livedisplay/sysfs`

**Reason**: These HIDL service implementations reference `@2.0` interfaces that don't exist in the AIDL-based hardware/lineage/interfaces from LineageOS 23.1.

---

### 4. ✅ Removed Qualcomm Vibrator

**Location deleted**: `vendor/qcom/opensource/vibrator`

**Reason**: This is a Qualcomm-only HAL with dependencies on Qualcomm-specific libraries. Not needed for MediaTek MT6895 devices.

---

### 5. ✅ Applied wpa_supplicant_8 Patches

**Location**: `external/wpa_supplicant_8`

**Patches applied**:
1. `39200b6c7b1f9ff1c1c6a6a5e4cd08c6f526d048` - MediaTek changes for WiFi support
2. `37a6e255d9d68fb483d12db550028749b280509b` - WAPI enablement

**Source**: `https://github.com/Nothing-2A/android_external_wpa_supplicant_8`

**Reason**: Standard AOSP wpa_supplicant doesn't support MediaTek's WiFi driver requirements.

---

### 6. ✅ Removed Qualcomm Hardware Directories

**Locations deleted**:
- `hardware/qcom/sdm845`
- `hardware/qcom/sm7250`
- `hardware/qcom/sm8150`
- `hardware/qcom/sm8250`
- `hardware/qcom/sm8350`

**Reason**: Broken symlinks / not needed for MediaTek builds. These cause build warnings/errors when they exist but aren't properly populated.

---

### 7. ✅ Cloned LineageOS Hardware Interfaces

**Location**: `hardware/lineage/interfaces`

**Source**: `https://github.com/AresOS-UDC/android_hardware_lineage_interfaces.git` (branch: lineage-22.1)

**Reason**: Device trees from xiaomi-mt6895-devs depend on LineageOS-specific hardware interfaces that aren't in stock PixelOS.

---

### 8. ✅ Removed ParanoidSense (Face Unlock)

**Locations**:
- Deleted: `packages/apps/ParanoidSense`
- Modified: `vendor/custom/config/common.mk` (removed from PRODUCT_PACKAGES)

**Reason**: ParanoidSense's `libmegface` conflicts with Xiaomi's `hardware/xiaomi/megvii`. Both define the same library.

**What was changed**:
```bash
rm -rf packages/apps/ParanoidSense
sed -i '/ParanoidSense/d' vendor/custom/config/common.mk
```

**Impact**: PixelOS face unlock disabled. Xiaomi's vendor face unlock may still work.

---

### 9. ✅ Removed ParanoidSense Biometrics from frameworks/base

**Location**: `frameworks/base/services/core/Android.bp`

**Reason**: After removing ParanoidSense, frameworks/base still depended on `vendor.aospa.biometrics.face`.

**What was changed**:
```bash
sed -i '/vendor\.aospa\.biometrics\.face/d' frameworks/base/services/core/Android.bp
```

---

### 10. ✅ Removed Qualcomm Vibrator References from Device Tree

**Locations**:
- `device/xiaomi/mt6895-common/mt6895.mk`
- `device/xiaomi/xaga/custom_xaga.mk`

**Reason**: xiaomi-mt6895-devs incorrectly included Qualcomm vibrator refs (`vendor.qti.hardware.vibrator.service`, `excluded-input-devices.xml`). Not needed for MediaTek.

**What was changed**:
```bash
sed -i '/vendor.qti.hardware.vibrator/d' device/xiaomi/mt6895-common/mt6895.mk
sed -i '/excluded-input-devices.xml/d' device/xiaomi/mt6895-common/mt6895.mk
```

**Impact**: None. MediaTek vibration handled by `hardware/mediatek/` and vendor blobs.

---

### 11. ✅ Removed LineageOS Internal Hardware Classes

**Location deleted**: `frameworks/base/core/java/com/android/internal/lineage/hardware/`

**Reason**: PixelOS frameworks/base contains LineageOS hardware classes (LineageHardwareManager, DisplayMode, HSIC, LiveDisplayConfig) that reference livedisplay AIDL interfaces we don't have.

**What was changed**:
```bash
rm -rf frameworks/base/core/java/com/android/internal/lineage/hardware/
```

**Impact**: LineageOS hardware features disabled (LiveDisplay color calibration, hardware key customization).

---

### 12. ✅ Removed ParanoidSense Face Services

**Location deleted**: `frameworks/base/services/core/java/com/android/server/biometrics/sensors/face/sense/`

**Reason**: ParanoidSense face biometrics references `vendor.aospa.biometrics.face.ISenseService` which we don't have.

**What was changed**:
```bash
rm -rf frameworks/base/services/core/java/com/android/server/biometrics/sensors/face/sense/
```

---

### 13. ✅ Removed LineageOS Display Services

**Location deleted**: `frameworks/base/services/core/java/com/android/server/lineage/`

**Reason**: Contains LiveDisplayService, LineageHardwareService, and display controllers that depend on removed LineageOS hardware classes.

**What was changed**:
```bash
rm -rf frameworks/base/services/core/java/com/android/server/lineage/
# Simple sed is too aggressive, use Python script (see entry #15)
```

**Impact**: LiveDisplay features completely disabled. Display functions normally.

---

### 14. ✅ Complete ParanoidSense Biometrics Removal

**Locations modified**:
- `frameworks/base/services/core/java/com/android/server/biometrics/sensors/face/FaceService.java`
- `frameworks/base/services/core/java/com/android/server/biometrics/AuthService.java`

**Reason**: After removing the sense/ directory (entry #12), these files still import and call `SenseProvider` and `SenseUtils` classes that no longer exist.

**What was changed**:
```bash
# Remove imports and replace SenseUtils.canUseProvider() with false
# FaceService.java: Remove getSenseProviders() method entirely
# AuthService.java: Remove Sense condition from face provider check
python3 /tmp/fix_sense_biometrics.py
```

**Python fix script** (saved as `/tmp/fix_sense_biometrics.py` in build script):
- Removes `import ...sense.SenseProvider` and `import ...sense.SenseUtils`
- Replaces `SenseUtils.canUseProvider()` with `false`
- Removes the entire `getSenseProviders()` method from FaceService
- Removes `providers.addAll(getSenseProviders())` call

**Impact**: ParanoidSense face unlock completely disabled. Standard HIDL face unlock unaffected.

---

### 15. ✅ InputMethodManagerService LineageHardware Complete Fix

**Location modified**: `frameworks/base/services/core/java/com/android/server/inputmethod/InputMethodManagerService.java`

**Reason**: Simple sed deletion of `mLineageHardware` lines breaks the file because it removes parts of if-blocks and method bodies. Need a more surgical approach.

**What was changed**:
```bash
# Use Python to properly stub out LineageHardwareManager
python3 /tmp/fix_imms.py
```

**Python fix script** (saved in build script):
- Removes the import statement
- Removes the field declaration
- Removes the initialization line
- Replaces `mLineageHardware.isSupported(...)` calls with `false`
- Comments out `mLineageHardware.set(...)` calls

**Impact**: Touch polling rate, touch sensitivity, and touch hovering toggles disabled. Touch works normally at device default settings.

---

### 16. ✅ Removed LineageHardwareManager from Settings DisplaySettings

**Location modified**: `packages/apps/Settings/src/com/android/settings/DisplaySettings.java`

**Reason**: `DisplaySettings.java` references `LineageHardwareManager` for touch polling rate and touch sensitivity features. These classes were removed from `frameworks/base` (entry #11), so the Settings app can no longer resolve them.

**What was changed**:
```bash
# Use Python to remove LineageHardwareManager references
# - Removed LineageHardwareManager import
# - Removed stray closing brace from previously deleted block
# - Removed hardware.isSupported(FEATURE_HIGH_TOUCH_SENSITIVITY) block
# - getNonIndexableKeys() now just calls super and returns
python3 -c "<inline script>"
```

**Impact**: High touch polling rate and high touch sensitivity toggles won't appear in Settings. Touch works normally at device default settings. Same impact scope as entry #15.

---

### 17. ✅ Created Git Placeholders for Deleted Repo Projects

**Locations**: Multiple deleted directories that `repo` still tracks:
- `hardware/qcom/sdm845/{display,gps}`
- `hardware/qcom/sm7250/{display,gps}`
- `hardware/qcom/sm8150/{display,gps}`
- `hardware/qcom/audio`, `bt`, `camera`, `display`, `gps`, `media`, `data/ipacfg-mgr`
- `vendor/qcom/opensource/vibrator`
- `packages/apps/ParanoidSense`

**Reason**: The `build-manifest.xml` build step runs `repo manifest -r` which needs every manifest project to be a valid git directory. Directories deleted by entries #4, #6, #8 caused `FileNotFoundError` crashes during this step.

**What was changed**:
```bash
# Create empty git repos at all missing project paths
repo list | while IFS=' : ' read -r path name; do
  path=$(echo "$path" | xargs)
  if [ -n "$path" ] && [ ! -d "$path/.git" ]; then
    mkdir -p "$path"
    git -C "$path" init && git -C "$path" commit --allow-empty -m "placeholder"
  fi
done
```

**Impact**: None on functionality. These are empty placeholder repos that satisfy `repo manifest` but contribute no code to the build.

---

### 18. ✅ Optional: Fastboot Package Build Support (XagaForge)

**Locations**: New files in `vendor/custom/build/`:
- `tasks/fb_package.mk` — Make target for `m fb_package`
- `tools/releasetools/Android.bp` — Python binary definition
- `tools/releasetools/img_from_target_files_extended.py` — Image extraction script
- `core/config.mk` — Added `IMG_FROM_TARGET_FILES_EXTENDED` variable

**Source**: [AresOS commit 19afe7c](https://github.com/AresOS-UDC/vendor_lineage/commit/19afe7c7e98c9ff5f57c57d09edfa954142e65b6) adapted for PixelOS `vendor/custom`

**What was changed**: Applied via `scripts/apply_fb_package_patch.sh`. Adds a `fb_package` build target that generates a fastboot-flashable ZIP containing all partition images from the target-files package.

**Impact**: Optional — does not affect the normal `m pixelos` build. Run `m fb_package` after a successful build to generate the fastboot package.

---

### 19. ✅ Restored Vibrator HAL (Reverts Entry #10)

**Locations**: `device/xiaomi/mt6895-common/mt6895.mk`, `vendor/qcom/opensource/vibrator/excluded-input-devices.xml`

**Reason**: Entry #10 removed `vendor.qti.hardware.vibrator.service` and `excluded-input-devices.xml` assuming they were Qualcomm-specific. However, the xiaomi-mt6895-devs vendor blobs ship this vibrator HAL service. Removing it caused vibration to stop working entirely and the vibration settings to disappear.

**What was changed**:
- Restored `PRODUCT_PACKAGES += vendor.qti.hardware.vibrator.service` in `mt6895.mk`
- Restored `PRODUCT_COPY_FILES` for `excluded-input-devices.xml` in `mt6895.mk`
- Recreated `vendor/qcom/opensource/vibrator/excluded-input-devices.xml`
- Removed the `sed` commands from `build-pixelos.sh` that stripped these lines

**Impact**: Vibration now works. Vibration settings restored in Settings app.

---

### 20. ✅ Added MIUI Camera from XagaForge

**Locations**:
- `vendor/xiaomi/miuicamera-xaga/` — cloned from `gitlab.com/priiii1808/proprietary_vendor_xiaomi_miuicamera-xaga` (branch `16.1`)
- `device/xiaomi/xaga/custom_xaga.mk` — added `inherit-product` for `device.mk`
- `device/xiaomi/xaga/BoardConfigXaga.mk` — added `include` for `BoardConfig.mk`

**What was changed**: Cloned the MIUI Camera vendor package and integrated it into the device tree makefiles so it gets included in the build.

**Impact**: MIUI Camera app is now included in the ROM build.

---

### 21. ✅ Added Build Upload Script

**Location**: `scripts/upload-build.sh`

**What was changed**: New script that generates a fastboot package (`m fb_package`) and uploads ROM ZIP, fastboot ZIP, `boot.img`, and `vendor_boot.img` to `gs://pixelos-xaga-builds`.

**Usage**: `bash ~/Pixelos/scripts/upload-build.sh` (from `~/pixelos`)

**Impact**: Convenience script for post-build packaging and download.

---

### 22. ✅ Restored Vibrator Source Code (Reverts Entry #4)

**Locations**: `vendor/qcom/opensource/vibrator`

**Reason**: The build failed with `includes non-existent modules in PRODUCT_PACKAGES: vendor.qti.hardware.vibrator.service`. This confirms that the MediaTek device tree expects to build the Qualcomm vibrator HAL from Use, not just use a prebuilt. Entry #4 had deleted this directory.

**What was changed**:
- Commented out the `rm -rf vendor/qcom/opensource/vibrator` block in `scripts/build-pixelos.sh`.
- Instructed user to restore the directory via `repo sync`.

**Impact**: Builds can now compile the vibrator HAL service required by the device tree.

---

## Pending Issues / Watch List

### 🔄 MIUI Camera Compatibility

The MIUI Camera package from XagaForge is built for specific framework versions. If camera crashes occur:
1. Check if camera blob versions match framework expectations
2. May need to update branch from `16.1` to match ROM version

### 🔄 SEPolicy Warnings

MediaTek SEPolicy from xiaomi-mt6895-devs may generate warnings. Usually safe to ignore unless:
- Boot fails with selinux denials
- Specific features don't work

---

## How to Add New Entries

When fixing a build error, add an entry with:

```markdown
### N. [STATUS] Brief Description

**Location**: `path/to/file/or/directory`

**Reason**: Why this change was needed

**What was changed**: Specific commands or code changes

**Impact**: What features are affected (if any)
```

---

## Build Error Quick Reference

| Error Pattern | Likely Cause | Solution Reference |
|--------------|--------------|-------------------|
| `livedisplay` module not found | HIDL/AIDL mismatch | See entry #2, #3 |
| `vendor.lineage.*` missing | LineageOS deps | See entry #7 |
| `hardware/qcom/*` errors | Wrong platform | See entry #6 |
| WiFi not working | Missing patches | See entry #5 |
| `lunch` target not found | Missing makefile | See entry #1 |
| `custom_xaga` not found | Wrong product prefix | See entry #1 |
| `libmegface already defined` | ParanoidSense conflict | See entry #8 |
| `vendor.aospa.biometrics.face` missing | ParanoidSense removed | See entry #9 |
| `vendor.qti.hardware.vibrator` missing | Vibrator HAL removed | See entry #19 (reverts #10) |
| `excluded-input-devices.xml` missing | Vibrator config removed | See entry #19 (reverts #10) |
| No vibration / settings missing | Vibrator HAL not in build | See entry #19 |
| `LineageHardwareManager` not found | LineageOS classes removed | See entry #11 |
| `ISenseService` not found | ParanoidSense services | See entry #12 |
| `LiveDisplayService` errors | LineageOS display services | See entry #13 |
| `SenseProvider` / `SenseUtils` not found | ParanoidSense biometrics | See entry #14 |
| `mLineageHardware` cannot find symbol | IMMS LineageOS touch features | See entry #15 |
| `LineageHardwareManager` in DisplaySettings | Settings touch feature toggles | See entry #16 |
| `build-manifest.xml` FileNotFoundError | Deleted repo project dirs | See entry #17 |


