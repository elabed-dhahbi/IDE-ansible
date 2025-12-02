#!/bin/bash
# check_offline_artifacts.sh
# Validates that all required offline packages are present before installation
# Reads configuration from config/values.yaml and checks against inventory groups

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config/values.yaml"
PACKAGES_FILE="$PROJECT_ROOT/config/packages.yaml"
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
    
    local parent="${key%%.*}"
    local child="${key#*.}"
    
    awk -v parent="$parent" -v child="$child" '
        /^[[:space:]]*'$parent':[[:space:]]*$/ { in_block=1; next }
        in_block && /^[[:space:]]*'$child':[[:space:]]*/ {
            # Extract everything after the colon
            gsub(/^[[:space:]]*[^:]+:[[:space:]]*/, "", $0)
            gsub(/["\x27]/, "", $0)
            gsub(/\r$/, "", $0)  # Remove carriage return
            print $0
            exit
        }
    ' "$yaml_file"
}

render_template() {
    local template="$1"
    local yaml_file="$2"
    
    # Match all {{ ... }} expressions
    while [[ "$template" =~ \{\{\ ([a-zA-Z0-9_.]+)\ \}\} ]]; do
        local var="${BASH_REMATCH[1]}"
        local val
        # Try to get value from the provided file, or from values.yaml if it's a version variable
        if [[ "$var" == versions.* ]]; then
            val=$(extract_yaml_value "$var" "$CONFIG_FILE")
        else
            val=$(extract_yaml_value "$var" "$yaml_file")
        fi
        template="${template//\{\{ ${var} \}\}/$val}"
    done
    
    echo "$template"
}

# Function to check if inventory group has hosts
has_hosts() {
    local group="$1"
    local inventory="$2"

    if [[ ! -f "$inventory" ]]; then
        echo "false"
        return
    fi

    awk -v group="$group" '
      $0 ~ /^\[/ { in_group = ($0 ~ "^\\[" group "\\][[:space:]]*$"); next }
      in_group && $0 !~ /^[[:space:]]*#/ && NF { has_hosts = 1; exit }
      END { print has_hosts ? "true" : "false" }
    ' "$inventory"
}

# Main validation function
validate_artifacts() {
    local offline_dir

    # Extract offline directory path first (fixes unbound variable crash)
    # Check both values.yaml and packages.yaml for paths.offline_dir
    offline_dir=$(awk '/^[[:space:]]*paths:[[:space:]]*$/ { in_paths=1; next } in_paths && /^[[:space:]]*offline_dir:/ { gsub(/["\x27]/, "", $2); gsub(/#.*$/, "", $2); gsub(/[[:space:]]+$/, "", $2); print $2; exit }' "$CONFIG_FILE" 2>/dev/null)
    
    # If not found in values.yaml, try packages.yaml
    if [[ -z "$offline_dir" ]] && [[ -f "$PACKAGES_FILE" ]]; then
        offline_dir=$(awk '/^[[:space:]]*paths:[[:space:]]*$/ { in_paths=1; next } in_paths && /^[[:space:]]*offline_dir:/ { gsub(/["\x27]/, "", $2); gsub(/#.*$/, "", $2); gsub(/[[:space:]]+$/, "", $2); print $2; exit }' "$PACKAGES_FILE" 2>/dev/null)
    fi
    
    # If still not found, use default
    if [[ -z "$offline_dir" ]]; then
        offline_dir="/tmp/offline"
        echo -e "${YELLOW}WARNING: paths.offline_dir not found in config files, using default: $offline_dir${NC}"
        echo -e "${YELLOW}To set a custom path, add to config/values.yaml or config/packages.yaml:${NC}"
        echo -e "${YELLOW}paths:${NC}"
        echo -e "${YELLOW}  offline_dir: /tmp/offline${NC}"
    fi

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

    # Check if offline directory exists
    if [[ ! -d "$offline_dir" ]]; then
        echo -e "${RED}ERROR: Offline directory not found: $offline_dir${NC}"
        exit 1
    fi
    
    echo "=== Package Validation Results ==="
    printf "%-20s | %-40s | %-60s\n" "Component" "Pattern" "Resolved File"
    printf "%-20s | %-40s | %-60s\n" "----------" "--------" "-------------"
    
    # All packages - just log them, nothing is mandatory
    local all_packages=(
        "pgdg_repo_rpm:package_globs.pgdg_repo_rpm"
        "jdk8_tgz:package_globs.jdk8_tgz"
        "jdk8_32bit:package_globs.jdk8_32bit"
        "jdk8_64bit:package_globs.jdk8_64bit"
        "sls_rpm:package_globs.sls_rpm"
        "elasticsearch_rpm:package_globs.elasticsearch_rpm"
        "kibana_rpm:package_globs.kibana_rpm"
        "logstash_rpm:package_globs.logstash_rpm"
        "logstash_filter_rest:package_globs.logstash_filter_rest"
        "opensearch_rpm:package_globs.opensearch_rpm"
        "opensearch_dashboards_rpm:package_globs.opensearch_dashboards_rpm"
        "logstash_oss_rpm:package_globs.logstash_oss_rpm"
    )
    
    for item in "${all_packages[@]}"; do
        IFS=':' read -r key pattern_key <<< "$item"
        # Try packages.yaml first for package_globs, then values.yaml
        if [[ "$pattern_key" == package_globs.* ]] && [[ -f "$PACKAGES_FILE" ]]; then
            raw_template=$(extract_yaml_value "$pattern_key" "$PACKAGES_FILE")
            pattern=$(render_template "$raw_template" "$PACKAGES_FILE")
        else
            raw_template=$(extract_yaml_value "$pattern_key" "$CONFIG_FILE")
            pattern=$(render_template "$raw_template" "$CONFIG_FILE")
        fi

        if [[ -z "$pattern" ]]; then
            print_status "MISSING" "$key" "PATTERN_NOT_FOUND" ""
            continue
        fi

        resolved_files=$(find "$offline_dir" -maxdepth 1 -name "$pattern" -type f 2>/dev/null | head -1)

        if [[ -n "$resolved_files" ]]; then
            filename=$(basename "$resolved_files")
            print_status "FOUND" "$key" "$pattern" "$filename"
        else
            print_status "MISSING" "$key" "$pattern" ""
        fi
    done
    
    # Conditionally required packages based on inventory groups
    local conditional_required=(
        "dmc_rpm:package_globs.dmc_rpm:dmc1"
        "mmg_rpm:package_globs.mmg_rpm:mmg"
        "mmsoap_rpm:package_globs.mmsoap_rpm:mmsoap"
        "smppc_rpm:package_globs.smppc_rpm:smppc"
        "sls_rpm:package_globs.sls_rpm:sls"
        "drs_rpm:package_globs.drs_rpm:drs"
        "opensearch_rpm:package_globs.opensearch_rpm:opensearch"
        "opensearch_dashboards_rpm:package_globs.opensearch_dashboards_rpm:opensearch_dashboards"
        "logstash_oss_rpm:package_globs.logstash_oss_rpm:logstash_oss"
    )
    
    for item in "${conditional_required[@]}"; do
        IFS=':' read -r key pattern_key group <<< "$item"

        if [[ $(has_hosts "$group" "$INVENTORY_FILE") == "false" ]]; then
            printf "%-20s | %-40s | ${YELLOW}%-60s${NC}\n" "$key" "N/A" "SKIPPED (no hosts in $group)"
            continue
        fi

        if [[ "$group" == "mmsoap" || "$group" == "sls" ]]; then
            printf "%-20s | %-40s | ${YELLOW}%-60s${NC}\n" "$key" "REQUIRED" "ENVIRONMENT_REQUIRED"
        fi

        # Try packages.yaml first for package_globs, then values.yaml
        if [[ "$pattern_key" == package_globs.* ]] && [[ -f "$PACKAGES_FILE" ]]; then
            raw_template=$(extract_yaml_value "$pattern_key" "$PACKAGES_FILE")
            pattern=$(render_template "$raw_template" "$PACKAGES_FILE")
        else
            raw_template=$(extract_yaml_value "$pattern_key" "$CONFIG_FILE")
            pattern=$(render_template "$raw_template" "$CONFIG_FILE")
        fi

        if [[ -z "$pattern" ]]; then
            print_status "MISSING" "$key" "PATTERN_NOT_FOUND" ""
            continue
        fi

        resolved_files=$(find "$offline_dir" -maxdepth 1 -name "$pattern" -type f 2>/dev/null | head -1)

        if [[ -n "$resolved_files" ]]; then
            filename=$(basename "$resolved_files")
            print_status "FOUND" "$key" "$pattern" "$filename"
        else
            print_status "MISSING" "$key" "$pattern" ""
        fi
    done
    
    echo ""
    echo "=== Validation Summary ==="
    echo -e "${GREEN}✓ Package validation completed${NC}"
    echo -e "${YELLOW}Note: All packages are logged above. Missing packages are informational only.${NC}"
    echo -e "${YELLOW}Installation will proceed based on your inventory and stack selection.${NC}"
    return 0
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
    -l, --list-files        List all files in offline directory (quick test)

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
        -l|--list-files)
            # Quick test: list all files in offline directory
            offline_dir=$(awk '/^[[:space:]]*paths:[[:space:]]*$/ { in_paths=1; next } in_paths && /^[[:space:]]*offline_dir:/ { gsub(/["\x27]/, "", $2); gsub(/#.*$/, "", $2); gsub(/[[:space:]]+$/, "", $2); print $2; exit }' "$CONFIG_FILE" 2>/dev/null)
            if [[ -z "$offline_dir" ]] && [[ -f "$PACKAGES_FILE" ]]; then
                offline_dir=$(awk '/^[[:space:]]*paths:[[:space:]]*$/ { in_paths=1; next } in_paths && /^[[:space:]]*offline_dir:/ { gsub(/["\x27]/, "", $2); gsub(/#.*$/, "", $2); gsub(/[[:space:]]+$/, "", $2); print $2; exit }' "$PACKAGES_FILE" 2>/dev/null)
            fi
            if [[ -z "$offline_dir" ]]; then
                offline_dir="/tmp/offline"
            fi
            echo "=== Files in offline directory: $offline_dir ==="
            if [[ -d "$offline_dir" ]]; then
                ls -lh "$offline_dir" | tail -n +2 | awk '{printf "%-10s %s\n", $5, $9}'
            else
                echo "Directory does not exist: $offline_dir"
            fi
            exit 0
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

