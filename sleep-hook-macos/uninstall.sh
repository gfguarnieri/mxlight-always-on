#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SleepHook"
APP_DST="/Applications/${APP_NAME}.app"
AGENT_PLIST="$HOME/Library/LaunchAgents/com.example.sleephook.menu.plist"

launchctl unload "$AGENT_PLIST" 2>/dev/null || true
rm -f "$AGENT_PLIST"
rm -rf "$APP_DST"

echo "🧹 Removed app & LaunchAgent. Config/log kept at:"
echo "    ~/Library/Application Support/${APP_NAME}/"
