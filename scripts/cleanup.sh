#!/bin/bash

# Manual Cleanup Script for Prometheus/Grafana Monitoring Stack
# This script provides an interactive way to clean up the monitoring infrastructure
#
# Usage:
#   ./scripts/cleanup.sh [OPTIONS]
#
# Options:
#   --preserve-data       Keep volumes (Prometheus metrics, Grafana dashboards)
#   --stop-only           Only stop services, don't remove containers
#   --full-destroy        Remove everything including infrastructure
#   --dry-run            Show what would be removed without doing it
#   -h, --help           Show this help message

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PRESERVE_DATA=false
STOP_ONLY=false
FULL_DESTROY=false
DRY_RUN=false
INVENTORY_FILE="ansible/inventory/hosts"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display help
show_help() {
    cat << EOF
Prometheus/Grafana Monitoring Stack Cleanup Script

This script helps you clean up the monitoring infrastructure safely.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --preserve-data        Keep volumes (Prometheus metrics, Grafana dashboards)
                          Default: Remove volumes

    --stop-only           Only stop services, don't remove containers
                          Useful for temporary shutdown
                          Default: false

    --full-destroy        Remove everything including Terraform infrastructure
                          WARNING: This destroys EC2 instances
                          Default: false

    --dry-run            Show what would be removed without doing it
                          Default: false

    -h, --help           Show this help message

EXAMPLES:
    # Stop services but keep data
    $0 --preserve-data

    # Temporary shutdown (can restart easily)
    $0 --stop-only

    # Complete cleanup but keep infrastructure
    $0

    # See what would be removed
    $0 --dry-run

    # Nuclear option: destroy everything
    $0 --full-destroy

CLEANUP LEVELS:
    Level 1 (--stop-only):        Stop services only
    Level 2 (--preserve-data):   + Remove containers, keep data
    Level 3 (Default):           + Remove volumes
    Level 4 (--full-destroy):    + Destroy infrastructure

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --preserve-data)
            PRESERVE_DATA=true
            shift
            ;;
        --stop-only)
            STOP_ONLY=true
            shift
            ;;
        --full-destroy)
            FULL_DESTROY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Display banner
echo "=========================================="
echo "Prometheus/Grafana Cleanup Tool"
echo "=========================================="
echo ""

# Check if running from project root
if [[ ! -f "$PROJECT_ROOT/ansible/playbooks/cleanup.yml" ]]; then
    print_error "cleanup.yml not found. Are you in the project root?"
    exit 1
fi

# Check if inventory exists
if [[ ! -f "$PROJECT_ROOT/$INVENTORY_FILE" ]]; then
    print_error "Inventory file not found: $INVENTORY_FILE"
    print_info "Generate inventory with: cd terraform && terraform output"
    exit 1
fi

# Display configuration
print_info "Cleanup Configuration:"
echo "  Preserve Data: $(if $PRESERVE_DATA; then echo 'YES'; else echo 'NO'; fi)"
echo "  Stop Only: $(if $STOP_ONLY; then echo 'YES'; else echo 'NO'; fi)"
echo "  Full Destroy: $(if $FULL_DESTROY; then echo 'YES'; else echo 'NO'; fi)"
echo "  Dry Run: $(if $DRY_RUN; then echo 'YES'; else echo 'NO'; fi)"
echo ""

# Warnings for destructive operations
if ! $PRESERVE_DATA && ! $STOP_ONLY; then
    print_warning "Data volumes will be DELETED permanently!"
    echo "  - Prometheus metrics history"
    echo "  - Grafana dashboards and datasources"
    echo "  - AlertManager data"
fi

if $FULL_DESTROY; then
    print_error "Infrastructure will be DESTROYED (EC2 instance, VPC, etc.)"
fi

# Confirmation prompt
if ! $DRY_RUN; then
    echo ""
    read -p "Do you want to proceed? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Cleanup cancelled"
        exit 0
    fi
fi

# Check for Ansible
if ! command -v ansible-playbook &> /dev/null; then
    print_error "ansible-playbook not found. Please install Ansible:"
    echo "  pip install ansible"
    exit 1
fi

# Build Ansible command
ANSIBLE_CMD="ansible-playbook -i $INVENTORY_FILE ansible/playbooks/cleanup.yml"
ANSIBLE_CMD="$ANSIBLE_CMD -e preserve_data=$PRESERVE_DATA"
ANSIBLE_CMD="$ANSIBLE_CMD -e stop_only=$STOP_ONLY"

if $DRY_RUN; then
    ANSIBLE_CMD="$ANSIBLE_CMD --check"
fi

# Execute cleanup playbook
print_info "Running cleanup playbook..."
echo ""

cd "$PROJECT_ROOT"

if $DRY_RUN; then
    print_warning "DRY RUN MODE - No changes will be made"
fi

if $ANSIBLE_CMD; then
    print_success "Monitoring stack cleanup completed!"
else
    print_error "Cleanup playbook failed"
    exit 1
fi

# Full infrastructure destruction
if $FULL_DESTROY && ! $DRY_RUN; then
    echo ""
    print_warning "Proceeding with infrastructure destruction..."
    echo ""

    read -p "Type 'DESTROY' to confirm infrastructure destruction: " -r
    echo ""

    if [[ $REPLY == "DESTROY" ]]; then
        if [[ -d "$PROJECT_ROOT/terraform" ]]; then
            print_info "Running Terraform destroy..."
            cd "$PROJECT_ROOT/terraform"

            if terraform destroy -auto-approve; then
                print_success "Infrastructure destroyed successfully"
            else
                print_error "Terraform destroy failed"
                exit 1
            fi
        else
            print_warning "Terraform directory not found, skipping infrastructure destroy"
        fi
    else
        print_info "Infrastructure destruction cancelled"
    fi
fi

# Final summary
echo ""
echo "=========================================="
print_success "Cleanup Complete!"
echo "=========================================="
echo ""
print_info "Summary of actions:"
echo "  ✓ Docker Compose services stopped"

if ! $STOP_ONLY; then
    echo "  ✓ Containers removed"
    echo "  ✓ Networks cleaned up"
fi

if ! $PRESERVE_DATA && ! $STOP_ONLY; then
    echo "  ✓ Data volumes removed"
else
    echo "  ℹ Data volumes preserved (can be reused)"
fi

if $FULL_DESTROY && ! $DRY_RUN; then
    echo "  ✓ Infrastructure destroyed"
fi

echo ""
print_info "Next steps:"

if $STOP_ONLY; then
    echo "  - Restart services: cd terraform && terraform apply && cd ../ansible && ansible-playbook -i inventory/hosts playbooks/site.yml"
fi

if $PRESERVE_DATA; then
    echo "  - Data volumes are preserved at /var/lib/docker/volumes/"
    echo "  - To remove manually: docker volume rm prometheus_data grafana_data"
fi

if ! $FULL_DESTROY; then
    echo "  - To destroy infrastructure: $0 --full-destroy"
    echo "  - Or manually: cd terraform && terraform destroy"
fi

echo "  - To verify cleanup: docker ps -a && docker volume ls"
echo "  - To redeploy: ansible-playbook -i ansible/inventory/hosts ansible/playbooks/site.yml"
echo ""
