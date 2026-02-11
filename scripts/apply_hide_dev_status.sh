#!/bin/bash
# Apply "Hide Developer Status" feature to PixelOS source tree
# Usage: ./scripts/apply_hide_dev_status.sh [TOP_DIR]

set -e

TOP=${1:-$PWD}
PATCHES_DIR="$TOP/patches"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    if [ ! -d "$TOP/frameworks/base" ]; then
        log_error "frameworks/base not found in $TOP"
        exit 1
    fi
    
    if [ ! -d "$TOP/packages/apps/Settings" ]; then
        log_error "packages/apps/Settings not found in $TOP"
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        log_error "git is required but not installed"
        exit 1
    fi
}

# Create backup of a file
backup_file() {
    local file="$1"
    if [ -f "$file" ] && [ ! -f "$file.bak" ]; then
        cp "$file" "$file.bak"
        log_info "Created backup: $file.bak"
    fi
}

# Apply patch with verification
apply_patch() {
    local patch_file="$1"
    local target_dir="$2"
    
    if [ ! -f "$patch_file" ]; then
        log_error "Patch file not found: $patch_file"
        return 1
    fi
    
    log_info "Applying patch: $(basename "$patch_file")"
    
    cd "$target_dir"
    
    # Check if patch can be applied cleanly
    if git apply --check "$patch_file" 2>/dev/null; then
        if git apply "$patch_file"; then
            log_info "Patch applied successfully"
            return 0
        else
            log_error "Failed to apply patch"
            return 1
        fi
    else
        log_warn "Patch may already be applied or conflicts exist"
        # Try to see if it's already applied
        if git diff --name-only | grep -q "SettingsProvider\|Settings.java"; then
            log_info "Changes already present, skipping"
            return 0
        else
            log_error "Patch conflicts detected, manual intervention needed"
            return 1
        fi
    fi
}

# Apply framework patches
apply_framework_patches() {
    log_info "Applying framework patches..."
    
    local fw_patches_dir="$PATCHES_DIR/frameworks_base"
    
    if [ ! -d "$fw_patches_dir" ]; then
        log_warn "No framework patches found in $fw_patches_dir"
        return 0
    fi
    
    # Backup files before patching
    backup_file "$TOP/frameworks/base/packages/SettingsProvider/src/com/android/providers/settings/SettingsProvider.java"
    backup_file "$TOP/frameworks/base/core/java/android/provider/Settings.java"
    
    # Apply patches in order
    for patch in "$fw_patches_dir"/*.patch; do
        if [ -f "$patch" ]; then
            apply_patch "$patch" "$TOP/frameworks/base"
        fi
    done
}

# Create HideDeveloperStatusUtils class
create_utils_class() {
    log_info "Creating HideDeveloperStatusUtils class..."
    
    local utils_dir="$TOP/frameworks/base/core/java/com/android/internal/util/pixelos"
    local utils_file="$utils_dir/HideDeveloperStatusUtils.java"
    
    mkdir -p "$utils_dir"
    
    if [ -f "$utils_file" ]; then
        log_warn "HideDeveloperStatusUtils already exists, skipping"
        return 0
    fi
    
    cat > "$utils_file" << 'EOF'
/*
 * Copyright (C) 2019 The PixelExperience Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.android.internal.util.pixelos;

import android.content.ContentResolver;
import android.content.Context;
import android.os.SystemProperties;
import android.provider.Settings;

import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

/**
 * Utility class to hide developer status from specific apps.
 * This class intercepts settings queries and returns safe values
 * for apps that should not see developer options status.
 */
public class HideDeveloperStatusUtils {
    
    private static final Set<String> SETTINGS_TO_HIDE = new HashSet<>(Arrays.asList(
        Settings.Global.ADB_ENABLED,
        Settings.Global.ADB_WIFI_ENABLED,
        Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
        Settings.Secure.ADB_ENABLED,
        Settings.Secure.DEVELOPMENT_SETTINGS_ENABLED
    ));
    
    private static final Set<String> SYSTEM_PROPS_TO_HIDE = new HashSet<>(Arrays.asList(
        "sys.usb.config",
        "sys.usb.state",
        "persist.sys.usb.config",
        "init.svc.adbd"
    ));
    
    public enum Action {
        ADD,
        REMOVE,
        SET
    }
    
    /**
     * Check if we should hide developer status for this query
     */
    public static boolean shouldHideDevStatus(ContentResolver cr, String packageName, String name) {
        if (cr == null || packageName == null || name == null) {
            return false;
        }
        
        // Don't hide during boot to avoid issues
        if (!SystemProperties.getBoolean("sys.boot_completed", false)) {
            return false;
        }
        
        Set<String> apps = getApps(cr);
        if (apps.isEmpty()) {
            return false;
        }
        
        return apps.contains(packageName) && SETTINGS_TO_HIDE.contains(name);
    }
    
    /**
     * Check if we should hide system property
     */
    public static boolean shouldHideSystemProperty(String packageName, String key) {
        if (packageName == null || key == null) {
            return false;
        }
        
        if (!SystemProperties.getBoolean("sys.boot_completed", false)) {
            return false;
        }
        
        // Note: System property hiding requires native hooks
        // This is for future extensibility
        return SYSTEM_PROPS_TO_HIDE.contains(key);
    }
    
    private static Set<String> getApps(ContentResolver cr) {
        if (cr == null) {
            return new HashSet<>();
        }
        
        String apps = Settings.Secure.getString(cr, "hide_developer_status");
        if (apps != null && !apps.isEmpty() && !apps.equals(",")) {
            return new HashSet<>(Arrays.asList(apps.split(",")));
        }
        
        return new HashSet<>();
    }
    
    private static void putAppsForUser(Context context, String packageName, int userId, Action action) {
        if (context == null || userId < 0) {
            return;
        }
        
        final Set<String> apps = getApps(context.getContentResolver());
        switch (action) {
            case ADD:
                apps.add(packageName);
                break;
            case REMOVE:
                apps.remove(packageName);
                break;
            case SET:
                // Don't change
                break;
        }
        
        Settings.Secure.putStringForUser(
            context.getContentResolver(),
            "hide_developer_status",
            String.join(",", apps),
            userId
        );
    }
    
    public void addApp(Context context, String packageName, int userId) {
        if (context == null || packageName == null || userId < 0) {
            return;
        }
        putAppsForUser(context, packageName, userId, Action.ADD);
    }
    
    public void removeApp(Context context, String packageName, int userId) {
        if (context == null || packageName == null || userId < 0) {
            return;
        }
        putAppsForUser(context, packageName, userId, Action.REMOVE);
    }
    
    public void setApps(Context context, int userId) {
        if (context == null || userId < 0) {
            return;
        }
        putAppsForUser(context, null, userId, Action.SET);
    }
}
EOF
    
    log_info "Created HideDeveloperStatusUtils class"
}

