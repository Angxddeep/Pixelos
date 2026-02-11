# MIUI Camera Debugging Guide for PixelOS

## Quick Start (Windows)

1. Connect your device via USB with debugging enabled
2. Run: `scripts\debug-miui-camera.bat`
3. Check the generated log folder for issues

## Common Issues & How to Fix

### 1. Camera App Not Found

**Symptoms:**
- MIUI Camera icon missing
- `pm list packages | grep camera` shows no MIUI camera

**Check in logs:**
- `installed_camera_apps.txt` - should show `com.xiaomi.camera` or similar
- `camera_package_dump.txt` - should contain MIUI Camera package info

**Solutions:**
- Verify MIUI Camera vendor is cloned:
  ```bash
  ls vendor/xiaomi/miuicamera-xaga/
  ```
- Check if it's included in `device/xiaomi/xaga/custom_xaga.mk`:
  ```makefile
  $(call inherit-product-if-exists, vendor/xiaomi/miuicamera-xaga/device.mk)
  ```
- Rebuild with clean:
  ```bash
  bash scripts/build-pixelos.sh --clean
  ```

### 2. Camera Crashes on Open (libmialgoengine.so errors)

**Symptoms:**
- Camera app opens then immediately crashes
- Log shows `dlopen failed` or `cannot locate symbol`

**Check in logs:**
- `logcat_camera.txt` - look for "MIArcSoft" or "libmialgo" errors
- `camera_crashes.txt` - check for native crashes
- `vendor_camera_libs.txt` - verify libmialgoengine.so exists

**Example error:**
```
E MIArcSoft: dlopen failed: cannot locate symbol "_ZN7android..."
```

**Solutions:**
- Blob ABI mismatch with Android 16 QPR1 - may need newer MIUI Camera branch
- Try updating from `16.1` to `16.2` or `main` branch:
  ```bash
  cd vendor/xiaomi/miuicamera-xaga
  git fetch origin
  git checkout 16.2  # or try different branch
  ```
- Check XagaForge GitLab for updated branches

### 3. Black Screen / Preview Not Working

**Symptoms:**
- Camera app opens but shows black screen
- No preview, can't take photos

**Check in logs:**
- `camera_service_dump.txt` - check "Device" section for errors
- `logcat_camera.txt` - look for "Camera3-Device" errors
- `camera_sepolicy.txt` - check for SELinux denials

**Common errors:**
```
E Camera3-Device: configureStreams: Stream configuration failed
E CameraService: Camera 0: Error connecting to camera: Permission denied
```

**Solutions:**
- SEPolicy issues - may need to add camera permissions to sepolicy
- Camera HAL compatibility - check if `camera.device@3.x` interface is available
- Try clearing camera app data:
  ```bash
  adb shell pm clear com.xiaomi.camera
  ```

### 4. Front Camera Not Working

**Symptoms:**
- Rear camera works, front camera doesn't
- App crashes when switching cameras

**Check in logs:**
- `camera_service_dump.txt` - check camera IDs and capabilities
- Device tree camera configuration

**Solutions:**
- Check camera IDs in device tree `camera/camera_config.xml`
- Verify front camera sensor is properly defined

### 5. SEPolicy Denials

**Symptoms:**
- Camera features work partially
- Log shows avc: denied messages

**Check in logs:**
- `camera_sepolicy.txt` - look for "avc: denied" messages
- `logcat_full.txt` - search for "audit" and "camera"

**Example:**
```
W audit: type=1400 audit(...): avc: denied { read } for name="camera" dev="sysfs"
```

**Solutions:**
- Add missing sepolicy rules to `device/xiaomi/xaga/sepolicy/vendor/file.te` and `file_contexts`
- Or set permissive mode temporarily to test:
  ```bash
  adb shell setenforce 0
  ```

## Key Log Tags to Monitor

When manually checking logs, filter for these tags:

```bash
adb logcat -s CameraService:*
adb logcat -s Camera3-Device:*
adb logcat -s MIArcSoft:*
adb logcat -s miui.camera:*
adb logcat -s audit:*
```

## Files to Check

### On Build Machine:
- `vendor/xiaomi/miuicamera-xaga/` - Vendor blobs directory
- `device/xiaomi/xaga/custom_xaga.mk` - Integration makefile
- `device/xiaomi/xaga/BoardConfigXaga.mk` - Board config include

### On Device:
- `/vendor/lib/libmialgoengine.so` - Core camera algorithm library
- `/vendor/lib64/libmialgoengine.so` - 64-bit version
- `/vendor/lib/libarcsoft_*` - ArcSoft libraries
- `/system/etc/camera/` - Camera configuration files

## How to Report Issues

When reporting MIUI Camera issues, include:

1. **Device info:**
   - ROM version (e.g., PixelOS 16 QPR1)
   - Device model (POCO X4 GT / Redmi K50i / etc.)

2. **Logs (from debug script):**
   - `logcat_camera.txt`
   - `camera_crashes.txt`
   - `camera_service_dump.txt`
   - `vendor_camera_libs.txt`

3. **What you've tried:**
   - Clean install?
   - Different MIUI Camera branch?
   - Permissive SELinux?

4. **Specific error messages:**
   - Copy relevant lines from logcat

## Updating MIUI Camera

If the current version doesn't work, try updating:

```bash
# On build machine
cd ~/pixelos/vendor/xiaomi/miuicamera-xaga

# Check available branches
git branch -a

# Try different branch
git fetch origin
git checkout 16.2  # or main, or other available branch

# Rebuild
cd ~/pixelos
m pixelos
```

Available branches on XagaForge GitLab:
- `16.1` - Original branch (may have Android 16 QPR1 issues)
- `16.2` - Updated for newer Android versions
- `main` - Latest development

## Known Working Configurations

| ROM Branch | MIUI Camera Branch | Status |
|------------|-------------------|--------|
| sixteen-qpr1 | 16.1 | ⚠️ Testing needed |
| sixteen-qpr1 | 16.2 | 🔄 Try this if 16.1 fails |

## Getting Help

1. Check XagaForge GitLab issues for similar problems
2. Join PixelOS or Xaga device support groups
3. Share logs using the debug script above
