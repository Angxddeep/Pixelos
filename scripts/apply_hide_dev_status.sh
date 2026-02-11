#!/bin/bash
# Apply "Hide Developer Status" feature to PixelOS source tree
# Usage: ./scripts/apply_hide_dev_status.sh [TOP_DIR]

set -e

TOP=${1:-$PWD}

if [ ! -d "$TOP/frameworks/base" ]; then
    echo "Error: frameworks/base not found in $TOP"
    exit 1
fi

echo "Applying Hide Developer Status feature to $TOP..."

# -----------------------------------------------------------------------------
# 1. Frameworks Base Changes
# -----------------------------------------------------------------------------

echo "Creating HideDeveloperStatusUtils.java..."
mkdir -p "$TOP/frameworks/base/core/java/com/android/internal/util/pixelos"
cat > "$TOP/frameworks/base/core/java/com/android/internal/util/pixelos/HideDeveloperStatusUtils.java" << 'EOF'
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

public class HideDeveloperStatusUtils {
    private static final Set<String> settingsToHide =
        new HashSet<>(
            Arrays.asList(
                Settings.Global.ADB_ENABLED,
                Settings.Global.ADB_WIFI_ENABLED,
                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED
            ));

    enum Action {
        ADD,
        REMOVE,
        SET
    }

    private static boolean isBootCompleted() {
        return SystemProperties.getBoolean("sys.boot_completed", false);
    }

    public static boolean shouldHideDevStatus(ContentResolver cr, String packageName, String name) {
        if (cr == null || packageName == null || name == null || !isBootCompleted()) {
            return false;
        }

        Set<String> apps = getApps(cr);
        if (apps.isEmpty()) {
            return false;
        }

        return apps.contains(packageName) && settingsToHide.contains(name);
    }

    private static Set<String> getApps(Context context) {
        if (context == null) {
            return new HashSet<>();
        }

        return getApps(context.getContentResolver());
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

    private static void putAppsForUser(
            Context context, String packageName, int userId, Action action) {
        if (context == null || userId < 0) {
            return;
        }

        final Set<String> apps = getApps(context);
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
                userId);
    }

    public void addApp(Context mContext, String packageName, int userId) {
        if (mContext == null || packageName == null || userId < 0) {
            return;
        }

        putAppsForUser(mContext, packageName, userId, Action.ADD);
    }

    public void removeApp(Context mContext, String packageName, int userId) {
        if (mContext == null || packageName == null || userId < 0) {
            return;
        }

        putAppsForUser(mContext, packageName, userId, Action.REMOVE);
    }

    public void setApps(Context mContext, int userId) {
        if (mContext == null || userId < 0) {
            return;
        }

        putAppsForUser(mContext, null, userId, Action.SET);
    }
}
EOF

echo "Patching Settings.java to add HIDE_DEVELOPER_STATUS..."
SETTINGS_JAVA="$TOP/frameworks/base/core/java/android/provider/Settings.java"
if grep -q "HIDE_DEVELOPER_STATUS" "$SETTINGS_JAVA"; then
    echo "  Constant already exists in Settings.java, skipping."
else
    # Insert safely into Secure class. Look for a known constant or end of class.
    # Inserting after "public static final class Secure extends NameValueTable {"
    sed -i '/public static final class Secure extends NameValueTable {/a \        /** @hide */\n        public static final String HIDE_DEVELOPER_STATUS = "hide_developer_status";' "$SETTINGS_JAVA"
fi

echo "Patching SettingsProvider.java..."
SP_JAVA="$TOP/frameworks/base/packages/SettingsProvider/src/com/android/providers/settings/SettingsProvider.java"
if [ ! -f "$SP_JAVA" ]; then
    # Fallback path for Android 12+ / different structures
    SP_JAVA="$TOP/packages/SettingsProvider/src/com/android/providers/settings/SettingsProvider.java"
fi

if [ -f "$SP_JAVA" ]; then
    if grep -q "HideDeveloperStatusUtils" "$SP_JAVA"; then
        echo "  SettingsProvider seems already patched, skipping."
    else
        # 1. Add Import
        sed -i '/import android.util.ArraySet;/a import com.android.internal.util.pixelos.HideDeveloperStatusUtils;' "$SP_JAVA" || \
        sed -i '/package com.android.providers.settings;/a import com.android.internal.util.pixelos.HideDeveloperStatusUtils;' "$SP_JAVA"

        # 2. Add Logic to query method
        # This is tricky with sed. We look for the start of the query method.
        # Common signature: public Cursor query(Uri uri, String[] projection, Bundle queryArgs, CancellationSignal cancellationSignal)
        
        # We will append the logic check at the beginning of the function
        sed -i '/public Cursor query(Uri uri, String\[\] projection, Bundle queryArgs, CancellationSignal cancellationSignal) {/a \        if (HideDeveloperStatusUtils.shouldHideDevStatus(getContext().getContentResolver(), getCallingPackage(queryArgs), uri.getLastPathSegment())) {\n            MatrixCursor cursor = new MatrixCursor(new String[]{Settings.NameValueTable.VALUE});\n            cursor.addRow(new Object[]{"0"});\n            return cursor;\n        }' "$SP_JAVA"
        
        echo "  Patched SettingsProvider.java. PLEASE VERIFY THE CHANGES manually as sed patching on complex files can be fragile."
    fi
