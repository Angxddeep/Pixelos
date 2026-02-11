#!/bin/bash
#
# Optional Patch: Add fastboot package build support
# Adapted from AresOS commit 19afe7c for PixelOS vendor/custom
# Source: https://github.com/AresOS-UDC/vendor_lineage/commit/19afe7c7e98c9ff5f57c57d09edfa954142e65b6
#
# Usage: Run from the PixelOS source root (~/pixelos)
#   bash scripts/apply_fb_package_patch.sh
#
# After applying, build the fastboot package with:
#   m fb_package
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Ensure we're in the source root
if [[ ! -d "vendor/custom" ]]; then
    print_error "vendor/custom not found. Run this from the PixelOS source root."
    exit 1
fi

# =============================================================================
# 0. Copy fastboot tools to build root
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
FASTBOOT_SRC="$REPO_ROOT/fastboot"
FASTBOOT_DEST="./fastboot"

print_info "Checking for fastboot tools..."

if [ -d "$FASTBOOT_SRC" ]; then
    if [ ! -d "$FASTBOOT_DEST" ]; then
        print_info "Copying fastboot tools from $FASTBOOT_SRC to $FASTBOOT_DEST..."
        cp -r "$FASTBOOT_SRC" "$FASTBOOT_DEST"
        print_success "Copied fastboot tools."
    else
        print_info "Fastboot tools already exist at $FASTBOOT_DEST. Syncing..."
        cp -r "$FASTBOOT_SRC/"* "$FASTBOOT_DEST/"
        print_success "Synced fastboot tools."
    fi
else
    print_warn "Could not find fastboot tools at $FASTBOOT_SRC"
fi

# =============================================================================
# 1. Discover PixelOS version variables
# =============================================================================

print_info "Discovering PixelOS version variables..."

# Find the version makefile
VERSION_MK=""
for f in vendor/custom/config/version.mk vendor/custom/config/custom_version.mk vendor/custom/config/common.mk; do
    if [[ -f "$f" ]]; then
        VERSION_MK="$f"
        break
    fi
done

if [[ -z "$VERSION_MK" ]]; then
    print_warn "Could not find version makefile, using fallback naming"
fi

print_info "Version makefile: ${VERSION_MK:-not found}"

# =============================================================================
# 2. Create fb_package.mk
# =============================================================================

print_info "Creating vendor/custom/build/tasks/fb_package.mk..."

mkdir -p vendor/custom/build/tasks

cat > vendor/custom/build/tasks/fb_package.mk << 'EOFMK'
# Fastboot package build target
# Adapted from AresOS for PixelOS
# Usage: m fb_package (after a successful m pixelos build)

# Construct the output filename using the build number
PIXELOS_FB_PACKAGE := $(PRODUCT_OUT)/$(shell date +%Y%m%d-%H%M).zip
FB_GEN_DIR := $(PRODUCT_OUT)/fastboot_gen

# Path to fastboot tools (injected by apply_fb_package_patch.sh)
PIXELOS_FASTBOOT_DIR := __FASTBOOT_DIR__

# All images to include in the package (matches AresOS reference layout)
FB_PACKAGE_IMAGES := \
    apusys.img audio_dsp.img boot.img ccu.img dpm.img dtbo.img \
    gpueb.img gz.img lk.img mcf_ota.img mcupm.img md1img.img \
    mvpu_algo.img pi_img.img scp.img spmfw.img sspm.img tee.img \
    vcp.img vbmeta.img vbmeta_system.img vbmeta_vendor.img \
    vendor_boot.img super.img unsparse_super_empty.img

