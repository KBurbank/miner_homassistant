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
