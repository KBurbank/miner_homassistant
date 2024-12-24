#!/bin/bash

# Try to find the config file
CONFIG_PATH="/Users/Shared/minertimer/config.sh"

if [ ! -f "$CONFIG_PATH" ]; then
    echo "Error: Could not find config file at $CONFIG_PATH"
    exit 1
fi

# Source the config file
source "$CONFIG_PATH"

# Parse the URL to get host and port
if [[ $HASS_URL =~ http://([^:/]+):([0-9]+) ]]; then
    HASS_HOST="${BASH_REMATCH[1]}"
    HASS_PORT="${BASH_REMATCH[2]}"
else
    echo "Error: Could not parse HASS_URL"
    exit 1
fi

echo "Extracted config values:"
echo "HASS_HOST: $HASS_HOST"
echo "HASS_PORT: $HASS_PORT"
echo "HASS_ENTITY: $HASS_ENTITY"
echo "HASS_TOKEN: ${HASS_TOKEN:0:10}..." # Show only first 10 chars

# Create config directory
CONFIG_DIR="$HOME/Library/Application Support/MinerTimer"
mkdir -p "$CONFIG_DIR"

# Create config.json with proper JSON escaping
cat > "$CONFIG_DIR/config.json" << EOL
{
    "baseURL": "${HASS_URL}",
    "token": "$(echo $HASS_TOKEN | sed 's/"/\\"/g')",
    "entityID": "$(echo $HASS_ENTITY | sed 's/"/\\"/g')"
}
EOL

echo -e "\nConfig migrated to $CONFIG_DIR/config.json"
echo -e "\nVerifying JSON format:"
if command -v jq >/dev/null 2>&1; then
    jq . "$CONFIG_DIR/config.json"
else
    cat "$CONFIG_DIR/config.json"
fi

echo -e "\nTesting URL access:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "${HASS_URL}" 