.PHONY: fb_package
fb_package: $(BUILT_TARGET_FILES_PACKAGE)
	$(call pretty,"Package fastboot: $(PIXELOS_FB_PACKAGE)")
	$(hide) if [ ! -f "$(PRODUCT_OUT)/super.img" ]; then \
		echo "=== Building super.img ==="; \
		$(HOST_OUT_EXECUTABLES)/build_super_image -v $(PRODUCT_OUT)/obj/PACKAGING/target_files_intermediates/$(TARGET_PRODUCT)-target_files/META/misc_info.txt $(PRODUCT_OUT)/super.img; \
	fi
	$(hide) rm -rf $(FB_GEN_DIR)
	$(hide) mkdir -p $(FB_GEN_DIR)/images
	@echo "=== Collecting images from build output ==="
	$(hide) for img in $(FB_PACKAGE_IMAGES); do \
		if [ -f "$(PRODUCT_OUT)/$$img" ]; then \
			echo "  ✓ $$img"; \
			cp $(PRODUCT_OUT)/$$img $(FB_GEN_DIR)/images/$$img; \
		else \
			echo "  ✗ $$img (not found, skipping)"; \
		fi; \
	done
	$(hide) if [ -f "$(PRODUCT_OUT)/preloader_xaga.bin" ]; then \
		echo "  ✓ preloader_xaga.bin"; \
		cp $(PRODUCT_OUT)/preloader_xaga.bin $(FB_GEN_DIR)/images/preloader_xaga.bin; \
	else \
		echo "  ✗ preloader_xaga.bin (not found, skipping)"; \
	fi
	@echo "=== Copying fastboot tools ==="
	$(hide) if [ -d "$(PIXELOS_FASTBOOT_DIR)" ]; then \
		cp -r $(PIXELOS_FASTBOOT_DIR)/tools $(FB_GEN_DIR)/tools; \
		cp $(PIXELOS_FASTBOOT_DIR)/linux_installation.sh $(FB_GEN_DIR)/linux_installation.sh; \
		cp $(PIXELOS_FASTBOOT_DIR)/win_installation.bat $(FB_GEN_DIR)/win_installation.bat; \
		chmod +x $(FB_GEN_DIR)/linux_installation.sh; \
	elif [ -d "$(TOP)/fastboot" ]; then \
		cp -r $(TOP)/fastboot/tools $(FB_GEN_DIR)/tools; \
		cp $(TOP)/fastboot/linux_installation.sh $(FB_GEN_DIR)/linux_installation.sh; \
		cp $(TOP)/fastboot/win_installation.bat $(FB_GEN_DIR)/win_installation.bat; \
		chmod +x $(FB_GEN_DIR)/linux_installation.sh; \
	else \
		echo "ERROR: fastboot tools not found!"; \
		exit 1; \
	fi
	@echo "=== Creating ZIP package ==="
	$(hide) cd $(FB_GEN_DIR) && zip -r $(abspath $(PIXELOS_FB_PACKAGE)) .
	$(hide) ln -sf $(notdir $(PIXELOS_FB_PACKAGE)) $(PRODUCT_OUT)/latest-fastboot.zip
	$(hide) rm -rf $(FB_GEN_DIR)
	@echo ""
	@echo "=== Package contents ==="
	@unzip -l $(PIXELOS_FB_PACKAGE) | tail -n +4 | head -n -2
	@echo ""
	@echo "Package Complete: $(PIXELOS_FB_PACKAGE)" >&2
EOFMK

# Inject the actual absolute path of the fastboot tools directory
sed -i "s|__FASTBOOT_DIR__|${FASTBOOT_SRC}|g" vendor/custom/build/tasks/fb_package.mk

print_success "Created fb_package.mk (fastboot tools path: $FASTBOOT_SRC)"

# =============================================================================
# 3. Create Android.bp for img_from_target_files_extended
# =============================================================================

print_info "Creating vendor/custom/build/tools/releasetools/Android.bp..."

mkdir -p vendor/custom/build/tools/releasetools

cat > vendor/custom/build/tools/releasetools/Android.bp << 'EOFBP'
// Copyright (C) 2019 The Android Open Source Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//
// Module-specific defaults.
//
// For module X, if we need to build it both as a library and an executable:
//  - A default rule `releasetools_X_defaults` is created, which lists `srcs`, `libs` and
//    `required` properties.
//  - `python_library_host` and `python_binary_host` are created by listing
//    `releasetools_X_defaults` in their defaults.
//

package {
    default_applicable_licenses: ["Android-Apache-2.0"],
}

python_defaults {
    name: "releasetools_img_from_target_files_extended_defaults",
    srcs: [
        "img_from_target_files_extended.py",
    ],
    libs: [
        "releasetools_build_super_image",
        "releasetools_common",
    ],
}

