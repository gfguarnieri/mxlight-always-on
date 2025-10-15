# MX Light Always On

Keep your **Logitech MX Mechanical Mini** keyboard backlight always on via Bluetooth Low Energy on macOS.

The app runs in the background with a **menu bar icon** (lightbulb 💡) that allows you to quit the application.

## Prerequisites

- macOS with Xcode Command Line Tools:
  ```bash
  xcode-select --install
  ```
- Your keyboard's UUID (find it using **LightBlue** from the Mac App Store)

## Get Device UUID

1. Open **LightBlue** and connect to your keyboard (MX MCHNCL M / MX Mechanical)
2. Copy the **Peripheral Identifier** (e.g., `44B8F2E2-ED97-6227-6712-A41AC332C9D8`)

## Build

```bash
swiftc -O -o mxlight mxlight.swift -framework CoreBluetooth -framework Cocoa
```

## Run

Simply execute the program - a dialog will appear to configure the UUID and refresh interval:

```bash
./mxlight
```

Or pass parameters directly via command line:

```bash
./mxlight --uuid 44B8F2E2-ED97-6227-6712-A41AC332C9D8 --interval 6.5
```

### Configuration Dialog

When you run the program without arguments, a dialog will appear asking for:

1. **Device UUID**: The unique identifier of your keyboard (find it using LightBlue)
2. **Refresh Interval**: How often to send the "keep light on" command (default: 6.5 seconds)
   - Recommended: **6.5 seconds** (optimal balance between responsiveness and battery life)
   - Minimum: 1.0 second

### How It Works

The application will:
- Show a **lightbulb icon** in the menu bar (near the clock)
- Send a "turn light ON" command immediately upon connection
- **Automatically resend** the command at your specified interval to keep the light always on
- Display a checkmark (✓) when the light is successfully turned on
- Keep running in the background to maintain the light on
- Allow you to quit by clicking the icon and selecting "Quit"

The periodic refresh ensures the keyboard backlight stays on even if the keyboard tries to turn it off automatically.

## Run as Background Service (LaunchAgent)

To keep the light always on, even after sleep/wake and system restarts:

1. **Edit the plist file** with your keyboard's UUID and desired interval:
   ```bash
   nano com.mxlight.always-on.plist
   ```
   Update line 12 with your UUID.
   Optionally, add `<string>--interval</string>` and `<string>6.5</string>` to customize the refresh interval.

2. **Copy the compiled binary**:
   ```bash
   sudo mkdir -p /Applications/mxlight.app/Contents/MacOS
   sudo cp mxlight /Applications/mxlight.app/Contents/MacOS/
   ```

3. **Install the LaunchAgent**:
   ```bash
   cp com.mxlight.always-on.plist ~/Library/LaunchAgents/
   launchctl load ~/Library/LaunchAgents/com.mxlight.always-on.plist
   ```

4. **Check logs** (if needed):
   ```bash
   tail -f /tmp/mxlight.out.log
   tail -f /tmp/mxlight.err.log
   ```

### Uninstall Background Service

```bash
launchctl unload ~/Library/LaunchAgents/com.mxlight.always-on.plist
rm ~/Library/LaunchAgents/com.mxlight.always-on.plist
```

## Troubleshooting

- **Cannot connect**: Quit **Logi Options+** first, or disconnect the keyboard in system Bluetooth settings
- **Permission required**: Grant Bluetooth permission when prompted on first run
- **Menu bar icon not visible**: Check if the app is running - it should show a lightbulb icon near the clock
- **To quit the app**: Click the lightbulb icon in the menu bar and select "Quit"

## Acknowledgments

Special thanks to [@rosickey](https://github.com/rosickey) for creating the original [mxlight](https://github.com/rosickey/mxlight) project, which serves as the foundation for this fork.

## License

MIT

