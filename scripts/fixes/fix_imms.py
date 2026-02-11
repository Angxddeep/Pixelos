#!/usr/bin/env python3
# Stub out LineageHardwareManager in InputMethodManagerService (optional; currently disabled in build).
# Run from BUILD_DIR (Android tree root).

import re
import os

def main():
    top = os.environ.get("ANDROID_BUILD_TOP", os.getcwd())
    os.chdir(top)
    imms = "frameworks/base/services/core/java/com/android/server/inputmethod/InputMethodManagerService.java"
    if not os.path.exists(imms):
        return
    with open(imms, "r") as f:
        content = f.read()
    content = re.sub(r"import com\.android\.internal\.lineage\.hardware\.LineageHardwareManager;\n", "", content)
    content = re.sub(r"\s*private LineageHardwareManager mLineageHardware;\n", "\n", content)
    content = re.sub(r"\s*mLineageHardware = LineageHardwareManager\.getInstance\(mContext\);\n", "\n", content)
    content = re.sub(r"mLineageHardware\.isSupported\(\s*LineageHardwareManager\.FEATURE_HIGH_TOUCH_POLLING_RATE\)", "false", content)
    content = re.sub(r"mLineageHardware\.isSupported\(\s*LineageHardwareManager\.FEATURE_HIGH_TOUCH_SENSITIVITY\)", "false", content)
    content = re.sub(r"mLineageHardware\.isSupported\(LineageHardwareManager\.FEATURE_TOUCH_HOVERING\)", "false", content)
    content = re.sub(r"mLineageHardware\.set\(LineageHardwareManager\.FEATURE_HIGH_TOUCH_POLLING_RATE, enabled\);", "// LineageOS touch polling disabled", content)
    content = re.sub(r"mLineageHardware\.set\(LineageHardwareManager\.FEATURE_HIGH_TOUCH_SENSITIVITY, enabled\);", "// LineageOS touch sensitivity disabled", content)
    content = re.sub(r"mLineageHardware\.set\(LineageHardwareManager\.FEATURE_TOUCH_HOVERING, enabled\);", "// LineageOS touch hovering disabled", content)
    with open(imms, "w") as f:
        f.write(content)
    print(f"Fixed {imms}")

if __name__ == "__main__":
    main()
