#!/bin/bash
# sync_packages.sh
# Scans offline directory and updates config/values.yaml with detected package versions
# Makes the playbook dynamic by auto-detecting versions from actual RPM/tarball files

set -uo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config/values.yaml"
RELEASE_FILE="$PROJECT_ROOT/ansible/vars/release.yml"  # NEW: Centralized version file
PACKAGES_FILE="$PROJECT_ROOT/config/packages.yaml"
OFFLINE_DIR="${OFFLINE_DIR:-/tmp/offline}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to extract version from filename
extract_version() {
    local pattern="$1"
    local file="$2"
    
    # Try to match the pattern and extract version
    if [[ "$file" =~ $pattern ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Function to find latest version file matching pattern
find_latest_version() {
    local pattern="$1"
    local offline_dir="$2"
    
    # Find all files matching the pattern
    find "$offline_dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null | sort -V | tail -1
}

# Function to update YAML value in config/values.yaml (versions section)
update_yaml_value() {
    local key_path="$1"
    local new_value="$2"
    local yaml_file="$3"

    # Skip if file doesn't exist (backward compatibility)
    if [[ ! -f "$yaml_file" ]]; then
        return 0
    fi
    
    # Split key path (e.g., "versions.zabbix" -> child="zabbix")
    local child="${key_path#*.}"
    
    # Create backup if it doesn't exist
    if [[ ! -f "${yaml_file}.bak" ]]; then
        cp "$yaml_file" "${yaml_file}.bak"
    fi
    
    # Only update keys under the versions: section to avoid updating wrong keys
    # Check if the key exists in the versions: section
    local in_versions=0
    local found_key=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*versions:[[:space:]]*$ ]]; then
            in_versions=1
            continue
        fi
        if [[ $in_versions -eq 1 ]] && [[ "$line" =~ ^[[:space:]]*[a-zA-Z_]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]+ ]]; then
            # Left the versions section
            break
        fi
        if [[ $in_versions -eq 1 ]] && [[ "$line" =~ ^[[:space:]]*${child}:[[:space:]]* ]]; then
            found_key=1
            break
        fi
    done < "$yaml_file"
    
    if [[ $found_key -eq 0 ]]; then
        return 1
    fi
    
    # Get the old value for debugging (only from versions section)
    local old_line=$(awk '/^[[:space:]]*versions:[[:space:]]*$/{flag=1; next} /^[[:space:]]*[a-zA-Z_]+:[[:space:]]*$/{if(flag && !/^[[:space:]]+/) flag=0} flag && /^[[:space:]]*'${child}':/{print; exit}' "$yaml_file")
    local old_value=$(echo "$old_line" | sed 's/^[[:space:]]*[^:]*:[[:space:]]*["'\'']\?\([^"'\'']*\)["'\'']\?.*/\1/')
    
    # Use awk to update only within the versions: section
    local tmp_file="${yaml_file}.tmp.$$"
    awk -v key="$child" -v newval="$new_value" '
        /^[[:space:]]*versions:[[:space:]]*$/ { in_versions=1; print; next }
        in_versions && /^[[:space:]]*[a-zA-Z_]+:[[:space:]]*$/ && !/^[[:space:]]+/ { in_versions=0 }
        in_versions && $0 ~ "^[[:space:]]*" key ":" {
            match($0, /^[[:space:]]*/)
            indent = substr($0, 1, RLENGTH)
            print indent key ": \"" newval "\""
            next
        }
        { print }
    ' "$yaml_file" > "$tmp_file" 2>/dev/null
    
    if [[ $? -eq 0 ]] && [[ -f "$tmp_file" ]] && [[ -s "$tmp_file" ]]; then
        # Verify the change was made in the versions section
        local new_line=$(awk '/^[[:space:]]*versions:[[:space:]]*$/{flag=1; next} /^[[:space:]]*[a-zA-Z_]+:[[:space:]]*$/{if(flag && !/^[[:space:]]+/) flag=0} flag && /^[[:space:]]*'${child}':/{print; exit}' "$tmp_file")
        if [[ -n "$new_line" ]]; then
            # Replace the original file
            mv "$tmp_file" "$yaml_file" 2>/dev/null || {
                rm -f "$tmp_file" 2>/dev/null || true
                return 1
            }
            
            # Get the new value for debugging
            local new_value_check=$(echo "$new_line" | sed 's/^[[:space:]]*[^:]*:[[:space:]]*["'\'']\?\([^"'\'']*\)["'\'']\?.*/\1/')
            
            # Print what changed for debugging
            echo "    DEBUG: ${child}: \"${old_value}\" -> \"${new_value_check}\""
            
            return 0
        else
            rm -f "$tmp_file" 2>/dev/null || true
            echo "    DEBUG ERROR: ${child}: update succeeded but key not found in versions section" >&2
            return 1
        fi
    else
        rm -f "$tmp_file" 2>/dev/null || true
        echo "    DEBUG ERROR: ${child}: awk command failed" >&2
        return 1
    fi
}

# Function to update release.yml (new centralized version file)
update_release_yml() {
    local key="$1"
    local new_value="$2"
    local yaml_file="$3"

    # Skip if file doesn't exist
    if [[ ! -f "$yaml_file" ]]; then
        return 1
    fi

    # Create backup if it doesn't exist
    if [[ ! -f "${yaml_file}.bak" ]]; then
        cp "$yaml_file" "${yaml_file}.bak"
    fi

    # Get the old value for debugging
    local old_line=$(grep "^${key}:" "$yaml_file" 2>/dev/null | head -1)
    local old_value=$(echo "$old_line" | sed 's/^[^:]*:[[:space:]]*["'\'']\?\([^"'\'']*\)["'\'']\?.*/\1/')

    # Use sed to update the value (simple key: "value" format)
    local tmp_file="${yaml_file}.tmp.$$"
    sed "s|^${key}:[[:space:]]*[\"']\?[^\"']*[\"']\?|${key}: \"${new_value}\"|" "$yaml_file" > "$tmp_file" 2>/dev/null

    if [[ $? -eq 0 ]] && [[ -f "$tmp_file" ]] && [[ -s "$tmp_file" ]]; then
        # Verify the change was made
        local new_line=$(grep "^${key}:" "$tmp_file" 2>/dev/null | head -1)
        if [[ -n "$new_line" ]]; then
            # Replace the original file
            mv "$tmp_file" "$yaml_file" 2>/dev/null || {
                rm -f "$tmp_file" 2>/dev/null || true
                return 1
            }

            # Get the new value for debugging
            local new_value_check=$(echo "$new_line" | sed 's/^[^:]*:[[:space:]]*["'\'']\?\([^"'\'']*\)["'\'']\?.*/\1/')

            # Print what changed for debugging
            echo "    DEBUG: ${key}: \"${old_value}\" -> \"${new_value_check}\""

            return 0
        else
            rm -f "$tmp_file" 2>/dev/null || true
            return 1
        fi
    else
        rm -f "$tmp_file" 2>/dev/null || true
        return 1
    fi
}

echo -e "${BLUE}=== Syncing Package Versions from Offline Directory ===${NC}"
echo "Offline directory: $OFFLINE_DIR"
echo "Config file: $CONFIG_FILE"
echo "Release file: $RELEASE_FILE"
echo ""

if [[ ! -d "$OFFLINE_DIR" ]]; then
    echo -e "${RED}ERROR: Offline directory not found: $OFFLINE_DIR${NC}"
    exit 1
fi

# Check if release file exists, create if it doesn't
if [[ ! -f "$RELEASE_FILE" ]]; then
    echo -e "${YELLOW}⚠ Release file not found: $RELEASE_FILE${NC}"
    echo -e "${YELLOW}Creating release file from template...${NC}"
    mkdir -p "$(dirname "$RELEASE_FILE")"
    cat > "$RELEASE_FILE" << 'EOF'
---
# =============================================================================
# RELEASE VERSIONS - Centralized Version Management
# =============================================================================
# This file is auto-generated by sync_packages.sh
# To manually override, edit this file after running sync-packages
# =============================================================================

# PostgreSQL versions
postgresql_major_version: "15"
postgresql_full_version: "15.14"
postgresql_package_version: "15.14-1PGDG.rhel9"
libpq_version: "17.6-1PGDG.rhel9"
python3_psycopg2_version: "2.8.6-6.el9"

# Java versions
java_major_version: "8"
java_full_version: "8u412"
java_build_version: "8u412-b08"
java_legacy_version: "1_8_0_92"

# SICAP Application versions
dmc_version: "4.6.33"
mmg_version: "4.6.21"
mmsoap_version: "5.6.1"
smppc_version: "5.4.9"
sls_version: "2.0.3"
drs_version: "1.7.0"

# ELK Stack versions
elasticsearch_version: "7.17.25"
kibana_version: "7.17.25"
logstash_version: "7.17.25"
logstash_oss_version: "8.19.4"

# OpenSearch versions
opensearch_version: "3.2.0"
opensearch_dashboards_version: "3.2.0"

# Zabbix versions
zabbix_version: "7.4.2"
zabbix_release: "release1"

# Package repository versions
pgdg_repo_version: "latest"
EOF
    echo -e "${GREEN}✓ Created release file${NC}"
fi

# Check if config file exists (for backward compatibility)
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}⚠ Config file not found: $CONFIG_FILE (will only update release.yml)${NC}"
fi

# Detect versions from files
declare -A detected_versions

# Zabbix version detection
zabbix_file=$(find_latest_version "zabbix-server-pgsql-*-release*.el9.x86_64.rpm" "$OFFLINE_DIR")
if [[ -n "$zabbix_file" ]]; then
    version=$(extract_version "zabbix-server-pgsql-([0-9]+\.[0-9]+\.[0-9]+)-release" "$(basename "$zabbix_file")")
    if [[ -n "$version" ]]; then
        detected_versions["zabbix"]="$version"
        echo -e "${GREEN}✓ Detected Zabbix version: $version${NC}"
    fi
fi

# PostgreSQL version detection - extract version from any postgresql15 package
postgres_file=$(find_latest_version "postgresql15-*.rhel9.x86_64.rpm" "$OFFLINE_DIR")
if [[ -n "$postgres_file" ]]; then
    # Pattern: postgresql15-libs-15.14-1PGDG.rhel9.x86_64.rpm -> extract 15.14
    # Try pattern that matches -15.14-1PGDG
    version=$(extract_version "-([0-9]+\.[0-9]+)-1PGDG" "$(basename "$postgres_file")")
    if [[ -n "$version" ]]; then
        detected_versions["postgres"]="$version"
        detected_versions["postgresql_full_version"]="$version"
        # Extract major version (e.g., 15.14 -> 15)
        major_version=$(echo "$version" | cut -d. -f1)
        detected_versions["postgresql_major_version"]="$major_version"
        echo -e "${GREEN}✓ Detected PostgreSQL version: $version (major: $major_version)${NC}"
    fi
fi

# DMC version detection
dmc_file=$(find_latest_version "SCPdmc-*.tar.gz" "$OFFLINE_DIR")
if [[ -n "$dmc_file" ]]; then
    version=$(extract_version "SCPdmc-([0-9]+\.[0-9]+\.[0-9]+)" "$(basename "$dmc_file")")
    if [[ -n "$version" ]]; then
        detected_versions["dmc"]="$version"
        echo -e "${GREEN}✓ Detected DMC version: $version${NC}"
    fi
fi

# OpenSearch version detection - exclude dashboards
opensearch_file=$(find "$OFFLINE_DIR" -maxdepth 1 -type f -name "opensearch-*-linux-x64.rpm" ! -name "*dashboards*" 2>/dev/null | sort -V | tail -1)
if [[ -n "$opensearch_file" ]]; then
    version=$(extract_version "opensearch-([0-9]+\.[0-9]+\.[0-9]+)-" "$(basename "$opensearch_file")")
    if [[ -n "$version" ]]; then
        detected_versions["opensearch"]="$version"
        echo -e "${GREEN}✓ Detected OpenSearch version: $version${NC}"
    fi
fi

# Logstash OSS version detection
logstash_oss_file=$(find_latest_version "logstash-oss-*-x86_64.rpm" "$OFFLINE_DIR")
if [[ -n "$logstash_oss_file" ]]; then
    # Pattern: logstash-oss-8.19.4-x86_64.rpm -> 8.19.4 (3 numbers, not 4)
    version=$(extract_version "logstash-oss-([0-9]+\.[0-9]+\.[0-9]+)-" "$(basename "$logstash_oss_file")")
    if [[ -n "$version" ]]; then
        detected_versions["logstash_oss"]="$version"
        echo -e "${GREEN}✓ Detected Logstash OSS version: $version${NC}"
    fi
fi

# MMG version detection
mmg_file=$(find_latest_version "SCPmmg-*.rpm" "$OFFLINE_DIR")
if [[ -n "$mmg_file" ]]; then
    version=$(extract_version "SCPmmg-([0-9]+\.[0-9]+\.[0-9]+)" "$(basename "$mmg_file")")
    if [[ -n "$version" ]]; then
        detected_versions["mmg"]="$version"
        echo -e "${GREEN}✓ Detected MMG version: $version${NC}"
    fi
fi

# MMSOAP version detection
mmsoap_file=$(find_latest_version "SCPmmsoap-*.rpm" "$OFFLINE_DIR")
if [[ -n "$mmsoap_file" ]]; then
    version=$(extract_version "SCPmmsoap-([0-9]+\.[0-9]+\.[0-9]+)" "$(basename "$mmsoap_file")")
    if [[ -n "$version" ]]; then
        detected_versions["mmsoap"]="$version"
        echo -e "${GREEN}✓ Detected MMSOAP version: $version${NC}"
    fi
fi

# SMPPC version detection
smppc_file=$(find_latest_version "SCPsmppc-*.rpm" "$OFFLINE_DIR")
if [[ -n "$smppc_file" ]]; then
    version=$(extract_version "SCPsmppc-([0-9]+\.[0-9]+\.[0-9]+)" "$(basename "$smppc_file")")
    if [[ -n "$version" ]]; then
        detected_versions["smppc"]="$version"
        echo -e "${GREEN}✓ Detected SMPPC version: $version${NC}"
    fi
fi

# SLS version detection
sls_file=$(find_latest_version "SCPsls-*.tar.gz" "$OFFLINE_DIR")
if [[ -n "$sls_file" ]]; then
    version=$(extract_version "SCPsls-([0-9]+\.[0-9]+\.[0-9]+)" "$(basename "$sls_file")")
    if [[ -n "$version" ]]; then
        detected_versions["sls"]="$version"
        echo -e "${GREEN}✓ Detected SLS version: $version${NC}"
    fi
fi

# DRS version detection
drs_file=$(find_latest_version "SCPdrs-*.rpm" "$OFFLINE_DIR")
if [[ -n "$drs_file" ]]; then
    version=$(extract_version "SCPdrs-([0-9]+\.[0-9]+\.[0-9]+)" "$(basename "$drs_file")")
    if [[ -n "$version" ]]; then
        detected_versions["drs"]="$version"
        echo -e "${GREEN}✓ Detected DRS version: $version${NC}"
    fi
fi

echo ""
echo -e "${BLUE}=== Summary of Detected Versions ===${NC}"
if [[ ${#detected_versions[@]} -eq 0 ]]; then
    echo -e "${YELLOW}⚠ No package versions detected${NC}"
    exit 0
fi

# Show all detected versions
for key in "${!detected_versions[@]}"; do
    version="${detected_versions[$key]}"
    echo -e "  ${GREEN}${key}${NC}: ${version}"
done

echo ""
echo -e "${BLUE}=== Updating Version Files ===${NC}"

# Mapping from detected keys to release.yml keys
declare -A release_key_mapping
release_key_mapping["postgres"]="postgresql_full_version"
release_key_mapping["postgresql_major_version"]="postgresql_major_version"
release_key_mapping["postgresql_full_version"]="postgresql_full_version"
release_key_mapping["dmc"]="dmc_version"
release_key_mapping["mmg"]="mmg_version"
release_key_mapping["mmsoap"]="mmsoap_version"
release_key_mapping["smppc"]="smppc_version"
release_key_mapping["sls"]="sls_version"
release_key_mapping["drs"]="drs_version"
release_key_mapping["opensearch"]="opensearch_version"
release_key_mapping["logstash_oss"]="logstash_oss_version"
release_key_mapping["zabbix"]="zabbix_version"

# Update release.yml (new centralized file)
echo -e "${YELLOW}Updating ansible/vars/release.yml (centralized versions)...${NC}"
release_updated_count=0
release_failed_count=0

for key in "${!detected_versions[@]}"; do
    version="${detected_versions[$key]}"
    release_key="${release_key_mapping[$key]:-$key}"
    
    # Skip keys that don't have a mapping (like postgresql_major_version which is already set)
    if [[ -z "${release_key_mapping[$key]:-}" ]] && [[ "$key" != "postgresql_major_version" ]]; then
        continue
    fi
    
    if update_release_yml "$release_key" "$version" "$RELEASE_FILE"; then
        echo -e "${GREEN}✓ Updated $release_key to $version${NC}"
        ((release_updated_count++))
    else
        echo -e "${YELLOW}⚠ Could not update $release_key (key may not exist in release.yml)${NC}"
        ((release_failed_count++))
    fi
done

# Update config/values.yaml (for backward compatibility)
if [[ -f "$CONFIG_FILE" ]]; then
    echo ""
    echo -e "${YELLOW}Updating config/values.yaml (backward compatibility)...${NC}"
    config_updated_count=0
    config_failed_count=0
    
    for key in "${!detected_versions[@]}"; do
        version="${detected_versions[$key]}"
        # Only update keys that belong in versions: section (skip postgresql_full_version, etc.)
        if [[ "$key" =~ ^(postgres|dmc|mmg|mmsoap|smppc|sls|drs|opensearch|logstash_oss|zabbix)$ ]]; then
            if update_yaml_value "versions.$key" "$version" "$CONFIG_FILE"; then
                echo -e "${GREEN}✓ Updated versions.$key to $version${NC}"
                ((config_updated_count++))
            else
                echo -e "${YELLOW}⚠ Could not update versions.$key (key may not exist in config)${NC}"
                ((config_failed_count++))
            fi
        fi
    done
fi

# Summary
updated_count=$((release_updated_count + ${config_updated_count:-0}))
failed_count=$((release_failed_count + ${config_failed_count:-0}))

echo ""

if [[ $release_updated_count -gt 0 ]]; then
    echo -e "${GREEN}✓ Successfully updated $release_updated_count version(s) in $RELEASE_FILE${NC}"
    if [[ -f "${RELEASE_FILE}.bak" ]]; then
        echo -e "${YELLOW}Backup saved to: ${RELEASE_FILE}.bak${NC}"
    fi
fi

if [[ -f "$CONFIG_FILE" ]] && [[ ${config_updated_count:-0} -gt 0 ]]; then
    echo -e "${GREEN}✓ Successfully updated ${config_updated_count} version(s) in $CONFIG_FILE${NC}"
    if [[ -f "${CONFIG_FILE}.bak" ]]; then
        echo -e "${YELLOW}Backup saved to: ${CONFIG_FILE}.bak${NC}"
    fi
fi

if [[ $failed_count -gt 0 ]]; then
    echo -e "${YELLOW}⚠ $failed_count version(s) could not be updated (keys may not exist or update failed)${NC}"
fi

echo ""

if [[ $updated_count -gt 0 ]]; then
    echo -e "${GREEN}✓ Package version sync completed successfully${NC}"
    echo -e "${BLUE}Primary version file: $RELEASE_FILE${NC}"
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${BLUE}Backward compatibility: $CONFIG_FILE${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Package version sync completed with warnings${NC}"
fi

# Always exit with success so make prepare continues
exit 0

