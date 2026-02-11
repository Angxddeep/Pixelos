# Stage 5: Post-sync fixes — Qualcomm/livedisplay removal (MediaTek build)
# Run from BUILD_DIR. Idempotent.

_STAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -n "$REPO_ROOT" ]] || REPO_ROOT="$(cd "$_STAGE_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/lib/common.sh"

print_info "Removing Qualcomm hardware (not needed for MediaTek)..."
rm -rf hardware/qcom/sdm845 hardware/qcom/sm7250 hardware/qcom/sm8150 hardware/qcom/sm8250 hardware/qcom/sm8350 2>/dev/null || true

print_info "Removing incompatible livedisplay HIDL services..."
rm -rf hardware/lineage/livedisplay/sdm hardware/lineage/livedisplay/sysfs 2>/dev/null || true

print_info "Livedisplay/frameworks check..."
if [[ -f "frameworks/base/Android.bp" ]]; then
    print_success "frameworks/base present; LiveDisplay uses lineage-21.0 interfaces."
else
    print_warn "frameworks/base/Android.bp not found."
fi
print_success "Sources ready!"
