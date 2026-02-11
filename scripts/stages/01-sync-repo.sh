# Stage 1: Initialize and sync PixelOS repo
# Run from BUILD_DIR. Expects: REPO_ROOT, BUILD_DIR, ROM_*, JOBS from config.

_STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -n "$REPO_ROOT" ]] || REPO_ROOT="$(cd "$_STAGE_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/lib/common.sh"

print_step "1/6 - Initializing PixelOS manifest..."
if [[ ! -d ".repo" ]]; then
    repo init -u "$ROM_MANIFEST" -b "$ROM_BRANCH" --git-lfs --depth=1
else
    print_info "Repo already initialized, skipping..."
fi

print_step "2/6 - Syncing ROM source (this may take a long time)..."
print_info "Cleaning up potential dirty repositories..."
rm -rf hardware/qcom/sdm845/display hardware/qcom/sdm845/gps 2>/dev/null || true
rm -rf hardware/qcom/sm7250/display hardware/qcom/sm7250/gps 2>/dev/null || true
rm -rf hardware/qcom/sm8150/display hardware/qcom/sm8150/gps 2>/dev/null || true
rm -rf packages/apps/ParanoidSense 2>/dev/null || true
repo sync -c --no-tags --no-clone-bundle --optimized-fetch --prune --force-sync -j"$JOBS" || \
repo sync -c --no-tags --no-clone-bundle --optimized-fetch --prune --force-sync -j4
