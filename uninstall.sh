#!/bin/bash

# MX Light Always On - Uninstallation Script

echo "========================================="
echo "MX Light Always On - Uninstaller"
echo "========================================="
echo ""

APP_PATH="$HOME/Applications/MX Light.app"

if [ -d "$APP_PATH" ]; then
    echo "Removing application..."
    rm -rf "$APP_PATH"
    echo "✓ Application removed from $APP_PATH"
else
    echo "Application not found at $APP_PATH"
fi

echo ""
echo "Note: If you added the app to Login Items in System Settings,"
echo "you may want to remove it manually from:"
echo "System Settings > General > Login Items"

echo ""
echo "========================================="
echo "Uninstallation Complete!"
echo "========================================="
echo ""