# Create Settings app resources and code
create_settings_app() {
    log_info "Creating Settings app resources..."
    
    local settings_res="$TOP/packages/apps/Settings/res"
    local settings_src="$TOP/packages/apps/Settings/src/com/android/settings/security"
    
    mkdir -p "$settings_res/layout" "$settings_res/menu" "$settings_res/values" "$settings_src"
    
    # Create layout files
    cat > "$settings_res/layout/hide_developer_status_layout.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">
    <androidx.recyclerview.widget.RecyclerView
        android:id="@+id/apps_list"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />
</FrameLayout>
EOF
    
    cat > "$settings_res/layout/hide_developer_status_list_item.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:background="?android:attr/selectableItemBackground"
    android:gravity="center_vertical"
    android:minHeight="?android:attr/listPreferredItemHeightSmall"
    android:paddingStart="?android:attr/listPreferredItemPaddingStart"
    android:paddingEnd="?android:attr/listPreferredItemPaddingEnd">

    <LinearLayout
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:gravity="start|center_vertical"
        android:minWidth="@dimen/secondary_app_icon_size"
        android:orientation="horizontal"
        android:paddingEnd="16dp"
        android:paddingTop="4dp"
        android:paddingBottom="4dp">
        <ImageView
            android:id="@+id/icon"
            android:layout_width="@dimen/secondary_app_icon_size"
            android:layout_height="@dimen/secondary_app_icon_size"/>
    </LinearLayout>

    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_weight="1"
        android:orientation="vertical"
        android:paddingTop="16dp"
        android:paddingBottom="16dp">
        <TextView
            android:id="@+id/label"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:ellipsize="marquee"
            android:fadingEdge="horizontal"
            android:maxLines="2"
            android:textAppearance="?android:attr/textAppearanceListItem"/>
        <TextView
            android:id="@+id/packageName"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:textDirection="locale"
            android:textAppearance="?android:attr/textAppearanceSmall"
            android:textColor="?android:attr/textColorSecondary"/>
    </LinearLayout>
    <CheckBox
        android:id="@+id/checkBox"
        android:layout_width="wrap_content"
        android:layout_height="match_parent"
        android:gravity="center_vertical|end"
        android:focusable="false"
        android:clickable="false" />
</LinearLayout>
EOF
    
    cat > "$settings_res/menu/hide_developer_status_menu.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<menu xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <item
        android:id="@+id/search"
        android:actionViewClass="android.widget.SearchView"
        android:icon="@drawable/ic_find_in_page_24px"
        android:showAsAction="ifRoom|collapseActionView"
        android:title="@string/search"
        tools:ignore="AppCompatResource" />
    <item
        android:id="@+id/show_system"
        android:title="@string/menu_show_system"
        android:showAsAction="never" />
    <item
        android:id="@+id/hide_system"
        android:title="@string/menu_hide_system"
        android:showAsAction="never" />
</menu>
EOF
    
    # Update strings.xml
    local strings_xml="$settings_res/values/strings.xml"
    if [ -f "$strings_xml" ] && ! grep -q "hide_developer_status_title" "$strings_xml"; then
        backup_file "$strings_xml"
        # Add strings before closing resources tag
        sed -i '/<\/resources>/i \\n    <!-- Hide developer status -->\n    <string name="hide_developer_status_title">Hide developer status</string>\n    <string name="hide_developer_status_summary">Hide developer status from apps</string>\n    <string name="menu_show_system">Show system applications</string>\n    <string name="menu_hide_system">Hide system applications</string>' "$strings_xml"
        log_info "Updated strings.xml"
    fi
    
    # Create arrays.xml if not exists
    local arrays_xml="$settings_res/values/arrays.xml"
    if [ ! -f "$arrays_xml" ]; then
        cat > "$arrays_xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
</resources>
EOF
    fi
    
    if ! grep -q "hide_developer_status_hidden_apps" "$arrays_xml"; then
        backup_file "$arrays_xml"
        sed -i '/<\/resources>/i \\n    <!-- Apps list to hide from Hide developer status setting -->\n    <string-array name="hide_developer_status_hidden_apps" translatable="false">\n        <item>android</item>\n        <item>com.android.settings</item>\n        <item>com.android.systemui</item>\n        <item>com.android.shell</item>\n    </string-array>' "$arrays_xml"
        log_info "Updated arrays.xml"
    fi
    
    log_info "Settings app resources created"
}

