#!/bin/bash

# MX Light Always On - Installation Script
# This script compiles and installs the application

set -e

echo "========================================="
echo "MX Light Always On - Installer"
echo "========================================="
echo ""

# Check if Swift compiler is available
if ! command -v swiftc &> /dev/null; then
    echo "Error: Swift compiler not found."
    echo "Please install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

# Compile the application
echo "Step 1: Compiling mxlight..."
swiftc -O -o mxlight mxlight.swift -framework CoreBluetooth -framework Cocoa

if [ ! -f "mxlight" ]; then
    echo "Error: Compilation failed."
    exit 1
fi

echo "✓ Compilation successful"
echo ""

# Install to user Applications folder
echo "Step 2: Installing application..."
APP_NAME="MX Light"
APP_PATH="$HOME/Applications/$APP_NAME.app"
CONTENTS_PATH="$APP_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

# Create app bundle structure
mkdir -p "$MACOS_PATH"
mkdir -p "$RESOURCES_PATH"

# Copy binary
cp mxlight "$MACOS_PATH/$APP_NAME"
chmod +x "$MACOS_PATH/$APP_NAME"

# Create Info.plist
cat > "$CONTENTS_PATH/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.mxlight.always-on</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>This app needs Bluetooth access to control your Logitech MX Mechanical Mini keyboard backlight.</string>
</dict>
</plist>
EOF

echo "✓ Installed to $APP_PATH"

# Remove quarantine attribute
echo ""
echo "Removing quarantine attribute..."
xattr -cr "$APP_PATH"
echo "✓ Quarantine removed"

echo ""
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo ""

echo "The app has been installed to:"
echo "  $HOME/Applications/MX Light.app"
echo ""
echo "To run the app:"
echo "  1. Open Finder"
echo "  2. Go to Applications (in your home folder)"
echo "  3. Double-click 'MX Light'"
echo "  4. Look for the lightbulb icon in your menu bar"
echo "  5. Click the icon and select 'Configure...' to set your keyboard UUID"
echo ""
echo "Or run from Terminal:"
echo "  open '$HOME/Applications/MX Light.app'"
echo ""
echo "For more information, see the README.md file."
echo ""
