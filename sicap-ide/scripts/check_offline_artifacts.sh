#!/bin/bash
# check_offline_artifacts.sh
# Validates that all required offline packages are present before installation
# Reads configuration from config/values.yaml and checks against inventory groups

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config/values.yaml"
INVENTORY_FILE="${INVENTORY_FILE:-$PROJECT_ROOT/ansible/inventories/TT/hosts.ini}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status="$1"
    local key="$2"
    local pattern="$3"
    local file="$4"
    
    if [[ "$status" == "FOUND" ]]; then
        printf "%-20s | %-40s | ${GREEN}%-60s${NC}\n" "$key" "$pattern" "$file"
    else
        printf "%-20s | %-40s | ${RED}%-60s${NC}\n" "$key" "$pattern" "MISSING"
    fi
}

# Function to extract values from YAML using POSIX tools
extract_yaml_value() {
    local key="$1"
    local yaml_file="$2"
    
    # Use grep and awk to extract values, handling nested keys like paths.offline_dir
    grep -E "^[[:space:]]*${key//./\\.}:" "$yaml_file" | \
    sed -E 's/^[[:space:]]*[^:]+:[[:space:]]*["\x27]?([^"\x27]*?)["\x27]?[[:space:]]*$/\1/' | \
    head -1
}

# Function to check if inventory group has hosts
has_hosts() {
    local group="$1"
    local inventory="$2"
    
    if [[ ! -f "$inventory" ]]; then
        echo "false"
        return
    fi
    
    # Check if group exists and has uncommented hosts
    awk -v group="$group" '
    BEGIN { in_group = 0; has_hosts = 0 }
    /^\[/ { in_group = ($1 == "[" group "]") }
    /^#/ { next }
    in_group && /^[^[#]/ && /ansible_host=/ { has_hosts = 1; exit }
    END { print has_hosts ? "true" : "false" }
    ' "$inventory"
}

# Main validation function
validate_artifacts() {
    local offline_dir
    local missing_count=0
    
    echo "=== DMC4.6.18 Offline Artifacts Validation ==="
    echo "Config file: $CONFIG_FILE"
    echo "Inventory file: $INVENTORY_FILE"
    echo "Offline directory: $offline_dir"
    echo ""
    
    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}ERROR: Config file not found: $CONFIG_FILE${NC}"
        echo "Please copy config/values.example.yaml to config/values.yaml and customize it."
        exit 1
    fi
    
    # Extract offline directory path
    offline_dir=$(extract_yaml_value "offline_dir" "$CONFIG_FILE")
    if [[ -z "$offline_dir" ]]; then
        echo -e "${RED}ERROR: offline_dir not found in config file${NC}"
        exit 1
    fi
    
    # Check if offline directory exists
    if [[ ! -d "$offline_dir" ]]; then
        echo -e "${RED}ERROR: Offline directory not found: $offline_dir${NC}"
        exit 1
    fi
    
    echo "=== Package Validation Results ==="
    printf "%-20s | %-40s | %-60s\n" "Component" "Pattern" "Resolved File"
    printf "%-20s | %-40s | %-60s\n" "----------" "--------" "-------------"
    
    # Always required packages
    local always_required=(
        "pgdg_repo_rpm:pgdg_repo_rpm"
        "es_rpm:es_rpm"
        "kibana_rpm:kibana_rpm"
        "logstash_rpm:logstash_rpm"
        "jdk8_tgz:jdk8_tgz"
    )
    
    # Check always required packages
    for item in "${always_required[@]}"; do
        IFS=':' read -r key pattern_key <<< "$item"
        pattern=$(extract_yaml_value "$pattern_key" "$CONFIG_FILE")
        
        if [[ -z "$pattern" ]]; then
            print_status "MISSING" "$key" "PATTERN_NOT_FOUND" ""
            ((missing_count++))
            continue
        fi
        
        # Resolve pattern to actual files
        resolved_files=$(find "$offline_dir" -maxdepth 1 -name "$pattern" -type f 2>/dev/null | head -1)
        
        if [[ -n "$resolved_files" ]]; then
            filename=$(basename "$resolved_files")
            print_status "FOUND" "$key" "$pattern" "$filename"
        else
            print_status "MISSING" "$key" "$pattern" ""
            ((missing_count++))
        fi
    done
    
    # Conditionally required packages based on inventory groups
    local conditional_required=(
        "dmc_rpm:dmc_rpm:dmc1"
        "mmg_rpm:mmg_rpm:mmg"
        "mmsoap_rpm:mmsoap_rpm:mmsoap"
        "smppc_rpm:smppc_rpm:smppc"
        "sls_rpm:sls_rpm:sls"
    )
    
    # Check conditionally required packages
    for item in "${conditional_required[@]}"; do
        IFS=':' read -r key pattern_key group <<< "$item"
        
        # Check if group has hosts in inventory
        if [[ $(has_hosts "$group" "$INVENTORY_FILE") == "false" ]]; then
            printf "%-20s | %-40s | ${YELLOW}%-60s${NC}\n" "$key" "N/A" "SKIPPED (no hosts in $group)"
            continue
        fi
        
        # Special handling for required components
        if [[ "$group" == "mmsoap" || "$group" == "sls" ]]; then
            printf "%-20s | %-40s | ${YELLOW}%-60s${NC}\n" "$key" "REQUIRED" "ENVIRONMENT_REQUIRED"
        fi
        
        pattern=$(extract_yaml_value "$pattern_key" "$CONFIG_FILE")
        
        if [[ -z "$pattern" ]]; then
            print_status "MISSING" "$key" "PATTERN_NOT_FOUND" ""
            ((missing_count++))
            continue
        fi
        
        # Resolve pattern to actual files
        resolved_files=$(find "$offline_dir" -maxdepth 1 -name "$pattern" -type f 2>/dev/null | head -1)
        
        if [[ -n "$resolved_files" ]]; then
            filename=$(basename "$resolved_files")
            print_status "FOUND" "$key" "$pattern" "$filename"
        else
            print_status "MISSING" "$key" "$pattern" ""
            ((missing_count++))
        fi
    done
    
    echo ""
    echo "=== Validation Summary ==="
    
    if [[ $missing_count -eq 0 ]]; then
        echo -e "${GREEN}✓ All required packages found successfully${NC}"
        echo -e "${GREEN}✓ Ready for installation${NC}"
        return 0
    else
        echo -e "${RED}✗ $missing_count required packages missing${NC}"
        echo -e "${RED}✗ Installation cannot proceed${NC}"
        echo ""
        echo "Please ensure all required packages are present in: $offline_dir"
        return 1
    fi
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Validates that all required offline packages are present before DMC installation.

OPTIONS:
    -h, --help              Show this help message
    -i, --inventory FILE    Use specific inventory file (default: TT environment)
    -v, --verbose           Enable verbose output

ENVIRONMENT VARIABLES:
    INVENTORY_FILE          Path to inventory file to use for validation

EXAMPLES:
    $0                                    # Validate using TT inventory
    $0 -i ansible/inventories/DEV/hosts.ini  # Validate using DEV inventory
    INVENTORY_FILE=ansible/inventories/DEV/hosts.ini $0  # Using env var

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -i|--inventory)
            INVENTORY_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run validation
validate_artifacts

