# Building PixelOS on Google Cloud

This guide covers setting up a Google Cloud Compute Engine VM for building PixelOS.

## Prerequisites

1. **Google Cloud Account** with billing enabled
2. **gcloud CLI** installed locally: [Install Guide](https://cloud.google.com/sdk/docs/install)
3. **GCP Project** created

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/YOUR_USER/Pixelos.git
cd Pixelos

# 2. Create VM (requires gcloud CLI)
bash scripts/gcloud-setup.sh --project=YOUR_PROJECT_ID --spot

# 3. SSH into VM
gcloud compute ssh pixelos-builder --zone=us-central1-a

# 4. On the VM: Clone repo and setup
git clone https://github.com/YOUR_USER/Pixelos.git
cd Pixelos
bash scripts/env-setup.sh

# 5. Start build
bash scripts/build-pixelos.sh
```

## VM Specifications

| Spec | Recommended | Minimum |
|------|-------------|---------|
| vCPUs | 32 | 16 |
| RAM | 128 GB | 64 GB |
| Storage | 500 GB SSD | 300 GB SSD |
| OS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |

## Cost Estimation

| VM Type | Hourly Cost | Build Time | Total |
|---------|-------------|------------|-------|
| n2-standard-32 (On-Demand) | ~$1.60 | 4-6 hours | $6-10 |
| n2-standard-32 (Spot) | ~$0.50 | 4-6 hours | $2-3 |
| n2-highmem-32 (Spot) | ~$0.75 | 3-5 hours | $2-4 |

> **Tip**: Use `--spot` flag to save 60-80% on VM costs. Spot VMs can be preempted but builds can be resumed.

## Scripts

### gcloud-setup.sh

Creates a GCP Compute Engine VM.

```bash
# Basic usage
bash scripts/gcloud-setup.sh --project=my-project

# With Spot VM (cheaper)
bash scripts/gcloud-setup.sh --project=my-project --spot

# Custom specs
bash scripts/gcloud-setup.sh --project=my-project --machine=n2-highmem-32 --disk-size=600

# Delete VM after build
bash scripts/gcloud-setup.sh --project=my-project --delete
```

### env-setup.sh

Installs Android build dependencies on the VM.

```bash
# Run on the VM
bash scripts/env-setup.sh
```

### build-pixelos.sh

Builds PixelOS for Xaga device.

```bash
# Full build
bash scripts/build-pixelos.sh

# Sync sources only (no build)
bash scripts/build-pixelos.sh --sync-only

# Clean build
bash scripts/build-pixelos.sh --clean

# Release build
bash scripts/build-pixelos.sh --user
```

## Source Configuration

The build uses:

| Component | Source | Branch |
|-----------|--------|--------|
| Device Tree | xiaomi-mt6895-devs | lineage-23.1 |
| Kernel | xiaomi-mt6895-devs | lineage-23.1 |
| Vendor | xiaomi-mt6895-devs | lineage-23.1 |
| MediaTek HAL | xiaomi-mt6895-devs | lineage-23.1 |
| MIUI Camera | XagaForge (GitLab) | 16.1 |

## Download Build Output

After build completes:

```bash
# From your local machine
gcloud compute scp pixelos-builder:~/pixelos/out/target/product/xaga/*.zip ./
```

## Fastboot Package

The fastboot package is a self-contained ZIP with firmware, AOSP images, tools, and installation scripts — matching the AresOS reference layout.

### Building

```bash
# Build fastboot ROM only (NO recovery ROM):
cd ~/pixelos
source build/envsetup.sh
breakfast xaga
bash ~/Pixelos/scripts/apply_fb_package_patch.sh   # generates fb_package.mk
m pixelos_fb                                        # builds target-files-package + fb_package only
```

**Alternative:** If you want to build recovery ROM first, then fastboot package:
```bash
m pixelos fb_package  # This WILL build recovery ROM first
```

**Note:** `m pixelos_fb` builds ONLY fastboot ROM (no recovery ROM). Use this if you only need fastboot package.

The output ZIP will be at `out/target/product/xaga/<date>-<time>.zip`.

### Package Contents

| Directory | Contents |
|-----------|----------|
| `images/` | All firmware (apusys, scp, lk, tee, etc.), boot, vbmeta, super.img, preloader |
| `tools/` | fastboot binaries for Linux and Windows |
| Root | `win_installation.bat`, `linux_installation.sh` |

### Flashing

1. Extract the ZIP
2. Boot device into bootloader (`adb reboot bootloader` or Vol Down + Power)
3. Run `win_installation.bat` (Windows) or `sudo bash linux_installation.sh` (Linux)

> **⚠️ Warning**: Do NOT use `fastboot reboot recovery` on xaga — it can brick the device.

## Troubleshooting

### Out of Memory
Increase VM RAM or add swap:
```bash
sudo fallocate -l 32G /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Build Fails at Sync
Retry with fewer jobs:
```bash
repo sync -j4
```

### Preempted Spot VM
Re-start VM and resume build:
```bash
gcloud compute instances start pixelos-builder --zone=us-central1-a
gcloud compute ssh pixelos-builder --zone=us-central1-a
cd ~/pixelos && bash ../Pixelos/scripts/build-pixelos.sh --build-only
```

## Cleanup

**Delete VM to stop billing:**
```bash
bash scripts/gcloud-setup.sh --project=YOUR_PROJECT --delete
```
