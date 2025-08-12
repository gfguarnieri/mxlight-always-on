#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SleepHook"
APP_SRC="$(pwd)/build/${APP_NAME}.app"
APP_DST="/Applications/${APP_NAME}.app"

if [ ! -d "$APP_SRC" ]; then
  echo "❌ $APP_SRC not found. Run ./build.sh first."; exit 1
fi

echo "📦 Installing to $APP_DST"
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

CFG_DIR="$HOME/Library/Application Support/${APP_NAME}"
mkdir -p "$CFG_DIR"
CFG_FILE="$CFG_DIR/config.json"

if [ ! -f "$CFG_FILE" ]; then
cat > "$CFG_FILE" <<'JSON'
{
  "uuid": "6D6299B8-F57F-04B3-7285-E0A5C0448F00",
  "nightStart": "17:00",
  "nightEnd":   "07:00",
  "triggerOnDisplaySleep": true,
  "triggerOnDisplayWake":  true,
  "triggerOnScreensaver":  false,
  "launchAtLogin": true
}
JSON
fi

open "$APP_DST"
echo "✅ Installed. A 🌙 icon should appear in the menu bar."
echo "   Preferences… can set UUID / night window / login item."
