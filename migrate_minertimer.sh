#!/bin/bash

# Define paths
REPO_ROOT="$PWD/mac-companion"
SOURCE_DIR="$REPO_ROOT/Sources/MinerTimer"
SCRIPTS_DIR="$REPO_ROOT/Scripts"
DOCS_DIR="$REPO_ROOT/Documentation"
LAUNCHD_DIR="$SCRIPTS_DIR/launchd"

# Create directory structure
mkdir -p "$SOURCE_DIR/Legacy"
mkdir -p "$SOURCE_DIR/Models"
mkdir -p "$SOURCE_DIR/Services"
mkdir -p "$SOURCE_DIR/Views"
mkdir -p "$SCRIPTS_DIR/launchd"
mkdir -p "$DOCS_DIR"

# Copy files to their new locations
echo "Migrating files to new structure..."

# Legacy scripts
if [ -f "/Users/Shared/minertimer/minertimer.sh" ]; then
    cp "/Users/Shared/minertimer/minertimer.sh" "$SOURCE_DIR/Legacy/"
fi

if [ -f "/Users/Shared/minertimer/extend_time.sh" ]; then
    cp "/Users/Shared/minertimer/extend_time.sh" "$SOURCE_DIR/Legacy/"
fi

# Configuration files
if [ -f "/Users/Shared/minertimer/config.sh" ]; then
    cp "/Users/Shared/minertimer/config.sh" "$SOURCE_DIR/Legacy/"
fi

if [ -f "/Users/Shared/minertimer/config2.sh" ]; then
    cp "/Users/Shared/minertimer/config2.sh" "$SOURCE_DIR/Legacy/"
fi

# LaunchDaemon
if [ -f "/Library/LaunchDaemons/com.soferio.minertimer_daily_timer.plist" ]; then
    sudo cp "/Library/LaunchDaemons/com.soferio.minertimer_daily_timer.plist" "$LAUNCHD_DIR/"
fi

# Installation script
if [ -f "install_minertimer.sh" ]; then
    cp "install_minertimer.sh" "$SCRIPTS_DIR/"
fi

# Documentation
if [ -f "DeveloperNotes.md" ]; then
    cp "DeveloperNotes.md" "$DOCS_DIR/"
fi

# Create new files if they don't exist
if [ ! -f "$SOURCE_DIR/Models/HAConfig.swift" ]; then
    cat > "$SOURCE_DIR/Models/HAConfig.swift" << 'EOL'
import Foundation

struct HAConfig: Codable {
    let baseURL: URL
    let token: String
    let entityID: String
}
EOL
fi

# Create a new installation script
cat > "$SCRIPTS_DIR/install.sh" << 'EOL'
#!/bin/bash

# New installer for Swift-based MinerTimer
APP_NAME="MinerTimer"
INSTALL_DIR="/Applications/$APP_NAME.app"
LAUNCHD_PLIST="/Library/LaunchDaemons/com.soferio.minertimer.plist"

echo "Building $APP_NAME..."
cd "$(dirname "$0")/.."
swift build -c release

echo "Creating application bundle..."
mkdir -p "$INSTALL_DIR/Contents/MacOS"
cp ".build/release/MinerTimer" "$INSTALL_DIR/Contents/MacOS/"

echo "Installing LaunchDaemon..."
sudo cp "Scripts/launchd/com.soferio.minertimer.plist" "$LAUNCHD_PLIST"
sudo launchctl load "$LAUNCHD_PLIST"

echo "Installation complete!"
EOL

chmod +x "$SCRIPTS_DIR/install.sh"

echo "Migration complete! New structure created at: $REPO_ROOT"
echo "
Next steps:
1. Review the migrated files in $SOURCE_DIR/Legacy
2. Update the Swift app code as needed
3. Test the new installation script
4. Update the LaunchDaemon configuration if needed" 