#!/bin/bash

# Ensure directories exist
sudo mkdir -p /Users/Shared/minertimer
sudo chown $USER /Users/Shared/minertimer
mkdir -p ~/Library/LaunchAgents

# Copy app to Applications
sudo cp -R MinerTimer.app /Applications/
sudo chown -R $USER /Applications/MinerTimer.app

# Migrate config
./Scripts/migrate_config.sh

# Set up persistence directory
sudo mkdir -p /Users/Shared/minertimer
sudo chown $USER /Users/Shared/minertimer
touch /Users/Shared/minertimer/timestate.json
chmod 644 /Users/Shared/minertimer/timestate.json

# Set up password file
echo "Enter password for adding time:"
read -s password
echo "$password" > /Users/Shared/minertimer/password.txt
chmod 600 /Users/Shared/minertimer/password.txt

# Create LaunchAgent plist
cat > ~/Library/LaunchAgents/com.soferio.minertimer.plist << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.soferio.minertimer</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/MinerTimer.app/Contents/MacOS/MinerTimer</string>
        <string>--service</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StandardOutPath</key>
    <string>/Users/Shared/minertimer/service.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/Shared/minertimer/service.error.log</string>
    <key>WorkingDirectory</key>
    <string>/Users/Shared/minertimer</string>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
</dict>
</plist>
EOL

# Install LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.soferio.minertimer.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.soferio.minertimer.plist

# Set up logging
touch /Users/Shared/minertimer/service.log
touch /Users/Shared/minertimer/service.error.log

# Add new instructions
echo "3. Install the MinerTimer integration from HACS (see https://github.com/kburbank/minertimer-ha)"

echo "Installation complete. You may need to:"
echo "1. Allow MinerTimer in System Preferences → Security & Privacy → Privacy → Accessibility"
echo "2. Allow MinerTimer in System Preferences → Security & Privacy → Privacy → Full Disk Access"
