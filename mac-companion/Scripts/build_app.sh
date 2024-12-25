#!/bin/bash

set -e  # Exit on any error

APP_NAME="MinerTimer"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean previous builds
if [ -d ".build" ]; then
    chmod -R u+w .build
    rm -rf .build
fi
rm -rf "$APP_BUNDLE"

# Build using the build script
chmod +x Scripts/build.sh
./Scripts/build.sh

# Create app bundle structure
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Determine build directory based on architecture
if [ "$(uname -m)" = "arm64" ]; then
    BUILD_DIR=".build/arm64-apple-macosx/debug"
else
    BUILD_DIR=".build/x86_64-apple-macosx/debug"
fi

# Copy executable
if [ ! -f "$BUILD_DIR/MinerTimer" ]; then
    echo "Error: Executable not found at $BUILD_DIR/MinerTimer"
    exit 1
fi

cp "$BUILD_DIR/MinerTimer" "$MACOS_DIR/"

# Copy Info.plist
cp "Sources/MinerTimer/Info.plist" "$CONTENTS_DIR/"

# Build complete
echo "App bundle created at $APP_BUNDLE"

# Run install script if --install flag is provided
if [[ "$1" == "--install" ]]; then
    echo "Installing MinerTimer..."
    chmod +x Scripts/install.sh
    ./Scripts/install.sh
fi 