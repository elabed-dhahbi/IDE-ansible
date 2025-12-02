#!/bin/bash
# Test YAML parsing fix

CONFIG_FILE="config/values.yaml"

echo "=== Testing YAML parsing fix ==="
echo "Config file: $CONFIG_FILE"
echo ""

echo "=== Testing extract_yaml_value function ==="
extract_yaml_value() {
    local key="$1"
    local yaml_file="$2"
    
    local parent="${key%%.*}"
    local child="${key#*.}"
    
    awk -v parent="$parent" -v child="$child" '
        /^[[:space:]]*'$parent':[[:space:]]*$/ { in_block=1; next }
        in_block && /^[[:space:]]*'$child':[[:space:]]*/ {
            gsub(/["\x27]/, "", $2)
            gsub(/\r$/, "", $2)  # Remove carriage return
            print $2
            exit
        }
    ' "$yaml_file"
}

# Test pgdg_repo_rpm extraction
echo "Testing package_globs.pgdg_repo_rpm extraction:"
result=$(extract_yaml_value "package_globs.pgdg_repo_rpm" "$CONFIG_FILE")
echo "Result: '$result'"
echo "Length: ${#result}"

# Test if it matches the file
echo ""
echo "=== Testing file matching ==="
if [[ -f "/tmp/offline/$result" ]]; then
    echo "✓ File found: /tmp/offline/$result"
else
    echo "✗ File not found: /tmp/offline/$result"
    echo "Available files:"
    ls -la /tmp/offline/ | grep pgdg
fi




