#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SleepHook"
BUILD_DIR="$(pwd)/build"
APP_DIR="$BUILD_DIR/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
BIN_DIR="$RESOURCES/bin"

echo "🧱 Building…"
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS" "$BIN_DIR"

# 1) 编译菜单栏 App
swiftc -O -framework AppKit -framework Foundation -o "$MACOS/$APP_NAME" app/MenuApp.swift

# 2) 编译工具二进制
swiftc -O -framework CoreBluetooth -o "$BIN_DIR/mxlight" tools/mxlight.swift
swiftc -O -framework AppKit -framework Foundation -o "$BIN_DIR/sleep-hook" tools/sleep-hook.swift

# 3) 拷贝 Info.plist
cp Info.plist "$CONTENTS/Info.plist"

echo "✅ Built $APP_DIR"
echo "   └─ Resources/bin/mxlight"
echo "   └─ Resources/bin/sleep-hook"
