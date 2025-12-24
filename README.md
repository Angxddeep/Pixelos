# 🚀 PixelOS Build for Xaga

Build **PixelOS (sixteen-qpr1)** for Xaga devices on GitHub Actions or Google Cloud.

## 📱 Supported Devices
- POCO X4 GT
- Redmi K50i  
- Redmi Note 11T Pro / Pro+

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

# 3. Setup environment
git clone https://github.com/YOUR_USER/Pixelos.git
cd Pixelos && bash scripts/env-setup.sh

# 4. Build!
bash scripts/build-pixelos.sh
```

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
├── .github/workflows/build.yml   # GitHub Actions workflow
├── docs/GCLOUD_BUILD.md          # Google Cloud guide
├── local_manifests/xaga.xml      # Device sources manifest
├── scripts/
│   ├── gcloud-setup.sh           # Create GCloud VM
│   ├── env-setup.sh              # Install build dependencies
│   └── build-pixelos.sh          # Main build script
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