else
    echo "  Warning: SettingsProvider.java not found. Skipping patch."
fi

# -----------------------------------------------------------------------------
# 2. Settings App Changes
# -----------------------------------------------------------------------------

echo "Creating Settings App resources..."
SETTINGS_RES="$TOP/packages/apps/Settings/res"
mkdir -p "$SETTINGS_RES/layout" "$SETTINGS_RES/menu" "$SETTINGS_RES/values"

cat > "$SETTINGS_RES/layout/hide_developer_status_layout.xml" << 'EOF'
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

cat > "$SETTINGS_RES/layout/hide_developer_status_list_item.xml" << 'EOF'
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

cat > "$SETTINGS_RES/menu/hide_developer_status_menu.xml" << 'EOF'
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

echo "Appending strings and arrays..."
# Append to strings.xml just before </resources>
STRINGS_XML="$SETTINGS_RES/values/strings.xml"
if ! grep -q "hide_developer_status_title" "$STRINGS_XML"; then
    sed -i '/<\/resources>/i \    <!-- Hide developer status -->\n    <string name="hide_developer_status_title">Hide developer status</string>\n    <string name="hide_developer_status_summary">Hide developer status from apps</string>\n    <string name="menu_show_system">Show system applications</string>\n    <string name="menu_hide_system">Hide system applications</string>' "$STRINGS_XML"
fi

ARRAYS_XML="$SETTINGS_RES/values/arrays.xml"
if ! grep -q "hide_developer_status_hidden_apps" "$ARRAYS_XML"; then
    sed -i '/<\/resources>/i \    <!-- Apps list to hide from Hide developer status setting -->\n    <string-array name="hide_developer_status_hidden_apps" translatable="false">\n        <item>android</item>\n        <item>com.android.settings</item>\n        <item>com.android.systemui</item>\n        <item>com.android.shell</item>\n    </string-array>' "$ARRAYS_XML"
fi

echo "Creating Settings source files..."
SETTINGS_SRC="$TOP/packages/apps/Settings/src/com/android/settings/security"
mkdir -p "$SETTINGS_SRC"

