#!/bin/bash
# Test YAML parsing

CONFIG_FILE="config/values.yaml"

# Function to extract values from YAML using POSIX tools
extract_yaml_value() {
    local key="$1"
    local yaml_file="$2"
    
    # Handle nested keys like paths.offline_dir
    local parent="${key%%.*}"
    local child="${key#*.}"
    
    if [[ "$parent" == "$child" ]]; then
        # Simple key (no nesting)
        grep -E "^[[:space:]]*${key}:" "$yaml_file" | \
        sed -E 's/^[[:space:]]*[^:]+:[[:space:]]*["\x27]?([^"\x27]*?)["\x27]?[[:space:]]*#.*$/\1/' | \
        sed -E 's/^[[:space:]]*[^:]+:[[:space:]]*["\x27]?([^"\x27]*?)["\x27]?[[:space:]]*$/\1/' | \
        head -1
    else
        # Nested key - find parent section first
        awk -v parent="$parent" -v child="$child" '
            $1 == parent ":" { in_section = 1; next }
            in_section && /^[[:space:]]*[a-zA-Z]/ && $1 != parent ":" { in_section = 0 }
            in_section && $1 == child ":" {
                gsub(/[[:space:]]*#.*$/, "", $0)  # Remove comments
                gsub(/^[[:space:]]*[^:]+:[[:space:]]*["\x27]?/, "", $0)  # Remove key and quotes
                gsub(/["\x27][[:space:]]*$/, "", $0)  # Remove trailing quotes
                print $0
                exit
            }
        ' "$yaml_file"
    fi
}

echo "Testing YAML parsing..."
echo "Config file: $CONFIG_FILE"
echo ""

# Test offline_dir extraction
echo "Testing paths.offline_dir extraction:"
offline_dir=$(extract_yaml_value "paths.offline_dir" "$CONFIG_FILE")
echo "Result: '$offline_dir'"
echo ""

# Test versions.dmc extraction
echo "Testing versions.dmc extraction:"
dmc_version=$(extract_yaml_value "versions.dmc" "$CONFIG_FILE")
echo "Result: '$dmc_version'"
echo ""

# Test package_globs.dmc_rpm extraction
echo "Testing package_globs.dmc_rpm extraction:"
dmc_pattern=$(extract_yaml_value "package_globs.dmc_rpm" "$CONFIG_FILE")
echo "Result: '$dmc_pattern'"




