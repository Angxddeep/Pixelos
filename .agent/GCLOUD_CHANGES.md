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
