#!/bin/bash
#
# PixelOS Build for Xaga (MT6895)
# Structured driver: config + stages. See config/build.conf and scripts/stages/.
#
# Usage:
#   bash scripts/build-pixelos.sh              # full sync + build
#   bash scripts/build-pixelos.sh --sync-only  # sync only
#   bash scripts/build-pixelos.sh --build-only # build only (sources already synced)
#   bash scripts/build-pixelos.sh --clean       # clean out/ then build
#   bash scripts/build-pixelos.sh --user       # user variant
#

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/scripts/lib/common.sh"

# Overrides from environment (optional)
SYNC_ONLY="${SYNC_ONLY:-false}"
BUILD_ONLY="${BUILD_ONLY:-false}"
CLEAN_BUILD="${CLEAN_BUILD:-false}"

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Build PixelOS for Xaga (POCO X4 GT / Redmi K50i / Redmi Note 11T Pro+).

Options:
  --sync-only       Only sync sources, do not build
  --build-only      Only build (assume sources already synced)
  --clean           Clean build (remove out/) before building
  --user            Build user variant (release)
  --userdebug       Build userdebug variant (default)
  --jobs=N          Parallel jobs (default: all cores)
  --dir=PATH        Build directory (default: ~/pixelos)
  -h, --help        Show this help

Config: $REPO_ROOT/config/build.conf
Stages: $REPO_ROOT/scripts/stages/
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --sync-only)   SYNC_ONLY=true ;;
        --build-only) BUILD_ONLY=true ;;
        --clean)       CLEAN_BUILD=true ;;
        --user)        BUILD_TYPE="user" ;;
        --userdebug)   BUILD_TYPE="userdebug" ;;
        --jobs=*)      JOBS="${1#*=}" ;;
        --dir=*)       BUILD_DIR="${1#*=}" ;;
        -h|--help)     show_help; exit 0 ;;
        *)             print_error "Unknown option: $1"; show_help; exit 1 ;;
    esac
    shift
done

echo ""
print_info "=========================================="
print_info "PixelOS Build for Xaga"
print_info "=========================================="
print_info "ROM:           $ROM_NAME ($ROM_BRANCH)"
print_info "Device:        $DEVICE_CODENAME"
print_info "Build Type:    $BUILD_TYPE"
print_info "Build Dir:     $BUILD_DIR"
print_info "Jobs:          $JOBS"
print_info "Device Trees:  $DEVICE_TREE_ORG ($DEVICE_TREE_BRANCH)"
print_info "=========================================="
echo ""

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [[ "$BUILD_ONLY" != "true" ]]; then
    source "$REPO_ROOT/scripts/stages/01-sync-repo.sh"
    source "$REPO_ROOT/scripts/stages/02-device-trees.sh"
    source "$REPO_ROOT/scripts/stages/03-miui-preloader.sh"
    source "$REPO_ROOT/scripts/stages/04-patches.sh"
    source "$REPO_ROOT/scripts/stages/05-post-sync-fixes.sh"
fi

if [[ "$SYNC_ONLY" == "true" ]]; then
    print_success "Sync complete. Run without --sync-only to build."
    exit 0
fi

source "$REPO_ROOT/scripts/stages/06-build.sh"
