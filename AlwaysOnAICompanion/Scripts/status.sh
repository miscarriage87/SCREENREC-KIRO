#!/bin/bash

BUNDLE_ID="com.alwaysonai.recorderdaemon"
LOG_DIR="$HOME/Library/Logs/AlwaysOnAICompanion"

echo "Always-On AI Companion Status"
echo "============================="

if launchctl list | grep -q "$BUNDLE_ID"; then
    echo "✅ RecorderDaemon is running"
else
    echo "❌ RecorderDaemon is not running"
fi

echo ""
echo "Recent logs:"
echo "------------"
if [[ -f "$LOG_DIR/stdout.log" ]]; then
    tail -5 "$LOG_DIR/stdout.log"
else
    echo "No stdout logs found"
fi

if [[ -f "$LOG_DIR/stderr.log" ]]; then
    echo ""
    echo "Recent errors:"
    echo "--------------"
    tail -5 "$LOG_DIR/stderr.log"
fi
