#!/bin/zsh

###
# Core MINERTIMER script. Kills minecraft Java edition on MacOS after 30 min.
# Developed and owned by Soferio Pty Limited.
###

# Time limit in minutes
TIME_LIMIT=15
WEEKEND_TIME_LIMIT=30
DISPLAY_5_MIN_WARNING=true
DISPLAY_1_MIN_WARNING=true

# Process name to monitor
PROCESS_NAME="java"

# Directory and file to store total played time for the day
LOG_DIRECTORY="/var/lib/minertimer"
LOG_FILE="${LOG_DIRECTORY}/minertimer_playtime.log"

# Source Home Assistant configuration
CONFIG_FILE="/Users/Shared/minertimer/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found at $CONFIG_FILE"
    echo "Would you like to create one? You will first need to get a long-lived access token from Home Assistant's profile page. (y/n)"
    read answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo "Creating new config file..."
        echo "Enter Home Assistant URL (e.g., http://homeassistant:8123):"
        read hass_url
        echo "Enter Home Assistant Long-Lived Access Token:"
        read -s hass_token
        echo "Enter Home Assistant Entity ID (e.g., input_number.usage_limit):"
        read hass_entity
        
        # Create config file
        cat > "$CONFIG_FILE" << EOL
# Home Assistant Configuration
HASS_URL="$hass_url"
HASS_TOKEN="$hass_token"
HASS_ENTITY="$hass_entity"
EOL
        echo "Config file created at $CONFIG_FILE"
    else
        echo "ERROR: Config file required to run minertimer" >&2
        exit 1
    fi
fi

source "$CONFIG_FILE"

# Create the directory (don't throw error if already exists)
mkdir -p $LOG_DIRECTORY

# Get the current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Function to write all three lines to log file
write_log_file() {
    local date="$1"
    local limit="$2"
    local playtime="$3"
    echo "$date" > "$LOG_FILE"
    echo "$limit" >> "$LOG_FILE"
    echo "$playtime" >> "$LOG_FILE"
}

# Read the last play date, current limit, and total played time from the log file
if [ -f "$LOG_FILE" ]; then
    LAST_PLAY_DATE=$(head -n 1 "$LOG_FILE")
    STORED_LIMIT=$(sed -n '2p' "$LOG_FILE")
    TOTAL_PLAYED_TIME=$(sed -n '3p' "$LOG_FILE")
    echo "DEBUG: Read from log file:"
    echo "  Date: $LAST_PLAY_DATE"
    echo "  Stored limit: $STORED_LIMIT"
    echo "  Total played time: $TOTAL_PLAYED_TIME"
    
    # Initialize to 0 if empty or invalid
    if [ -z "$TOTAL_PLAYED_TIME" ] || ! [[ "$TOTAL_PLAYED_TIME" =~ ^[0-9]*\.?[0-9]+$ ]]; then
        echo "DEBUG: Invalid total played time, resetting to 0"
        TOTAL_PLAYED_TIME=0
        write_log_file "$LAST_PLAY_DATE" "$STORED_LIMIT" "0"
    fi
else
    LAST_PLAY_DATE="$CURRENT_DATE"
    STORED_LIMIT=0
    TOTAL_PLAYED_TIME=0
    write_log_file "$CURRENT_DATE" "0" "0"
fi

# If it's a new day, or first use, reset the playtime
if [ "$LAST_PLAY_DATE" != "$CURRENT_DATE" ]; then
    TOTAL_PLAYED_TIME=0
    STORED_LIMIT=0
    write_log_file "$CURRENT_DATE" "0" "0"
fi

# Function to get current limit from Home Assistant
get_hass_limit() {
    local response
    local limit
    
    # Fetch the current state from Home Assistant
    response=$(curl -s -X GET \
        -H "Authorization: Bearer $HASS_TOKEN" \
        -H "Content-Type: application/json" \
        "$HASS_URL/api/states/$HASS_ENTITY")
    
    # Extract the state value (already in minutes)
    limit=$(echo "$response" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)
    
    # Check if we got a valid number (integer or float)
    if [[ "$limit" =~ ^[0-9]+\.?[0-9]*$ ]] && [ ! -z "$limit" ]; then
        # Test if we can do arithmetic with it
        if (( $(echo "$limit >= 0" | bc -l) )); then
            # Store the successful HA limit
            sed -i '' "2s/.*/$limit/" "$LOG_FILE"
            echo "DEBUG: Got limit from Home Assistant: $limit" >&2
            echo "$limit"
            return
        fi
    fi
    
    # If we get here, either HA failed or returned invalid value
    # Try stored limit first
    if [[ "$STORED_LIMIT" =~ ^[0-9]+\.?[0-9]*$ ]] && [ ! -z "$STORED_LIMIT" ]; then
        if (( $(echo "$STORED_LIMIT > 0" | bc -l) )); then
            echo "DEBUG: Using stored limit: $STORED_LIMIT" >&2
            echo "$STORED_LIMIT"
            return
        fi
    fi
    
    # Fall back to defaults if both HA and stored limit failed
    if [[ $(date +%u) -gt 5 ]]; then
        echo "DEBUG: Using weekend default limit: $WEEKEND_TIME_LIMIT" >&2
        echo "$WEEKEND_TIME_LIMIT"
    else
        echo "DEBUG: Using default limit: $TIME_LIMIT" >&2
        echo "$TIME_LIMIT"
    fi
}