python_library_host {
    name: "releasetools_img_from_target_files_extended",
    defaults: [
        "releasetools_img_from_target_files_extended_defaults",
    ],
}

python_binary_host {
    name: "img_from_target_files_extended",
    defaults: [
        "releasetools_binary_defaults",
        "releasetools_img_from_target_files_extended_defaults",
    ],
}
EOFBP

print_success "Created Android.bp"

# =============================================================================
# 4. Create img_from_target_files_extended.py
# =============================================================================

print_info "Creating vendor/custom/build/tools/releasetools/img_from_target_files_extended.py..."

cat > vendor/custom/build/tools/releasetools/img_from_target_files_extended.py << 'EOFPY'
#!/usr/bin/env python
#
# Copyright (C) 2008 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Given an input target-files, produces an image zipfile suitable for use with
'fastboot update'.

Usage: img_from_target_files [flags] input_target_files output_image_zip

input_target_files: Path to the input target_files zip.

Flags:
  -z (--bootable_zip)
      Include only the bootable images (eg 'boot' and 'recovery') in
      the output.

  --additional <filespec>
      Include an additional entry into the generated zip file. The filespec is
      in a format that's accepted by zip2zip (e.g.
      'OTA/android-info.txt:android-info.txt', to copy `OTA/android-info.txt`
      from input_file into output_file as `android-info.txt`. Refer to the
      `filespec` arg in zip2zip's help message). The option can be repeated to
      include multiple entries.

  --additional_zip <zippath>
      Include an additional zip into the generated zip file.
      The option can be repeated to include multiple entries.

  --images_path <path>
      Specify a path in the generated zip where images will be stored.

  --exclude_android_info
      Exclude android-info.txt file from the generated zip.