# Verify the installation
verify_installation() {
    log_info "Verifying installation..."
    
    local errors=0
    
    # Check HideDeveloperStatusUtils
    if [ ! -f "$TOP/frameworks/base/core/java/com/android/internal/util/pixelos/HideDeveloperStatusUtils.java" ]; then
        log_error "HideDeveloperStatusUtils.java not found"
        ((errors++))
    fi
    
    # Check if SettingsProvider was patched
    if ! grep -q "HideDeveloperStatusUtils" "$TOP/frameworks/base/packages/SettingsProvider/src/com/android/providers/settings/SettingsProvider.java" 2>/dev/null; then
        log_warn "SettingsProvider.java may not be patched"
    fi
    
    # Check layout files
    if [ ! -f "$TOP/packages/apps/Settings/res/layout/hide_developer_status_layout.xml" ]; then
        log_error "hide_developer_status_layout.xml not found"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        log_info "Verification passed!"
        return 0
    else
        log_error "Verification failed with $errors errors"
        return 1
    fi
}

# Restore from backup
restore_backup() {
    log_info "Restoring from backups..."
    
    find "$TOP" -name "*.bak" -type f | while read -r backup; do
        local original="${backup%.bak}"
        if [ -f "$original" ]; then
            cp "$backup" "$original"
            log_info "Restored: $original"
        fi
    done
}

# Clean up backups
cleanup_backups() {
    log_info "Cleaning up backups..."
    find "$TOP" -name "*.bak" -type f -delete
    log_info "Backups cleaned up"
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TOP_DIR]

Apply "Hide Developer Status" feature to PixelOS source tree

OPTIONS:
    -h, --help          Show this help message
    -r, --restore       Restore from backups
    -c, --cleanup       Clean up backup files
    -v, --verify        Verify installation only

EXAMPLES:
    $0                          # Apply patches to current directory
    $0 /path/to/aosp            # Apply patches to specific directory
    $0 --restore                # Restore from backups
    $0 --cleanup                # Remove all backup files
EOF
}

# Main function
main() {
    local restore=false
    local cleanup=false
    local verify_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -r|--restore)
                restore=true
                shift
                ;;
            -c|--cleanup)
                cleanup=true
                shift
                ;;
            -v|--verify)
                verify_only=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                TOP="$1"
                shift
                ;;
        esac
    done
    
    cd "$TOP"
    
    if [ "$cleanup" = true ]; then
        cleanup_backups
        exit 0
    fi
    
    if [ "$restore" = true ]; then
        restore_backup
        exit 0
    fi
    
    if [ "$verify_only" = true ]; then
        verify_installation
        exit $?
    fi
    
    log_info "Applying Hide Developer Status feature to $TOP..."
    
    check_prerequisites
    apply_framework_patches
    create_utils_class
    create_settings_app
    
    if verify_installation; then
        log_info "======================================"
        log_info "Installation completed successfully!"
        log_info "======================================"
        log_info ""
        log_info "Next steps:"
        log_info "1. Review the patches applied in frameworks/base"
        log_info "2. Build the ROM and test"
        log_info "3. Use --verify flag to check installation"
        log_info "4. Use --restore flag to revert changes if needed"
    else
        log_error "Installation completed with errors"
        exit 1
    fi
}

main "$@"
