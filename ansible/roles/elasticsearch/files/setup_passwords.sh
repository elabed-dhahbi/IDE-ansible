#!/bin/bash

# Elasticsearch Password Setup Script
# This script sets up Elasticsearch passwords using the correct idempotency check

set -e

ELASTICSEARCH_HOST="192.168.6.131"
ELASTICSEARCH_PORT="9200"
NEW_PASSWORD="elastic"

echo "Checking if Elasticsearch is running..."

# Wait for Elasticsearch to be running first
for i in {1..30}; do
    if curl -s "http://$ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT/_cluster/health" > /dev/null 2>&1; then
        echo "✓ Elasticsearch is running"
        break
    fi
    echo "Waiting for Elasticsearch to start... (attempt $i/30)"
    sleep 2
done

# Check if Elasticsearch is running
if ! curl -s "http://$ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT/_cluster/health" > /dev/null 2>&1; then
    echo "✗ Elasticsearch is not running - cannot set passwords"
    exit 1
fi

echo "Checking if Elasticsearch passwords are already set correctly..."

# Use _security/_authenticate to check if elastic:elastic works (proper idempotency check)
auth_response=$(curl -s -u "elastic:$NEW_PASSWORD" "http://$ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT/_security/_authenticate" 2>/dev/null || echo "")
auth_username=$(echo "$auth_response" | grep -o '"username":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ "$auth_username" = "elastic" ]; then
    echo "✓ Elasticsearch passwords are already set correctly!"
    echo "✓ User 'elastic' authenticated successfully"
    echo "✓ All users already have password: $NEW_PASSWORD"
    echo ""
    echo "Test the connection:"
    echo "curl -u elastic:$NEW_PASSWORD http://$ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT/_cluster/health?pretty"
    exit 0
fi

echo "✗ Authentication failed - passwords not set correctly"
echo "Response: $auth_response"

# If we get here, passwords are not set, so we need to set them up
echo "Setting up initial passwords using elasticsearch-setup-passwords..."

cd /usr/share/elasticsearch

# Use expect to automate the setup-passwords interactive mode
expect << 'EOF'
spawn bin/elasticsearch-setup-passwords interactive
expect "Please confirm that you would like to continue \\\[y/N\\\]"
send "y\r"
expect "Enter password for \\\[elastic\\\]:"
send "elastic\r"
expect "Reenter password for \\\[elastic\\\]:"
send "elastic\r"
expect "Enter password for \\\[apm_system\\\]:"
send "elastic\r"
expect "Reenter password for \\\[apm_system\\\]:"
send "elastic\r"
expect "Enter password for \\\[kibana_system\\\]:"
send "elastic\r"
expect "Reenter password for \\\[kibana_system\\\]:"
send "elastic\r"
expect "Enter password for \\\[logstash_system\\\]:"
send "elastic\r"
expect "Reenter password for \\\[logstash_system\\\]:"
send "elastic\r"
expect "Enter password for \\\[beats_system\\\]:"
send "elastic\r"
expect "Reenter password for \\\[beats_system\\\]:"
send "elastic\r"
expect "Enter password for \\\[remote_monitoring_user\\\]:"
send "elastic\r"
expect "Reenter password for \\\[remote_monitoring_user\\\]:"
send "elastic\r"
expect eof
EOF

echo "Initial password setup completed!"
echo "All Elasticsearch users now have password: $NEW_PASSWORD"
echo ""
echo "Test the connection:"
echo "curl -u elastic:$NEW_PASSWORD http://$ELASTICSEARCH_HOST:$ELASTICSEARCH_PORT/_cluster/health?pretty"
