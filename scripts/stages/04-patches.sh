# Stage 4: Apply wpa_supplicant_8 patches (MediaTek / WAPI)
# Run from BUILD_DIR.

_STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -n "$REPO_ROOT" ]] || REPO_ROOT="$(cd "$_STAGE_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/lib/common.sh"

print_step "5/6 - Applying wpa_supplicant_8 patches..."

cd external/wpa_supplicant_8
git checkout -- . 2>/dev/null || true
git cherry-pick --abort 2>/dev/null || true
git reset --hard HEAD 2>/dev/null || true

for commit in "$WPA_PATCH1_COMMIT" "$WPA_PATCH2_COMMIT"; do
    print_info "Applying $commit..."
    if git fetch --depth=1 "$WPA_SUPPLICANT_REPO" "$commit" 2>/dev/null; then
        if git cherry-pick "$commit" 2>/dev/null; then
            print_success "Applied $commit"
        else
            print_warn "Cherry-pick $commit failed, skipping..."
            git cherry-pick --abort 2>/dev/null || true
            git checkout -- . 2>/dev/null || true
        fi
    else
        print_warn "Could not fetch $commit, skipping..."
    fi
done
cd "$BUILD_DIR"
