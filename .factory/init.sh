#!/bin/bash
set -e

# Ensure xcode-select points to Xcode.app
CURRENT_DEV_DIR=$(xcode-select -p 2>/dev/null || echo "")
if [ "$CURRENT_DEV_DIR" != "/Applications/Xcode.app/Contents/Developer" ]; then
    echo "WARNING: xcode-select not pointing to Xcode.app. Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi

# Verify Xcode is available
if ! DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version &>/dev/null; then
    echo "ERROR: Xcode not found at /Applications/Xcode.app"
    exit 1
fi

# Check for iOS simulator runtime
SIM_RUNTIMES=$(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list runtimes 2>&1 | grep -c "iOS" || true)
if [ "$SIM_RUNTIMES" -eq 0 ]; then
    echo "WARNING: No iOS simulator runtimes installed. Tests will fail."
    echo "Run: xcodebuild -downloadPlatform iOS"
fi

echo "Focus app environment ready."
