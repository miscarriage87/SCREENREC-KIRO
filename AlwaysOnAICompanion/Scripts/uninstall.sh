#!/bin/bash

BUNDLE_ID="com.alwaysonai.recorderdaemon"
LAUNCH_AGENT_NAME="com.alwaysonai.recorderdaemon.plist"
PLIST_PATH="/Users/cpohl/Library/LaunchAgents/$LAUNCH_AGENT_NAME"

echo "Uninstalling Always-On AI Companion..."

# Unload the LaunchAgent
if launchctl list | grep -q "$BUNDLE_ID"; then
    echo "Stopping RecorderDaemon..."
    launchctl unload -w "$PLIST_PATH"
fi

# Remove the plist file
if [[ -f "$PLIST_PATH" ]]; then
    echo "Removing LaunchAgent plist..."
    rm "$PLIST_PATH"
fi

echo "Uninstallation completed"
echo "Note: You may want to manually remove permissions from System Preferences > Privacy & Security"
