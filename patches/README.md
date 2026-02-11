# Hide Developer Status - Improved Implementation

This is an improved implementation of the "Hide Developer Status" feature for PixelOS. It uses proper git patches instead of fragile sed replacements and provides better coverage of settings access methods.

## Improvements Over Previous Implementation

### 1. **Proper Patch Files**
- Uses unified diff format patches applied with `git apply`
- Much more reliable than sed-based text replacement
- Easier to maintain and update for different Android versions
- Can be version controlled and reviewed

### 2. **Comprehensive Coverage**
Patches both methods apps use to access settings:
- `query()` - Standard ContentProvider query method
- `call()` - Direct method calls (faster, preferred by system apps)

### 3. **Better Error Handling**
- Pre-flight checks with `git apply --check`
- Automatic backup creation
- Verification step after installation
- Clear error messages with color coding

### 4. **Improved HideDeveloperStatusUtils**
- Supports more setting keys (ADB_WIFI_ENABLED, etc.)
- Better null-safety checks
- Support for system properties (extensible for future)
- Comprehensive documentation

## Architecture

```
patches/
├── frameworks_base/
│   ├── 0001-Add-hide-developer-status-to-SettingsProvider.patch
│   └── 0002-Add-hide-developer-status-constant.patch
└── packages_apps_Settings/
    └── (future patches for Settings app)

frameworks/base/
├── core/java/com/android/internal/util/pixelos/
│   └── HideDeveloperStatusUtils.java (new)
└── packages/SettingsProvider/src/com/android/providers/settings/
    └── SettingsProvider.java (patched)

packages/apps/Settings/
├── res/layout/
│   ├── hide_developer_status_layout.xml
│   └── hide_developer_status_list_item.xml
├── res/menu/
│   └── hide_developer_status_menu.xml
├── res/values/
│   └── (updated strings.xml and arrays.xml)
└── src/com/android/settings/security/
    ├── HideDeveloperStatusSettings.kt
    └── HideDeveloperStatusPreferenceController.java
```

## Installation

### Prerequisites
- Git must be installed
- Source tree must be initialized
- frameworks/base and packages/apps/Settings must exist

### Basic Usage

```bash
# Apply to current directory
./scripts/apply_hide_dev_status.sh

# Apply to specific directory
./scripts/apply_hide_dev_status.sh /path/to/aosp

# Verify installation
./scripts/apply_hide_dev_status.sh --verify

# Restore from backups (if something goes wrong)
./scripts/apply_hide_dev_status.sh --restore

# Clean up backup files
./scripts/apply_hide_dev_status.sh --cleanup
```

## How It Works

### 1. Framework Level (SettingsProvider)

When an app queries settings, the patched SettingsProvider checks:
1. Is the requesting app in the hide list?
2. Is the setting being queried a developer-related setting?
3. If both true, return "0" (disabled) instead of the real value

The patch intercepts:
- **query()**: Standard ContentProvider queries
- **call()**: Direct method calls used for performance

### 2. Utility Class (HideDeveloperStatusUtils)

Provides the logic to:
- Read the list of apps to hide from (`Settings.Secure.HIDE_DEVELOPER_STATUS`)
- Check if a setting should be hidden
- Manage the app list (add/remove)

Settings that are hidden:
- `ADB_ENABLED` (both Global and Secure)
- `ADB_WIFI_ENABLED`
- `DEVELOPMENT_SETTINGS_ENABLED` (both Global and Secure)

### 3. Settings App

Provides UI for users to:
- View all installed apps
- Select which apps should see hidden developer status
- Search and filter apps
- Show/hide system apps

## Security Considerations

### Fail-Open Design
The implementation uses "fail-open" design:
- If the check fails (null parameters, boot not completed), it returns `false` (don't hide)
- This ensures apps don't get stuck in a broken state

### Boot Protection
During boot (`!sys.boot_completed`), the feature is disabled:
- Prevents system apps from getting stuck
- Avoids circular dependencies during early boot

### Protected Apps
By default, these apps cannot be hidden from (they can always see real status):
- `android` (system)
- `com.android.settings`
- `com.android.systemui`
- `com.android.shell`

## Extending the Implementation

### Adding More Settings to Hide

Edit `HideDeveloperStatusUtils.java`:
```java
private static final Set<String> SETTINGS_TO_HIDE = new HashSet<>(Arrays.asList(
    Settings.Global.ADB_ENABLED,
    Settings.Global.ADB_WIFI_ENABLED,
    Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
    Settings.Secure.ADB_ENABLED,
    Settings.Secure.DEVELOPMENT_SETTINGS_ENABLED,
    // Add your setting here:
    Settings.Global.YOUR_SETTING
));
```

### Hiding System Properties (Advanced)

For apps that read system properties directly via `SystemProperties`, you need to patch native code:

1. Patch `frameworks/base/core/jni/android_os_SystemProperties.cpp`
2. Hook the `SystemProperties_get` or `SystemProperties_getBoolean` functions
3. Check calling package and return safe values

This is not implemented in the current version but is documented for future extensibility.

## Troubleshooting

### Patch Application Failed

```bash
# Check if patch can be applied
cd frameworks/base
git apply --check ../../patches/frameworks_base/0001-*.patch

# If conflicts exist, check current changes
git status
git diff
```

### Verification Failed

Run with verify flag to see specific issues:
```bash
./scripts/apply_hide_dev_status.sh --verify
```

### Restore Original Files

If something goes wrong:
```bash
./scripts/apply_hide_dev_status.sh --restore
```

## Patch Format

Patches follow unified diff format:
```diff
--- a/path/to/original/file
+++ b/path/to/modified/file
@@ -line,offset +line,offset @@
 context lines
-removed lines
+added lines
```

## Contributing

When creating new patches:
1. Make changes manually first
2. Generate patch: `git diff > 000X-description.patch`
3. Test with `git apply --check`
4. Place in appropriate patches/ subdirectory
5. Update this documentation

## Credits

Based on ideas from:
- PixelExperience Project
- AOSP-Krypton Project
- Nameless-AOSP Project
- ImNotADeveloper LSPosed module
- DevOptsHide LSPosed module

## License

Apache License 2.0 (same as AOSP)