"""

from __future__ import print_function

import logging
import os
import sys
import zipfile

import common
from build_super_image import BuildSuperImage

if sys.hexversion < 0x02070000:
    print('Python 2.7 or newer is required.', file=sys.stderr)
    sys.exit(1)

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS

OPTIONS.additional_entries = []
OPTIONS.additional_zip_entries = []
OPTIONS.bootable_only = False
OPTIONS.put_super = None
OPTIONS.put_bootloader = None
OPTIONS.dynamic_partition_list = None
OPTIONS.super_device_list = None
OPTIONS.retrofit_dap = None
OPTIONS.build_super = None
OPTIONS.sparse_userimages = None
OPTIONS.images_path = ''
OPTIONS.include_android_info = True

def LoadOptions(input_file):
    """Loads information from input_file to OPTIONS.

    Args:
        input_file: Path to the input target_files zip file.
    """
    with zipfile.ZipFile(input_file) as input_zip:
        info = OPTIONS.info_dict = common.LoadInfoDict(input_zip)

    OPTIONS.put_super = info.get('super_image_in_update_package') == 'true'
    OPTIONS.put_bootloader = info.get('bootloader_in_update_package') == 'true'
    OPTIONS.dynamic_partition_list = info.get('dynamic_partition_list',
                                              '').strip().split()
    OPTIONS.super_device_list = info.get('super_block_devices',
                                         '').strip().split()
    OPTIONS.retrofit_dap = info.get('dynamic_partition_retrofit') == 'true'
    OPTIONS.build_super = info.get('build_super_partition') == 'true'
    OPTIONS.sparse_userimages = bool(info.get('extfs_sparse_flag'))


def CopyZipEntries(input_file, output_file, entries):
    """Copies ZIP entries between input and output files.

    Args:
        input_file: Path to the input target_files zip.
        output_file: Output filename.
        entries: A list of entries to copy, in a format that's accepted by zip2zip
            (e.g. 'OTA/android-info.txt:android-info.txt', which copies
            `OTA/android-info.txt` from input_file into output_file as
            `android-info.txt`. Refer to the `filespec` arg in zip2zip's help
            message).
    """
    logger.info('Writing %d entries to archive...', len(entries))
    cmd = ['zip2zip', '-i', input_file, '-o', output_file]
    cmd.extend(entries)
    common.RunAndCheckOutput(cmd)

def MergeZips(input_files, output_file):
    """Merges several ZIPs into one.

    Args:
        input_file: Pathes to the input zips.
        output_file: Output filename.
    """
    cmd = ['merge_zips', output_file]
    cmd.extend(input_files)
    common.RunAndCheckOutput(cmd)

def EntriesForUserImages(input_file):
    """Returns the user images entries to be copied.

    Args:
        input_file: Path to the input target_files zip file.
    """
    dynamic_images = [p + '.img' for p in OPTIONS.dynamic_partition_list]

    # Filter out system_other for launch DAP devices because it is in super image.
    if not OPTIONS.retrofit_dap and 'system' in OPTIONS.dynamic_partition_list:
        dynamic_images.append('system_other.img')

    entries = []
    if OPTIONS.include_android_info:
        entries.append('OTA/android-info.txt:android-info.txt')
    with zipfile.ZipFile(input_file) as input_zip:
        namelist = input_zip.namelist()

    for image_path in [name for name in namelist if name.startswith('IMAGES/')]:
        image = os.path.basename(image_path)
        if OPTIONS.bootable_only and image not in('boot.img', 'recovery.img', 'bootloader', 'init_boot.img'):
            continue
        if not image.endswith('.img') and image != 'bootloader':
            continue
        if image == 'bootloader' and not OPTIONS.put_bootloader:
            continue
        # Filter out super_empty and the images that are already in super partition.
        if OPTIONS.put_super:
            if image == 'super_empty.img':
                continue
            if image in dynamic_images:
                continue
        entries.append('{}:{}'.format(image_path, OPTIONS.images_path + image))
    return entries


def EntriesForSplitSuperImages(input_file):
    """Returns the entries for split super images.

    This is only done for retrofit dynamic partition devices.

    Args:
        input_file: Path to the input target_files zip file.
    """
    with zipfile.ZipFile(input_file) as input_zip:
        namelist = input_zip.namelist()
    entries = []
    for device in OPTIONS.super_device_list:
        image = 'OTA/super_{}.img'.format(device)
        assert image in namelist, 'Failed to find {}'.format(image)
        entries.append('{}:{}'.format(image, OPTIONS.images_path + os.path.basename(image)))
    return entries


def RebuildAndWriteSuperImages(input_file, output_file):
    """Builds and writes super images to the output file."""
    logger.info('Building super image...')

    # We need files under IMAGES/, OTA/, META/ for img_from_target_files.py.
    # However, common.LoadInfoDict() may read additional files under BOOT/,
    # RECOVERY/ and ROOT/. So unzip everything from the target_files.zip.
    input_tmp = common.UnzipTemp(input_file)

    super_file = common.MakeTempFile('super_', '.img')
    BuildSuperImage(input_tmp, super_file)

    logger.info('Writing super.img to archive...')
    with zipfile.ZipFile(
        output_file, 'a', compression=zipfile.ZIP_DEFLATED,
        allowZip64=True) as output_zip:
        common.ZipWrite(output_zip, super_file, OPTIONS.images_path + 'super.img')


def ImgFromTargetFiles(input_file, output_file):
    """Creates an image archive from the input target_files zip.

    Args:
        input_file: Path to the input target_files zip.
        output_file: Output filename.

    Raises:
        ValueError: On invalid input.
    """
    if not os.path.exists(input_file):
        raise ValueError('%s is not exist' % input_file)

    if not zipfile.is_zipfile(input_file):
        raise ValueError('%s is not a valid zipfile' % input_file)

    logger.info('Building image zip from target files zip.')

    LoadOptions(input_file)

    # Entries to be copied into the output file.
    entries = EntriesForUserImages(input_file)

    # Only for devices that retrofit dynamic partitions there're split super
    # images available in the target_files.zip.
    rebuild_super = False
    if OPTIONS.build_super and OPTIONS.put_super:
        if OPTIONS.retrofit_dap:
            entries += EntriesForSplitSuperImages(input_file)
        else:
            rebuild_super = True

    # Any additional entries provided by caller.
    entries += OPTIONS.additional_entries

    CopyZipEntries(input_file, output_file, entries)

    os.rename(output_file, output_file + '.temp')
    MergeZips(OPTIONS.additional_zip_entries + [output_file + '.temp'], output_file)
    os.remove(output_file + '.temp')

    if rebuild_super:
        RebuildAndWriteSuperImages(input_file, output_file)


def main(argv):

    def option_handler(o, a):
        if o in ('-z', '--bootable_zip'):
            OPTIONS.bootable_only = True
        elif o == '--additional':
            OPTIONS.additional_entries.append(a)
        elif o == '--additional_zip':
            OPTIONS.additional_zip_entries.append(a)
        elif o in ('-z', '--images_path'):
            OPTIONS.images_path = a + '/'
        elif o == '--exclude_android_info':
            OPTIONS.include_android_info = False
        else:
            return False
        return True

    args = common.ParseOptions(argv, __doc__,
                               extra_opts='z',
                               extra_long_opts=[
                                   'additional=',
                                   'bootable_zip',
                                   'additional_zip=',
                                   'images_path=',
                                   'exclude_android_info',
                               ],
                               extra_option_handler=option_handler)
    if len(args) != 2:
        common.Usage(__doc__)
        sys.exit(1)

    common.InitLogging()

    ImgFromTargetFiles(args[0], args[1])

    logger.info('done.')


if __name__ == '__main__':
    try:
        common.CloseInheritedPipes()
        main(sys.argv[1:])
    finally:
        common.Cleanup()
EOFPY

print_success "Created img_from_target_files_extended.py"

# =============================================================================
# 5. Modify config.mk to add IMG_FROM_TARGET_FILES_EXTENDED variable
# =============================================================================

print_info "Updating vendor/custom/build/core/config.mk..."

CONFIG_MK="vendor/custom/build/core/config.mk"
if [[ -f "$CONFIG_MK" ]]; then
    if ! grep -q "IMG_FROM_TARGET_FILES_EXTENDED" "$CONFIG_MK"; then
        echo "" >> "$CONFIG_MK"
        echo "IMG_FROM_TARGET_FILES_EXTENDED := \$(HOST_OUT_EXECUTABLES)/img_from_target_files_extended\$(HOST_EXECUTABLE_SUFFIX)" >> "$CONFIG_MK"
        print_success "Updated config.mk"
    else
        print_info "config.mk already has IMG_FROM_TARGET_FILES_EXTENDED"
    fi
else
    print_warn "config.mk not found at $CONFIG_MK"
    print_info "Searching for config.mk in vendor/custom/build/..."
    FOUND_CONFIG=$(find vendor/custom/build/ -name "config.mk" -type f 2>/dev/null | head -1)
    if [[ -n "$FOUND_CONFIG" ]]; then
        print_info "Found: $FOUND_CONFIG"
        echo "" >> "$FOUND_CONFIG"
        echo "IMG_FROM_TARGET_FILES_EXTENDED := \$(HOST_OUT_EXECUTABLES)/img_from_target_files_extended\$(HOST_EXECUTABLE_SUFFIX)" >> "$FOUND_CONFIG"
        print_success "Updated $FOUND_CONFIG"
    else
        print_warn "No config.mk found. Creating one..."
        mkdir -p vendor/custom/build/core
        cat > "$CONFIG_MK" << 'EOFCFG'
# PixelOS custom build config

IMG_FROM_TARGET_FILES_EXTENDED := $(HOST_OUT_EXECUTABLES)/img_from_target_files_extended$(HOST_EXECUTABLE_SUFFIX)
EOFCFG
        print_success "Created config.mk"
    fi
fi

# =============================================================================
# 6. Create git placeholders for new directories (for repo manifest)
# =============================================================================

print_info "Ensuring git tracking for new files..."
cd vendor/custom
git add -f build/tasks/fb_package.mk \
           build/tools/releasetools/Android.bp \
           build/tools/releasetools/img_from_target_files_extended.py 2>/dev/null || true
cd - > /dev/null

# =============================================================================
# Done
# =============================================================================

echo ""
print_success "==========================================="
print_success "Fastboot package patch applied!"
print_success "==========================================="
echo ""
print_info "To build a fastboot package after a successful ROM build:"
echo "  m fb_package"
echo ""
print_info "The output will be in:"
echo "  out/target/product/xaga/*-FASTBOOT.zip"
echo ""
print_warn "Note: You must run 'm pixelos' first to generate the"
print_warn "target-files package that fb_package depends on."
echo ""
