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
INSTALL_PATH="$HOME/Applications/mxlight.app/Contents/MacOS"
mkdir -p "$INSTALL_PATH"
cp mxlight "$INSTALL_PATH/"
chmod +x "$INSTALL_PATH/mxlight"
echo "✓ Installed to $INSTALL_PATH"

echo ""

# Ask if user wants to set up LaunchAgent
echo "Step 3: Auto-start configuration"
echo ""
read -p "Do you want to configure the app to start automatically at login? [y/N]: " setup_launchagent

if [[ $setup_launchagent =~ ^[Yy]$ ]]; then
    echo ""
    read -p "Enter your keyboard UUID: " keyboard_uuid

    # Validate UUID format
    if ! [[ $keyboard_uuid =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
        echo "Warning: UUID format doesn't look valid, but continuing anyway..."
    fi

    read -p "Enter refresh interval in seconds [6.5]: " refresh_interval
    refresh_interval=${refresh_interval:-6.5}

    BINARY_PATH="$HOME/Applications/mxlight.app/Contents/MacOS/mxlight"

    # Create LaunchAgent plist
    PLIST_PATH="$HOME/Library/LaunchAgents/com.mxlight.always-on.plist"

    cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key> <string>com.mxlight.always-on</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BINARY_PATH</string>
    <string>--uuid</string>
    <string>$keyboard_uuid</string>
    <string>--interval</string>
    <string>$refresh_interval</string>
  </array>
  <key>RunAtLoad</key> <true/>
  <key>KeepAlive</key> <true/>

  <key>LimitLoadToSessionType</key> <string>Aqua</string>

  <key>StandardOutPath</key> <string>/tmp/mxlight.out.log</string>
  <key>StandardErrorPath</key> <string>/tmp/mxlight.err.log</string>
</dict>
</plist>
EOF

    echo "✓ LaunchAgent plist created at $PLIST_PATH"
    echo ""

    # Load the LaunchAgent
    read -p "Do you want to start the service now? [Y/n]: " start_now
    if [[ ! $start_now =~ ^[Nn]$ ]]; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        launchctl load "$PLIST_PATH"
        echo "✓ Service started"
        echo ""
        echo "The app is now running in the background."
        echo "Look for the lightbulb icon in your menu bar."
    else
        echo ""
        echo "Service not started. You can start it later with:"
        echo "  launchctl load $PLIST_PATH"
    fi

    echo ""
    echo "Logs are available at:"
    echo "  Output: /tmp/mxlight.out.log"
    echo "  Errors: /tmp/mxlight.err.log"
fi

echo ""
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo ""

if [[ $setup_launchagent =~ ^[Yy]$ ]]; then
    echo "The app will start automatically at login."
    echo ""
    echo "To uninstall, run:"
    echo "  launchctl unload $PLIST_PATH"
    echo "  rm $PLIST_PATH"
else
    echo "You can run the app manually with:"
    echo "  $BINARY_PATH"
fi

echo ""
echo "For more information, see the README.md file."
echo ""
