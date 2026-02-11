# Migration Guide: Old → New Implementation

## Quick Start

If you previously used the old sed-based implementation, here's how to migrate to the new patch-based system:

### 1. Clean Up Old Implementation

```bash
# Restore original files from backups (if available)
find . -name "*.bak" -type f -exec sh -c 'cp "$1" "${1%.bak}"' _ {} \;

# Or manually revert these files:
# - frameworks/base/packages/SettingsProvider/src/com/android/providers/settings/SettingsProvider.java
# - frameworks/base/core/java/android/provider/Settings.java
```

### 2. Delete Old Files

```bash
# Remove old utility class (it will be recreated)
rm -f frameworks/base/core/java/com/android/internal/util/pixelos/HideDeveloperStatusUtils.java

# Remove old Settings app files
rm -f packages/apps/Settings/res/layout/hide_developer_status_layout.xml
rm -f packages/apps/Settings/res/layout/hide_developer_status_list_item.xml
rm -f packages/apps/Settings/res/menu/hide_developer_status_menu.xml
rm -f packages/apps/Settings/src/com/android/settings/security/HideDeveloperStatusSettings.kt
rm -f packages/apps/Settings/src/com/android/settings/security/HideDeveloperStatusPreferenceController.java
```

### 3. Apply New Implementation

```bash
# Run the new script
./scripts/apply_hide_dev_status.sh

# Verify installation
./scripts/apply_hide_dev_status.sh --verify
```

## What's Changed

### Before (Old Implementation)
- Used `sed` to inject code into existing files
- Fragile - broke easily on different Android versions
- Single monolithic script
- Hard to maintain

### After (New Implementation)
- Uses `git apply` with unified diff patches
- Reliable across Android versions
- Organized patch files in `patches/` directory
- Separate utility class
- Better error handling
- Backup and restore functionality

## File Comparison

### Old vs New File Structure

```
# OLD
scripts/
└── apply_hide_dev_status.sh (600+ lines, everything embedded)

# NEW
patches/
├── README.md
├── frameworks_base/
│   ├── 0001-Add-hide-developer-status-to-SettingsProvider.patch
│   └── 0002-Add-hide-developer-status-constant.patch
└── packages_apps_Settings/
    └── src/com/android/settings/security/
        ├── HideDeveloperStatusSettings.kt
        └── HideDeveloperStatusPreferenceController.java
scripts/
└── apply_hide_dev_status.sh (clean, uses external files)
```

## Key Improvements

### 1. **Patch Both query() and call() Methods**
The new implementation patches both methods apps use to access settings:
- `query()` - Standard ContentProvider method
- `call()` - Direct method calls (faster, used by system apps)

### 2. **Proper Import Handling**
The patch now properly adds:
```java
import android.database.MatrixCursor;
import com.android.internal.util.pixelos.HideDeveloperStatusUtils;
```

### 3. **Backup and Restore**
```bash
# Automatic backups created before patching
./scripts/apply_hide_dev_status.sh --restore  # Restore from backups
./scripts/apply_hide_dev_status.sh --cleanup  # Clean up backup files
```

### 4. **Verification**
```bash
./scripts/apply_hide_dev_status.sh --verify  # Check if properly installed
```

## Troubleshooting Migration

### Issue: "Patch does not apply"

**Cause**: Files were already modified by old implementation

**Solution**:
```bash
# Clean up first
cd frameworks/base
git checkout -- packages/SettingsProvider/src/com/android/providers/settings/SettingsProvider.java
git checkout -- core/java/android/provider/Settings.java

# Then apply patches
cd ../..
./scripts/apply_hide_dev_status.sh
```

### Issue: "Missing template files"

**Cause**: Template files not in patches directory

**Solution**:
Ensure these files exist:
- `patches/packages_apps_Settings/src/com/android/settings/security/HideDeveloperStatusSettings.kt`
- `patches/packages_apps_Settings/src/com/android/settings/security/HideDeveloperStatusPreferenceController.java`

### Issue: "Settings app not building"

**Cause**: Missing resources or wrong imports

**Solution**:
Check that these resources were created:
- `packages/apps/Settings/res/layout/hide_developer_status_layout.xml`
- `packages/apps/Settings/res/layout/hide_developer_status_list_item.xml`
- `packages/apps/Settings/res/menu/hide_developer_status_menu.xml`

And strings were added to `packages/apps/Settings/res/values/strings.xml`

## Verification Checklist

After migration, verify:

- [ ] `frameworks/base/core/java/com/android/internal/util/pixelos/HideDeveloperStatusUtils.java` exists
- [ ] `frameworks/base/packages/SettingsProvider/src/com/android/providers/settings/SettingsProvider.java` contains "HideDeveloperStatusUtils"
- [ ] `packages/apps/Settings/res/layout/hide_developer_status_layout.xml` exists
- [ ] `packages/apps/Settings/src/com/android/settings/security/HideDeveloperStatusSettings.kt` exists
- [ ] `packages/apps/Settings/src/com/android/settings/security/HideDeveloperStatusPreferenceController.java` exists
- [ ] Run `./scripts/apply_hide_dev_status.sh --verify` passes

## Rolling Back

If you need to revert to the old implementation:

```bash
# Restore backups
./scripts/apply_hide_dev_status.sh --restore

# Or manually revert files using git
cd frameworks/base
git checkout -- packages/SettingsProvider/src/com/android/providers/settings/SettingsProvider.java
git checkout -- core/java/android/provider/Settings.java
cd ../..

# Remove new files
rm -rf frameworks/base/core/java/com/android/internal/util/pixelos
rm -f packages/apps/Settings/res/layout/hide_developer_status_*.xml
rm -f packages/apps/Settings/res/menu/hide_developer_status_menu.xml
rm -f packages/apps/Settings/src/com/android/settings/security/HideDeveloperStatus*.kt
rm -f packages/apps/Settings/src/com/android/settings/security/HideDeveloperStatus*.java
```

## Benefits of New Implementation

1. **More Reliable**: Git patches are more reliable than sed
2. **Easier to Debug**: Can inspect patches before applying
3. **Version Control Friendly**: Patches can be version controlled
4. **Maintainable**: Easier to update for new Android versions
5. **Better Coverage**: Both query() and call() methods patched
6. **Safer**: Automatic backups and verification

## Getting Help

If you encounter issues:

1. Check verification: `./scripts/apply_hide_dev_status.sh --verify`
2. Read the README: `cat patches/README.md`
3. Check patches applied: `cd frameworks/base && git status`
4. Restore and retry: `./scripts/apply_hide_dev_status.sh --restore && ./scripts/apply_hide_dev_status.sh`
