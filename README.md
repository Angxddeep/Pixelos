# 🚀 PixelOS Build for Xaga

Build **PixelOS (sixteen-qpr1)** for Xaga devices using GitHub Actions.

## 📱 Supported Devices
- POCO X4 GT
- Redmi K50i  
- Redmi Note 11T Pro / Pro+

## ⚡ Quick Start

### 1. Fork or Create Repository

**Option A: Fork this repo**
- Click "Fork" on GitHub

**Option B: Create new repo**
1. Create a new GitHub repository
2. Copy the `.github/workflows/build.yml` file to your repo

### 2. Run the Build

1. Go to your repository on GitHub
2. Click **Actions** tab
3. Select **"Build PixelOS for Xaga"** workflow
4. Click **"Run workflow"**
5. Choose your options:
   - **Build type**: `userdebug` (for testing) or `user` (for release)
   - **Clean build**: Enable for fresh build
   - **Upload to Release**: Creates a GitHub Release with the ROM

### 3. Download the ROM

After build completes (~6-10 hours):
- **Artifacts**: Go to Actions → Your build → Download "PixelOS-xaga-*"
- **Releases**: Go to Releases tab (if enabled)

## ⚠️ Important Notes

### GitHub Actions Limitations

| Limit | Free Tier | Pro |
|-------|-----------|-----|
| Build time | 6 hours max | 6 hours max |
| Storage | 500 MB artifacts | 2 GB artifacts |
| Minutes/month | 2000 min | 3000 min |

> **Problem**: ROM builds often take 8-12 hours, exceeding 6-hour limit!

### Solutions for 6-Hour Limit

#### Option 1: Self-Hosted Runner (Recommended)
Use your own PC or a VPS as a runner - no time limits!

```bash
# On your Linux machine/VPS:
# Go to: Settings → Actions → Runners → New self-hosted runner
# Follow the instructions to add your runner
```

#### Option 2: Use Crave.io (Free, Built for ROMs)
[Crave.io](https://crave.io) offers free Android build infrastructure.

#### Option 3: Split Build into Parts
Use caching and split the workflow (advanced).

## 🔧 Customization

### Change ROM Target

Edit `.github/workflows/build.yml`:

```yaml
env:
  ROM_MANIFEST: https://github.com/PixelOS-AOSP/android_manifest.git
  ROM_BRANCH: sixteen-qpr1
  LUNCH_TARGET: aosp_xaga  # Change if needed
```

### Use Different Device Trees

Modify the "Clone device trees" steps with your preferred sources.

## 📂 Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── build.yml    # GitHub Actions workflow
└── README.md
```

## 🔗 Source Repositories

| Component | Repository |
|-----------|------------|
| ROM Manifest | [PixelOS-AOSP/android_manifest](https://github.com/PixelOS-AOSP/android_manifest) |
| Device Trees | [XagaForge](https://github.com/XagaForge) |
| Vendor (xaga) | [GitLab - priiii08918](https://gitlab.com/priiii08918/android_vendor_xiaomi_xaga) |
| MiuiCamera | [GitLab - priiii1808](https://gitlab.com/priiii1808/proprietary_vendor_xiaomi_miuicamera-xaga) |

## 🛠️ Troubleshooting

### Build Failed - Check Logs
1. Go to Actions → Failed build
2. Click on failed step
3. Download `build-log-failed` artifact

### Out of Disk Space
GitHub runners have ~14GB free space. The workflow already clears unused tools.

### Patch Conflicts
Patches may fail on newer ROM branches. Check build logs and manually apply if needed.

## 📜 License

Device trees and configurations are from [XagaForge](https://github.com/XagaForge).
