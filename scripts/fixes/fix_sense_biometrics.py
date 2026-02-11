#!/usr/bin/env python3
# Fix ParanoidSense biometrics references in FaceService and AuthService after removing sense/.
# Run from BUILD_DIR (Android tree root).

import re
import os

def main():
    top = os.environ.get("ANDROID_BUILD_TOP", os.getcwd())
    os.chdir(top)

    faceservice = "frameworks/base/services/core/java/com/android/server/biometrics/sensors/face/FaceService.java"
    if os.path.exists(faceservice):
        with open(faceservice, "r") as f:
            content = f.read()
        content = re.sub(r"import com\.android\.server\.biometrics\.sensors\.face\.sense\.SenseProvider;\n", "", content)
        content = re.sub(r"import com\.android\.server\.biometrics\.sensors\.face\.sense\.SenseUtils;\n", "", content)
        content = content.replace("SenseUtils.canUseProvider()", "false")
        content = content.replace("providers.addAll(getSenseProviders());", "// Sense provider disabled")
        content = re.sub(r"\n\s*private List<ServiceProvider> getSenseProviders\(\) \{[\s\S]*?\n\s{8}\}", "", content)
        with open(faceservice, "w") as f:
            f.write(content)
        print(f"Fixed {faceservice}")

    authservice = "frameworks/base/services/core/java/com/android/server/biometrics/AuthService.java"
    if os.path.exists(authservice):
        with open(authservice, "r") as f:
            content = f.read()
        content = re.sub(r"import com\.android\.server\.biometrics\.sensors\.face\.sense\.SenseUtils;\n", "", content)
        content = content.replace("SenseUtils.canUseProvider()", "false")
        with open(authservice, "w") as f:
            f.write(content)
        print(f"Fixed {authservice}")

if __name__ == "__main__":
    main()