cat > "$SETTINGS_SRC/HideDeveloperStatusSettings.kt" << 'EOF'
/*
 * Copyright (C) 2021 AOSP-Krypton Project
 *           (C) 2022 Nameless-AOSP Project
 *           (C) 2022 Paranoid Android
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

package com.android.settings.security

import android.annotation.SuppressLint
import android.app.ActivityManager
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.UserInfo
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.os.UserManager
import android.provider.Settings
import android.view.Menu
import android.view.MenuInflater
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.widget.CheckBox
import android.widget.ImageView
import android.widget.SearchView
import android.widget.TextView

import androidx.core.view.ViewCompat
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView

import com.android.internal.util.pixelos.HideDeveloperStatusUtils

import com.android.settings.R

import com.google.android.material.appbar.AppBarLayout

class HideDeveloperStatusSettings: Fragment(R.layout.hide_developer_status_layout) {

    private lateinit var activityManager: ActivityManager
    private lateinit var packageManager: PackageManager
    private lateinit var recyclerView: RecyclerView
    private lateinit var adapter: AppListAdapter
    private lateinit var packageList: List<PackageInfo>
    private lateinit var userManager: UserManager
    private lateinit var userInfos: List<UserInfo>

    private var appBarLayout: AppBarLayout? = null
    private var searchText = ""
    private var customFilter: ((PackageInfo) -> Boolean)? = null
    private var comparator: ((PackageInfo, PackageInfo) -> Int)? = null
    private var hideDeveloperStatusUtils: HideDeveloperStatusUtils = HideDeveloperStatusUtils()
    private var showSystem = false
    private var optionsMenu: Menu? = null

    override fun onStart() {
        super.onStart()
        updateOptionsMenu()
        val host = getActivity()
        if (host != null) {
            host.invalidateOptionsMenu();
        }
    }

    @SuppressLint("QueryPermissionsNeeded")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setHasOptionsMenu(true)
        requireActivity().setTitle(getTitle())
        appBarLayout = requireActivity().findViewById(R.id.app_bar)
        activityManager = requireContext().getSystemService(ActivityManager::class.java) as ActivityManager
        packageManager = requireContext().packageManager
        packageList = packageManager.getInstalledPackages(PackageManager.MATCH_ANY_USER)
        userManager = UserManager.get(requireContext())
        userInfos = userManager.getUsers()
        for (info in userInfos) {
            hideDeveloperStatusUtils.setApps(requireContext(), info.id)
        }
    }

    private fun getTitle(): Int {
        return R.string.hide_developer_status_title
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        adapter = AppListAdapter()
        recyclerView = view.findViewById<RecyclerView>(R.id.apps_list).also {
            it!!.layoutManager = LinearLayoutManager(context)
            it!!.adapter = adapter
        } as RecyclerView
        refreshList()
    }

    private fun getInitialCheckedList(): List<String> {
        val flattenedString = Settings.Secure.getString(
            requireContext().contentResolver, getKey()
        )
        return flattenedString?.takeIf {
            it.isNotBlank()
        }?.split(",")?.toList() ?: emptyList()
    }

    override fun onCreateOptionsMenu(menu: Menu, inflater: MenuInflater) {
        val activity = getActivity()
        if (activity == null) {
            return;
        }
        optionsMenu = menu;
        inflater.inflate(R.menu.hide_developer_status_menu, menu)

        menu.findItem(R.id.show_system).setVisible(!showSystem)
        menu.findItem(R.id.hide_system).setVisible(showSystem)

        val searchMenuItem = menu.findItem(R.id.search) as MenuItem
        searchMenuItem.setOnActionExpandListener(object: MenuItem.OnActionExpandListener {
            override fun onMenuItemActionExpand(item: MenuItem): Boolean {
                appBarLayout!!.setExpanded(false, false)
                ViewCompat.setNestedScrollingEnabled(recyclerView, false)
                return true
            }

            override fun onMenuItemActionCollapse(item: MenuItem): Boolean {
                appBarLayout!!.setExpanded(false, false)
                ViewCompat.setNestedScrollingEnabled(recyclerView, true)
                return true
            }
        })
        val searchView = searchMenuItem.actionView as SearchView
        searchView.queryHint = getString(R.string.search_apps)
        searchView.setOnQueryTextListener(object: SearchView.OnQueryTextListener {
            override fun onQueryTextSubmit(query: String) = false
            override fun onQueryTextChange(newText: String): Boolean {
                searchText = newText
                refreshList()
                return true
            }
        })
        updateOptionsMenu()
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        var i = item.getItemId()
        if (i == R.id.show_system || i == R.id.hide_system) {
            showSystem = !showSystem;
            refreshList();
        }
        updateOptionsMenu()
        return true
    }

    override fun onPrepareOptionsMenu(menu: Menu) {
        updateOptionsMenu()
    }

    override fun onDestroyOptionsMenu() {
        optionsMenu = null;
    }

    private fun updateOptionsMenu() {
        if (optionsMenu == null) return;
        var menu = optionsMenu as Menu
        menu.findItem(R.id.show_system).setVisible(!showSystem)
        menu.findItem(R.id.hide_system).setVisible(showSystem)
    }

    private fun onListUpdate(packageName: String, isChecked: Boolean) {
        if (packageName.isBlank()) return
        for (info in userInfos) {
            if (isChecked) {
                hideDeveloperStatusUtils.addApp(requireContext(), packageName, info.id)
            } else {
                hideDeveloperStatusUtils.removeApp(requireContext(), packageName, info.id)
            }
        }
        try {
            activityManager.forceStopPackage(packageName)
        } catch (ignored: Exception) {
        }
    }

    private fun getKey(): String {
        return "hide_developer_status"
    }

    private fun refreshList() {
        var list = packageList.filter {
            if (!showSystem) {
                !it.applicationInfo!!.isSystemApp()
                && !resources.getStringArray(
                        R.array.hide_developer_status_hidden_apps)
                            .asList().contains(it.applicationInfo!!.packageName)
                && !it.applicationInfo!!.packageName.contains("android.settings")
            } else {
                !resources.getStringArray(
                    R.array.hide_developer_status_hidden_apps)
                        .asList().contains(it.applicationInfo!!.packageName)
                && !it.applicationInfo!!.packageName.contains("android.settings")
                && !it.applicationInfo!!.isResourceOverlay()
            }
        }.filter {
            getLabel(it).contains(searchText, true)
        }
        list = customFilter?.let { customFilter ->
            list.filter {
                customFilter(it)
            }
        } ?: list
        list = comparator?.let {
            list.sortedWith(it)
        } ?: list.sortedWith { a, b ->
            getLabel(a).compareTo(getLabel(b))
        }
        if (::adapter.isInitialized) adapter.submitList(list.map { appInfoFromPackageInfo(it) })
    }

    private fun appInfoFromPackageInfo(packageInfo: PackageInfo) =
        AppInfo(
            packageInfo.packageName,
            getLabel(packageInfo),
            packageInfo.applicationInfo!!.loadIcon(packageManager),
        )

    private fun getLabel(packageInfo: PackageInfo) =
        packageInfo.applicationInfo!!.loadLabel(packageManager).toString()

    private inner class AppListAdapter: ListAdapter<AppInfo, AppListViewHolder>(itemCallback) {
        private val selectedIndices = mutableSetOf<Int>()
        private var initialList = getInitialCheckedList().toMutableList()

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            AppListViewHolder(layoutInflater.inflate(
                R.layout.hide_developer_status_list_item, parent, false))

        override fun onBindViewHolder(holder: AppListViewHolder, position: Int) {
            getItem(position).let {
                holder.label!!.text = it.label
                holder.packageName!!.text = it.packageName
                holder.icon!!.setImageDrawable(it.icon)
                holder.itemView!!.setOnClickListener {
                    if (selectedIndices.contains(position)) {
                        selectedIndices.remove(position)
                        onListUpdate(holder.packageName!!.text.toString(), false)
                    } else {
                        selectedIndices.add(position)
                        onListUpdate(holder.packageName!!.text.toString(), true)
                    }
                    notifyItemChanged(position)
                }
                if (initialList.contains(it.packageName)) {
                    initialList.remove(it.packageName)
                    selectedIndices.add(position)
                }
                holder.checkBox!!.isChecked = selectedIndices.contains(position)
            }
        }

        override fun submitList(list: List<AppInfo>?) {
            initialList = getInitialCheckedList().toMutableList()
            selectedIndices.clear()
            super.submitList(list)
        }
    }

    private class AppListViewHolder(itemView: View): RecyclerView.ViewHolder(itemView) {
        val icon: ImageView? = itemView.findViewById(R.id.icon)
        val label: TextView? = itemView.findViewById(R.id.label)
        val packageName: TextView? = itemView.findViewById(R.id.packageName)
        val checkBox: CheckBox? = itemView.findViewById(R.id.checkBox)
    }

    private data class AppInfo(
        val packageName: String,
        val label: String,
        val icon: Drawable,
    )

    companion object {
        private val itemCallback = object: DiffUtil.ItemCallback<AppInfo>() {
            override fun areItemsTheSame(oldInfo: AppInfo, newInfo: AppInfo) =
                oldInfo.packageName == newInfo.packageName

            override fun areContentsTheSame(oldInfo: AppInfo, newInfo: AppInfo) =
                oldInfo == newInfo
        }
    }
}
EOF

cat > "$SETTINGS_SRC/HideDeveloperStatusPreferenceController.java" << 'EOF'
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

package com.android.settings.security;

import android.content.Context;
import android.content.pm.UserInfo;
import android.provider.Settings;
import android.os.UserManager;

import com.android.settings.core.BasePreferenceController;

import com.android.internal.util.pixelos.HideDeveloperStatusUtils;

import java.util.List;

public class HideDeveloperStatusPreferenceController extends BasePreferenceController {

    private static final String PREF_KEY = "hide_developer_status_settings";
    private static HideDeveloperStatusUtils hideDeveloperStatusUtils = new HideDeveloperStatusUtils();

    private UserManager userManager;
    private List<UserInfo> userInfos;

    public HideDeveloperStatusPreferenceController(Context context) {
        super(context, PREF_KEY);
        userManager = UserManager.get(context);
        userInfos = userManager.getUsers();
        for (UserInfo info: userInfos) {
            hideDeveloperStatusUtils.setApps(context, info.id);
        }
    }

    @Override
    public int getAvailabilityStatus() {
        return AVAILABLE;
    }
}
EOF

echo "Patching security_advanced_settings.xml..."
SEC_XML="$SETTINGS_RES/xml/security_advanced_settings.xml"
if ! grep -q "hide_developer_status_settings" "$SEC_XML"; then
    # Add preference to the bottom of the screen
    sed -i '/<\/PreferenceScreen>/i \    <Preference\n        android:key="hide_developer_status_settings"\n        android:title="@string/hide_developer_status_title"\n        android:summary="@string/hide_developer_status_summary"\n        android:fragment="com.android.settings.security.HideDeveloperStatusSettings"\n        settings:controller="com.android.settings.security.HideDeveloperStatusPreferenceController" />' "$SEC_XML"
fi

echo "Done! Please verify patches in SettingsProvider.java explicitly."
EOF
