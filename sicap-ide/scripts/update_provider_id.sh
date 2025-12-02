#!/bin/bash
# Update Provider ID Script
# This script queries the database for the actual provider ID and updates configuration files
# Run this AFTER DMC is installed and provider is created via web interface

set -e

# Configuration - can be overridden by environment variables
DMC_CONF_DIR="${DMC_CONF_DIR:-/opt/dmc/current/conf}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-dmc46}"
DB_USER="${DB_USER:-dmc4}"
DB_PASSWORD="${DB_PASSWORD:-dmc4}"
PROVIDER_NAME="${PROVIDER_NAME:-sicap}"
DMC_SERVICE_NAME="${DMC_SERVICE_NAME:-dmc}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Updating Provider ID in DMC configuration files...${NC}"

# Check if PostgreSQL client is available
if ! command -v psql &> /dev/null; then
    echo -e "${RED}Error: psql command not found. Please install PostgreSQL client.${NC}"
    exit 1
fi

# Query database for provider ID
echo "Querying database for provider ID..."
PROVIDER_ID=$(psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -t -c "SELECT id FROM eu_provider WHERE name = '$PROVIDER_NAME' ORDER BY id DESC LIMIT 1;" 2>/dev/null | xargs)

if [ -z "$PROVIDER_ID" ] || [ "$PROVIDER_ID" = "" ]; then
    echo -e "${RED}Error: Provider '$PROVIDER_NAME' not found in database.${NC}"
    echo "Please create the provider via DMC web interface first."
    exit 1
fi

echo -e "${GREEN}Found provider ID: $PROVIDER_ID${NC}"

# Update cm-EndUser.properties
if [ -f "$DMC_CONF_DIR/cm-EndUser.properties" ]; then
    echo "Updating cm-EndUser.properties..."
    sed -i.bak "s/provider\.[0-9]*=/provider.$PROVIDER_ID=/g" "$DMC_CONF_DIR/cm-EndUser.properties"
    echo -e "${GREEN}✓ Updated cm-EndUser.properties${NC}"
else
    echo -e "${YELLOW}Warning: cm-EndUser.properties not found${NC}"
fi

# Update rest-api.properties
if [ -f "$DMC_CONF_DIR/rest-api.properties" ]; then
    echo "Updating rest-api.properties..."
    sed -i.bak "s/cache\.providers\.list = [0-9]*/cache.providers.list = $PROVIDER_ID/" "$DMC_CONF_DIR/rest-api.properties"
    echo -e "${GREEN}✓ Updated rest-api.properties${NC}"
else
    echo -e "${YELLOW}Warning: rest-api.properties not found${NC}"
fi

# Update cm-DMCDeployMode.properties
if [ -f "$DMC_CONF_DIR/cm-DMCDeployMode.properties" ]; then
    echo "Updating cm-DMCDeployMode.properties..."
    sed -i.bak "s/deployedProviderId=[0-9]*/deployedProviderId=$PROVIDER_ID/" "$DMC_CONF_DIR/cm-DMCDeployMode.properties"
    echo -e "${GREEN}✓ Updated cm-DMCDeployMode.properties${NC}"
else
    echo -e "${YELLOW}Warning: cm-DMCDeployMode.properties not found${NC}"
fi

echo -e "${GREEN}Provider ID update completed successfully!${NC}"
echo "Provider ID $PROVIDER_ID has been applied to all configuration files."

# Restart DMC service
echo "Restarting DMC service..."
if systemctl is-active --quiet "$DMC_SERVICE_NAME"; then
    systemctl restart "$DMC_SERVICE_NAME"
    echo -e "${GREEN}✓ DMC service restarted${NC}"
else
    echo -e "${YELLOW}Warning: DMC service is not running${NC}"
fi

echo ""
echo -e "${GREEN}Provider ID update completed!${NC}"
echo "Provider ID $PROVIDER_ID has been applied and DMC service restarted."
echo "Please verify the configuration is working correctly."
