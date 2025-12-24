#!/bin/bash
#
# Google Cloud VM Setup for PixelOS Build
# Creates a Compute Engine VM optimized for Android ROM compilation
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default configuration
VM_NAME="${VM_NAME:-pixelos-builder}"
PROJECT_ID="${PROJECT_ID:-}"
ZONE="${ZONE:-us-central1-a}"
MACHINE_TYPE="${MACHINE_TYPE:-n2-standard-32}"  # 32 vCPUs, 128GB RAM
BOOT_DISK_SIZE="${BOOT_DISK_SIZE:-500}"  # GB
USE_SPOT="${USE_SPOT:-false}"

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Create a Google Cloud Compute Engine VM for building PixelOS.

Options:
  --project=PROJECT_ID    GCP project ID (required)
  --zone=ZONE             Zone for VM (default: us-central1-a)
  --machine=MACHINE_TYPE  Machine type (default: n2-standard-32)
  --disk-size=SIZE        Boot disk size in GB (default: 500)
  --name=VM_NAME          VM instance name (default: pixelos-builder)
  --spot                  Use Spot VM for lower cost (can be preempted)
  --delete                Delete existing VM instead of creating
  -h, --help              Show this help message

Examples:
  # Create VM with defaults
  $(basename "$0") --project=my-gcp-project

  # Create Spot VM for cost savings (60-80% cheaper)
  $(basename "$0") --project=my-gcp-project --spot

  # Smaller VM for testing
  $(basename "$0") --project=my-gcp-project --machine=n2-standard-8 --disk-size=200

Machine Type Recommendations:
  n2-standard-8   (8 vCPUs, 32GB RAM)   - ~\$0.40/hr - Testing only
  n2-standard-16  (16 vCPUs, 64GB RAM)  - ~\$0.80/hr - Minimum for builds
  n2-standard-32  (32 vCPUs, 128GB RAM) - ~\$1.60/hr - Recommended
  n2-highmem-32   (32 vCPUs, 256GB RAM) - ~\$2.40/hr - Faster builds

EOF
}

DELETE_VM=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project=*) PROJECT_ID="${1#*=}" ;;
        --zone=*) ZONE="${1#*=}" ;;
        --machine=*) MACHINE_TYPE="${1#*=}" ;;
        --disk-size=*) BOOT_DISK_SIZE="${1#*=}" ;;
        --name=*) VM_NAME="${1#*=}" ;;
        --spot) USE_SPOT=true ;;
        --delete) DELETE_VM=true ;;
        -h|--help) show_help; exit 0 ;;
        *) print_error "Unknown option: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Check prerequisites
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI not found. Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

if [[ -z "$PROJECT_ID" ]]; then
    print_error "Project ID required. Use --project=YOUR_PROJECT_ID"
    exit 1
fi

# Set project
gcloud config set project "$PROJECT_ID" 2>/dev/null

# Delete VM if requested
if [[ "$DELETE_VM" == "true" ]]; then
    print_info "Deleting VM: $VM_NAME..."
    gcloud compute instances delete "$VM_NAME" --zone="$ZONE" --quiet || true
    print_success "VM deleted!"
    exit 0
fi

print_info "=========================================="
print_info "PixelOS Build VM Setup"
print_info "=========================================="
print_info "Project:      $PROJECT_ID"
print_info "VM Name:      $VM_NAME"
print_info "Zone:         $ZONE"
print_info "Machine:      $MACHINE_TYPE"
print_info "Disk Size:    ${BOOT_DISK_SIZE}GB SSD"
print_info "Spot VM:      $USE_SPOT"
print_info "=========================================="

# Estimate cost
if [[ "$USE_SPOT" == "true" ]]; then
    print_warn "Spot VM: Up to 80% cheaper but can be preempted!"
fi

# Build gcloud command
CMD="gcloud compute instances create $VM_NAME"
CMD+=" --project=$PROJECT_ID"
CMD+=" --zone=$ZONE"
CMD+=" --machine-type=$MACHINE_TYPE"
CMD+=" --image-family=ubuntu-2204-lts"
CMD+=" --image-project=ubuntu-os-cloud"
CMD+=" --boot-disk-size=${BOOT_DISK_SIZE}GB"
CMD+=" --boot-disk-type=pd-ssd"
CMD+=" --metadata=startup-script='#!/bin/bash
echo \"VM Ready for PixelOS build!\" > /tmp/vm-ready
'"

if [[ "$USE_SPOT" == "true" ]]; then
    CMD+=" --provisioning-model=SPOT"
    CMD+=" --instance-termination-action=STOP"
fi

print_info "Creating VM..."
eval "$CMD"

if [[ $? -eq 0 ]]; then
    print_success "VM created successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. SSH into VM:   gcloud compute ssh $VM_NAME --zone=$ZONE"
    echo "  2. Clone repo:    git clone https://github.com/YOUR_USER/Pixelos.git"
    echo "  3. Setup env:     cd Pixelos && bash scripts/env-setup.sh"
    echo "  4. Start build:   bash scripts/build-pixelos.sh"
    echo ""
    print_warn "Remember to delete VM after build to avoid charges:"
    echo "  gcloud compute instances delete $VM_NAME --zone=$ZONE"
else
    print_error "Failed to create VM"
    exit 1
fi
