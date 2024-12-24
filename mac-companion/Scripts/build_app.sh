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

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.soferio.minertimer</string>
    <key>CFBundleName</key>
    <string>MinerTimer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>CFBundleExecutable</key>
    <string>MinerTimer</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOL

echo "App bundle created at $APP_BUNDLE" 