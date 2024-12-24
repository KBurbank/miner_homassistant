#!/bin/bash

# Get SDK path
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

# Get architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    TARGET="arm64-apple-macosx10.15"
else
    TARGET="x86_64-apple-macosx10.15"
fi

# Build with explicit settings
swift build \
  -Xswiftc "-sdk" \
  -Xswiftc "$SDK_PATH" \
  -Xswiftc "-target" \
  -Xswiftc "$TARGET"

# Check build result
if [ $? -eq 0 ]; then
    echo "Build successful!"
else
    echo "Build failed!"
    exit 1
fi 