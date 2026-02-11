# 🚀 PixelOS Build for Xaga

Build **PixelOS (sixteen-qpr1)** for Xaga devices on GitHub Actions or Google Cloud. This repo uses a **structured workflow**: single config, staged scripts, and clear clean/recache steps.

## 📱 Supported Devices
- POCO X4 GT
- Redmi K50i  
- Redmi Note 11T Pro / Pro+

## 📖 PixelOS build practices (reference)

Official flow (see [PixelOS Building Guide](https://blog.pixelos.net/docs/JoinTheTeam/BuildingPixelOS); page may be outdated):

1. **Environment** — JDK 17, Android build deps, `repo`, git-lfs (we use `scripts/env-setup.sh`).
2. **Sync** — `repo init -u <manifest> -b <branch>`, then `repo sync`. We use **android_manifest** (PixelOS-AOSP), branch **sixteen-qpr1**.
3. **Device sources** — Device/vendor/kernel trees in the right paths; PixelOS sixteen uses **custom_** product prefix and **vendor/custom/**.
4. **Build** — `lunch <product>-userdebug`, then `mka bacon` or equivalent. We build **target-files-package** and then package a fastboot ZIP.

All ROM/device/repo settings live in **`config/build.conf`** so you can change branch or device in one place.

## 🔗 Source Configuration

| Component | Repository | Branch |
|-----------|------------|--------|
| Device Tree | [xiaomi-mt6895-devs](https://github.com/xiaomi-mt6895-devs) | lineage-23.1 |
| Kernel | xiaomi-mt6895-devs | lineage-23.1 |
| Vendor | xiaomi-mt6895-devs | lineage-23.1 |
| MediaTek HAL | xiaomi-mt6895-devs | lineage-23.1 |
| MIUI Camera | [XagaForge](https://gitlab.com/priiii1808/proprietary_vendor_xiaomi_miuicamera-xaga) | 16.1 |

## ☁️ Google Cloud Build (Recommended)

Build on a powerful cloud VM with no time limits.

### Quick Start

```bash
# 1. Create VM (~$2-3/hr, or ~$0.50/hr with Spot)
bash scripts/gcloud-setup.sh --project=YOUR_PROJECT --spot

# 2. SSH into VM
gcloud compute ssh pixelos-builder --zone=us-central1-a

# 3. One-time env setup
git clone https://github.com/YOUR_USER/Pixelos.git
cd Pixelos && bash scripts/env-setup.sh

# 4. Build (syncs then builds; use --sync-only or --build-only as needed)
bash scripts/build-pixelos.sh
```

### Full clean and recache

To wipe GCloud and recache everything (e.g. after changing branch or cleaning the project):

```bash
# Local: delete VM and get step-by-step instructions
bash scripts/gcloud-clean-recache.sh --project=YOUR_PROJECT --delete
```

On the VM, to only wipe source + build and re-sync:  
`rm -rf ~/pixelos/.repo ~/pixelos/out` then `bash scripts/build-pixelos.sh`. See [docs/GCLOUD_BUILD.md](docs/GCLOUD_BUILD.md).

📖 **Full Guide**: [docs/GCLOUD_BUILD.md](docs/GCLOUD_BUILD.md)

## ⚡ GitHub Actions Build

Build using GitHub Actions (requires self-hosted runner for builds >6 hours).

### Steps
1. Fork this repository
2. Go to **Actions** → **Build PixelOS for Xaga**
3. Click **Run workflow**
4. Select build options

### Limitations

| Limit | Free Tier |
|-------|-----------|
| Build time | 6 hours max |
| Storage | 500 MB artifacts |

> ⚠️ ROM builds take 8-12 hours. Use self-hosted runner or Google Cloud.

## 📂 Repository Structure

```
Pixelos/
├── config/
│   └── build.conf                # Single source of truth: ROM branch, device, repos, paths
├── docs/
│   ├── GCLOUD_BUILD.md           # Google Cloud + clean/recache
│   └── MIUI_CAMERA_DEBUG.md
├── local_manifests/xaga.xml     # Device sources manifest (reference)
├── scripts/
│   ├── lib/common.sh             # Shared helpers + config loading
│   ├── stages/                   # Build stages (run from build-pixelos.sh)
│   │   ├── 01-sync-repo.sh       # repo init + sync
│   │   ├── 02-device-trees.sh    # Device/vendor/kernel/MediaTek/Lineage
│   │   ├── 03-miui-preloader.sh  # MIUI Camera + preloader
│   │   ├── 04-patches.sh         # wpa_supplicant_8 patches
│   │   ├── 05-post-sync-fixes.sh # Qualcomm/livedisplay removal
│   │   └── 06-build.sh           # Pre-build fixes, lunch, make, package_fastboot
│   ├── fixes/                    # Python fix scripts (ParanoidSense etc.)
│   ├── gcloud-setup.sh           # Create/delete GCloud VM
│   ├── gcloud-clean-recache.sh   # Clean VM + full recache steps
│   ├── env-setup.sh              # One-time build env on VM
│   ├── build-pixelos.sh          # Main entry (uses config + stages)
│   └── package_fastboot.sh       # Fastboot ZIP packaging
├── .github/workflows/build.yml
└── README.md
```

## 🛠️ Troubleshooting

### Build Failed
Check logs in `build.log` or download the artifact from Actions.

### Out of Disk Space
GitHub runners have ~14GB. Use Google Cloud for larger builds.

### Patch Conflicts
If patches fail on newer branches, manually review and apply.

## 📜 Credits

- Device trees: [xiaomi-mt6895-devs](https://github.com/xiaomi-mt6895-devs)
- MIUI Camera: [XagaForge](https://github.com/XagaForge)
- ROM: [PixelOS](https://github.com/PixelOS-AOSP)
