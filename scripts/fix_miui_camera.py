import os
import sys

# Define constants
DEVICE_DIR = "device/xiaomi/xaga"
FRAMEWORK_DIR = os.path.join(DEVICE_DIR, "miuiframework")
JAVA_DIR = os.path.join(FRAMEWORK_DIR, "core/java/miui/process")
BP_FILE = os.path.join(FRAMEWORK_DIR, "Android.bp")
JAVA_FILE = os.path.join(JAVA_DIR, "ProcessManager.java")
MAKEFILE = os.path.join(DEVICE_DIR, "custom_xaga.mk")

def create_directory_structure():
    print(f"Creating directory: {JAVA_DIR}")
    os.makedirs(JAVA_DIR, exist_ok=True)

def create_java_file():
    print(f"Creating Java stub: {JAVA_FILE}")
    java_content = """package miui.process;

import java.util.List;
import android.util.Log;

/**
 * Stub implementation of miui.process.ProcessManager for PixelOS (Xaga)
 * Required by MIUI Camera app to prevent ClassNotFoundException.
 */
public class ProcessManager {
    private static final String TAG = "ProcessManagerStub";

    public static final int AI_MAX_ADJ = 0;
    public static final int AI_MAX_PROTECT_TIME = 0;

    public static boolean isLockedApplication(String packageName, int userId) {
        Log.d(TAG, "isLockedApplication called for " + packageName);
        return false;
    }

    public static void adjBoost(String processName, int targetAdj, long timeout, int userId) {
        Log.d(TAG, "adjBoost called for " + processName + " targetAdj=" + targetAdj);
    }

    public static void updateCloudData(List<String> whiteList) {
        Log.d(TAG, "updateCloudData called");
    }

    public static void registerForegroundInfoListener(IForegroundInfoListener listener) {
        Log.d(TAG, "registerForegroundInfoListener called");
    }

    public static void unregisterForegroundInfoListener(IForegroundInfoListener listener) {
        Log.d(TAG, "unregisterForegroundInfoListener called");
    }
    
    // Inner interface stub
    public interface IForegroundInfoListener {
        void onForegroundInfoChanged(ForegroundInfo foregroundInfo);
    }
    
    // Inner class stub
    public static class ForegroundInfo {
        public String mForegroundPackageName;
        public int mForegroundUid;
    }
}
"""
    with open(JAVA_FILE, "w") as f:
        f.write(java_content)

def create_bp_file():
    print(f"Creating Android.bp: {BP_FILE}")
    bp_content = """java_library {
    name: "miui-framework",
    installable: true,
    srcs: ["core/java/**/*.java"],
    sdk_version: "current",
}
"""
    with open(BP_FILE, "w") as f:
        f.write(bp_content)

def update_makefile():
    print(f"Updating makefile: {MAKEFILE}")
    
    if not os.path.exists(MAKEFILE):
        print(f"Error: {MAKEFILE} not found!")
        return

    with open(MAKEFILE, "r") as f:
        content = f.read()

    if "miui-framework" in content:
        print("miui-framework already present in makefile. Skipping.")
        return

    # Append to PRODUCT_PACKAGES using a safe approach
    # We look for the end of the file and append the new package
    new_content = content + "\n# Added by fix_miui_camera.py\nPRODUCT_PACKAGES += miui-framework\n"
    
    with open(MAKEFILE, "w") as f:
        f.write(new_content)
    print("Successfully updated PRODUCT_PACKAGES.")

def main():
    base_dir = os.getcwd()
    print(f"Running fix from: {base_dir}")
    
    # Check if we are in the root of the repo (or reasonably close)
    if not os.path.exists("device/xiaomi/xaga"):
        # Try to find the root if we are in scripts/
        if os.path.exists("../device/xiaomi/xaga"):
            os.chdir("..")
            print("Changed directory to repo root.")
        else:
            print("Error: Could not find device/xiaomi/xaga. Run this script from the repo root.")
            return

    create_directory_structure()
    create_java_file()
    create_bp_file()
    update_makefile()
    
    print("\nFix applied successfully!")
    print("Now run 'm pixelos' (or 'm fb_package' if testing fastboot update) to rebuild.")

if __name__ == "__main__":
    main()
