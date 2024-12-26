#!/bin/bash

CONFIG_FILE="/Users/Shared/minertimer/config.json"

if [ -f "$CONFIG_FILE" ]; then
    # Check if it has the old format with entity_id
    if grep -q "entity_id" "$CONFIG_FILE"; then
        echo "Migrating config.json to new format..."
        # Create temp file without entity_id
        jq 'del(.entity_id)' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
    fi
fi 