while true; do
    # Check if app is running and not suspended
    # Only get the first matching PID
    MINECRAFT_PID=$(ps aux | grep -iww "[${PROCESS_NAME:0:1}]${PROCESS_NAME:1}" | awk '{print $2}' | head -n 1)
    
    # If the process is not running, then sleep for 5 seconds.
    if [ -z "$MINECRAFT_PID" ]; then
        echo "DEBUG: $PROCESS_NAME is not running, sleeping for 5 seconds" >&2
        sleep 5
        continue
    fi

    # Get current limit from Home Assistant
    current_limit=$(get_hass_limit)
    
    # Remove the weekend override since it's now handled in get_hass_limit
    # if [[ $(date +%u) -gt 5 ]]; then
    #     current_limit=$WEEKEND_TIME_LIMIT
    # fi
    
    # Only proceed with ps check if MINECRAFT_PID is not empty
    if [ -n "$MINECRAFT_PID" ]; then
        # Check state of single PID
        if ps -o state= -p "$MINECRAFT_PID" 2>/dev/null | grep -q "^R\|^S"; then

            # If the time limit has been reached
            if ((TOTAL_PLAYED_TIME >= $current_limit)); then
                say "Total played time: $TOTAL_PLAYED_TIME minutes is over current limit: $current_limit minutes"
                kill -STOP "$MINECRAFT_PID"
                say "$PROCESS_NAME time has expired"
                echo "$PROCESS_NAME has been closed after reaching the daily time limit."

                afplay /System/Library/Sounds/Glass.aiff
            # 5 minute warning
            elif ((TOTAL_PLAYED_TIME >= $current_limit - 5)) && [ "$DISPLAY_5_MIN_WARNING" = true ]; then
                
                say "$PROCESS_NAME time will expire in 5 minutes"
                DISPLAY_5_MIN_WARNING=false
            # 1 minute warning
            elif ((TOTAL_PLAYED_TIME >= $current_limit - 1)) && [ "$DISPLAY_1_MIN_WARNING" = true ]; then

                say "$PROCESS_NAME time will expire in 1 minute"
                DISPLAY_1_MIN_WARNING=false
            fi
            echo "Sleeping for 15 seconds. Current played time: $TOTAL_PLAYED_TIME. Current limit: $current_limit"
            # Sleep for 15 seconds, then increment
            sleep 15
            TOTAL_PLAYED_TIME=$(echo "$TOTAL_PLAYED_TIME + 0.25" | bc)  # Use bc for floating point
            
            # Update the total played time in the log file
            sed -i '' "3s/.*/$TOTAL_PLAYED_TIME/" "$LOG_FILE"
            

        elif [ -n "$MINECRAFT_PID" ] && ps -o state= -p "$MINECRAFT_PID" | grep -q "^T"; then

            # compare played time to the current limit. if it's less than the limit, then unpause the process
            if ((TOTAL_PLAYED_TIME < $current_limit)); then
                say "Unpausing $PROCESS_NAME"
                kill -CONT "$MINECRAFT_PID"
            fi
        else
            echo "DEBUG: Nothing happened with $PROCESS_NAME" >&2
            sleep 10
        fi

        # Get the current date
        CURRENT_DATE=$(date +%Y-%m-%d)

        # Read the last play date from the log file
        if [ -f "$LOG_FILE" ]; then
            LAST_PLAY_DATE=$(head -n 1 "$LOG_FILE")
        else
            # This error should not happen because log file created above
            echo "ERROR - NO LOG FILE"
        fi

        # If it's a new day, reset the playtime
        if [ "$LAST_PLAY_DATE" != "$CURRENT_DATE" ]; then
            TOTAL_PLAYED_TIME=0
            STORED_LIMIT=0
            write_log_file "$CURRENT_DATE" "0" "0"
            echo "RESET DATE - $CURRENT_DATE"
        fi
    fi
done
