# Common helpers for PixelOS build scripts
# Usage: source "$(dirname "$0")/lib/common.sh"   (from scripts/*.sh)
# Or:    source "$REPO_ROOT/scripts/lib/common.sh"

set -e

# Resolve repo root (directory that contains .repo or config/)
REPO_ROOT="${REPO_ROOT:-}"
if [[ -z "$REPO_ROOT" ]]; then
    _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    # From scripts/lib/common.sh -> repo root is scripts/../ 
    if [[ "$_SCRIPT_DIR" == *"/scripts/lib" ]]; then
        REPO_ROOT="$(cd "$_SCRIPT_DIR/../.." && pwd)"
    else
        REPO_ROOT="$(cd "$_SCRIPT_DIR/.." && pwd)"
    fi
fi
export REPO_ROOT

# Load build config if not already set
if [[ -z "$BUILD_CONF_LOADED" ]]; then
    if [[ -f "$REPO_ROOT/config/build.conf" ]]; then
        source "$REPO_ROOT/config/build.conf"
        export BUILD_CONF_LOADED=1
    fi
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
print_step()    { echo -e "${CYAN}[STEP]${NC} $1"; }
