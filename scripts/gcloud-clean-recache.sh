#!/bin/bash
#
# Google Cloud: clean VM (optional) and full recache instructions
# Run locally (with gcloud CLI) to delete the build VM and get steps for a fresh build.
#
# For a full recache on the VM (wipe source + build and re-sync): see docs/GCLOUD_BUILD.md
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Defaults (override with env or pass-through to gcloud-setup)
VM_NAME="${VM_NAME:-pixelos-builder}"
ZONE="${ZONE:-us-central1-a}"
PROJECT_ID="${PROJECT_ID:-}"

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Clean your GCloud PixelOS build setup and get steps for a full recache.

Options:
  --project=ID     GCP project ID (required for --delete)
  --delete         Delete the VM (stops billing). You can recreate with gcloud-setup.sh.
  --zone=ZONE      Zone (default: us-central1-a)
  --name=VM_NAME   VM name (default: pixelos-builder)
  -h, --help       Show this help

Without --delete: only prints the steps for full recache (on VM and locally).
With --delete:    deletes the VM, then prints steps to create a new VM and do full recache.
EOF
}

DELETE_VM=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --project=*) PROJECT_ID="${1#*=}" ;;
        --zone=*)    ZONE="${1#*=}" ;;
        --name=*)    VM_NAME="${1#*=}" ;;
        --delete)    DELETE_VM=true ;;
        -h|--help)   show_help; exit 0 ;;
        *)           echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
    shift
done

if [[ "$DELETE_VM" == "true" ]]; then
    if [[ -z "$PROJECT_ID" ]]; then
        echo "Error: --project=YOUR_PROJECT required when using --delete"
        exit 1
    fi
    if ! command -v gcloud &>/dev/null; then
        echo "Error: gcloud CLI not found. Install: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    gcloud config set project "$PROJECT_ID" 2>/dev/null
    echo "[INFO] Deleting VM: $VM_NAME (zone: $ZONE)..."
    gcloud compute instances delete "$VM_NAME" --zone="$ZONE" --quiet || true
    echo "[SUCCESS] VM deleted. Billing stopped."
    echo ""
fi

echo "=========================================="
echo "Full recache (structured workflow)"
echo "=========================================="
echo ""
echo "1) Create VM (if you used --delete):"
echo "   bash scripts/gcloud-setup.sh --project=$PROJECT_ID --spot"
echo ""
echo "2) SSH into VM:"
echo "   gcloud compute ssh $VM_NAME --zone=$ZONE"
echo ""
echo "3) On the VM — clone and one-time env setup:"
echo "   git clone https://github.com/YOUR_USER/Pixelos.git"
echo "   cd Pixelos && bash scripts/env-setup.sh"
echo ""
echo "4) Full recache (wipe build dir and re-sync + build):"
echo "   export BUILD_DIR=\${BUILD_DIR:-$HOME/pixelos}"
echo "   rm -rf \"\$BUILD_DIR/.repo\" \"\$BUILD_DIR/out\""
echo "   Optional: ccache -C   # clear ccache"
echo "   cd Pixelos && bash scripts/build-pixelos.sh"
echo ""
echo "5) Build-only (sources already synced):"
echo "   cd Pixelos && bash scripts/build-pixelos.sh --build-only"
echo ""
echo "6) After build, delete VM to stop billing:"
echo "   bash scripts/gcloud-setup.sh --project=$PROJECT_ID --delete"
echo ""
