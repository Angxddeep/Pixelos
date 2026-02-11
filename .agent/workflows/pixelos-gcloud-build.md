---
description: PixelOS ROM Build Project - GCloud Build Helper for Xaga Devices
---

# PixelOS GCloud Build Project Context

## Project Overview

This is a **PixelOS Android ROM** build project for **Xaga** devices:
- POCO X4 GT
- Redmi K50i
- Redmi Note 11T Pro / Pro+

The ROM is built on **Google Cloud Compute Engine** VMs using Ubuntu 22.04 LTS.

## Key Information

| Item | Value |
|------|-------|
| ROM | PixelOS |
| ROM Branch | `sixteen-qpr1` (Android 16 QPR1) |
| Manifest | `https://github.com/PixelOS-AOSP/android_manifest.git` |
| Device Codename | xaga |
| SoC | MediaTek Dimensity 8100 (MT6895) |
| Lunch Target | `aosp_xaga-bp1a-userdebug` |
| Build Directory | `~/pixelos` |
| Build Script | ``~/Pixelos/scripts/build-pixelos.sh` |

> **Available Branches**: `sixteen-qpr1` (default), `sixteen-qpr2`, `sixteen`

## Source Trees

| Component | Repository | Branch |
|-----------|------------|--------|
| Device Tree | xiaomi-mt6895-devs | lineage-23.1 |
| Kernel | xiaomi-mt6895-devs | lineage-23.1 |
| Vendor | xiaomi-mt6895-devs | lineage-23.1 |
| MediaTek HAL | xiaomi-mt6895-devs | lineage-23.1 |
| MIUI Camera | XagaForge (GitLab) | 16.1 |

## GCloud VM Specs

- **Recommended**: n2-standard-32 (32 vCPUs, 128GB RAM)
- **Storage**: 500GB SSD
- **OS**: Ubuntu 22.04 LTS
- **Zone**: us-central1-a

## Important Files

- `scripts/build-pixelos.sh` - Main build script
- `scripts/env-setup.sh` - Environment setup for VM
- `scripts/gcloud-setup.sh` - VM creation script
- `local_manifests/xaga.xml` - Device manifest
- `docs/GCLOUD_BUILD.md` - Full GCloud build guide

## Common Build Commands

```bash
# Full build
bash scripts/build-pixelos.sh

# Sync sources only
bash scripts/build-pixelos.sh --sync-only

# Build only (sources already synced)
bash scripts/build-pixelos.sh --build-only

# Clean build
bash scripts/build-pixelos.sh --clean
```

## New PixelOS sixteen-qpr1 Build Method

The build script uses the new PixelOS build commands:
- `breakfast <device>` - replaces the old `lunch` command
- `m pixelos` - replaces `mka bacon`


## Known Patches/Fixes Applied by Build Script

1. **wpa_supplicant_8 patches** - MediaTek WiFi & WAPI support
2. **Livedisplay dependencies removed** - AIDL/HIDL incompatibility
3. **Qualcomm vibrator removed** - Not needed for MediaTek
4. **aosp_xaga.mk created** - PixelOS product makefile (device trees are for LineageOS)

## Troubleshooting Reference

See `.agent/GCLOUD_CHANGES.md` for a log of all modifications, deletions, and patches applied during builds with explanations of why each change was needed.

## When Helping with Build Errors

1. Check the build log: `build.log` in build directory
2. Check `.agent/GCLOUD_CHANGES.md` to see if the error relates to a known issue
3. Common issues:
   - **Missing dependencies**: Usually need to clone/update a repo
   - **HIDL/AIDL mismatches**: Module naming issues between ROM versions
   - **Qualcomm vs MediaTek**: Some AOSP/PixelOS modules are Qualcomm-only
   - **Lunch target format**: PixelOS sixteen uses `aosp_<device>-bp1a-<buildtype>`