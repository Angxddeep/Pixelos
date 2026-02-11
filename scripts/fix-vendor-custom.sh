#!/bin/bash
#
# Fix vendor/custom/config/common_full_phone.mk if it references vendor/lineage
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

COMMON_FULL_PHONE="vendor/custom/config/common_full_phone.mk"

if [[ ! -f "$COMMON_FULL_PHONE" ]]; then
    print_warn "$COMMON_FULL_PHONE not found"
    exit 0
fi

if grep -q "vendor/lineage" "$COMMON_FULL_PHONE"; then
    print_warn "Found vendor/lineage reference in $COMMON_FULL_PHONE"
    print_info "Creating backup..."
    cp "$COMMON_FULL_PHONE" "${COMMON_FULL_PHONE}.bak"
    
    # Comment out vendor/lineage references
    sed -i 's|^\(.*vendor/lineage.*\)|# \1|g' "$COMMON_FULL_PHONE"
    
    print_success "Commented out vendor/lineage references"
    print_warn "You may need to check the file manually if build still fails"
else
    print_info "No vendor/lineage references found in $COMMON_FULL_PHONE"
fi
