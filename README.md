# MX Light Always On

<img width="128" height="128" alt="128" src="https://github.com/user-attachments/assets/01407669-0c00-4ea7-b316-ede5f2a57ee5" />

Keep your **Logitech MX Mechanical Mini** keyboard backlight always on via Bluetooth Low Energy on macOS.

The app runs in the background with a **menu bar icon** (lightbulb) that allows you to configure settings and quit the application.

## Features

- Keep keyboard backlight always on
- Automatically saves your configuration (UUID and refresh interval)
- Visual feedback with menu bar icon (filled when configured, empty when not)
- Configurable refresh interval (default: 6.5 seconds)
- Automatically reconnects after configuration changes
- Easy installation with automated script

## Prerequisites

- macOS 10.15 or later
- Xcode Command Line Tools:
  ```bash
  xcode-select --install
  ```
- Your keyboard's UUID (find it using **LightBlue** from the Mac App Store)

## Get Device UUID

1. Download and open **LightBlue** from the Mac App Store
2. Connect to your keyboard (look for "MX MCHNCL M" or "MX Mechanical")

<img width="565" height="247" alt="image" src="https://github.com/user-attachments/assets/f4d39d3d-c4ae-4f74-84c9-1fb41fd7bf45" />

4. Copy the **Peripheral Identifier** at the top
   - Example: `44B8F2E2-ED97-6227-6712-A41AC332C9D8`

<img width="520" height="165" alt="image" src="https://github.com/user-attachments/assets/ed1b139a-2611-4199-9ae3-c295303fbcdb" />

5. You'll need this UUID to configure the app

## Installation

### Quick Install (Recommended)

Run the automated installer:

```bash
./install.sh
```

The installer will:
1. Compile the application from source
2. Create a proper macOS app bundle structure
3. Generate the required `Info.plist` file
4. Install to `~/Applications/MX Light.app`
5. Remove quarantine attributes to allow the app to run
6. Set proper permissions

After installation completes, you can:
- Open from Finder: Go to `Applications` folder (in your home directory) → Double-click `MX Light`
- Open from Terminal: `open ~/Applications/MX\ Light.app`

### Manual Build

If you prefer to build manually:

```bash
swiftc -O -o mxlight mxlight.swift -framework CoreBluetooth -framework Cocoa
./mxlight
```

**Note:** Manual builds won't have the app bundle structure and may require additional permissions setup.

## Configuration

### First Time Setup

1. Launch the app - you'll see a **lightbulb icon** (empty/outline) in the menu bar

<img width="227" height="136" alt="image" src="https://github.com/user-attachments/assets/86bccaa2-f670-41f0-b84b-c3c3396aa2f9" />

3. Click the icon and select **"Configure..."**
4. Enter your keyboard's UUID and refresh interval:
<img width="358" height="401" alt="image" src="https://github.com/user-attachments/assets/7cdf915d-a5f6-4820-bcfa-67afed716c11" />

   - **Device UUID**: The identifier you copied from LightBlue
   - **Refresh Interval**: How often to send the "keep light on" command (default: 6.5 seconds)
5. Click **"OK"** to save

Your settings are automatically saved and will be restored when you restart the app.

### Menu Bar Icon States

- **Empty lightbulb**: Not configured4
- **Filled lightbulb**: Configured and ready
- **Checkmark** in menu: Successfully keeping light on
- **X mark** in menu: Connection error

### Reconfiguring

You can change settings anytime:
1. Click the lightbulb icon
2. Select **"Configure..."**
3. Your current settings will be pre-filled
4. Make changes and click **"OK"**

The app will automatically reconnect with the new settings.

## How It Works

Once configured, the application:
- Connects to your keyboard via Bluetooth using the UUID
- Sends a "turn light ON" command immediately
- Automatically resends the command at your specified interval
- Keeps the backlight on even if the keyboard tries to auto-dim
- Remembers your settings between app restarts
- Runs quietly in the background (no Dock icon)

### Refresh Interval Recommendations

Choose the interval based on your keyboard's power source:

- **6.5 seconds** (default): Recommended when running on **battery**
  - Optimal balance between responsiveness and battery life
  - Light stays consistently on without frequent dimming

- **280 seconds** (approximately 4.7 minutes): Recommended when **plugged into power**
  - Conserves Bluetooth bandwidth
  - Reduces unnecessary communication overhead
  - Still ensures light stays on without manual intervention

**Other options:**
- **3-5 seconds**: More responsive on battery, but higher battery usage
- **10-60 seconds**: More battery-friendly, light may dim briefly before refreshing

**Minimum:** 1.0 second

## Command Line Usage

You can also run with parameters (skips configuration dialog):

```bash
./mxlight --uuid 44B8F2E2-ED97-6227-6712-A41AC332C9D8 --interval 6.5 
```

## Auto-Start at Login (Optional)

To launch the app automatically when you log in:

1. Open **System Settings** → **General** → **Login Items**
2. Click the **+** button under "Open at Login"
3. Navigate to `~/Applications/` and select **MX Light**
4. Done! The app will start automatically on login

To remove auto-start, simply remove it from Login Items in System Settings.

## Troubleshooting

### App won't connect to keyboard

- **Quit Logi Options+**: The official app may hold the Bluetooth connection
- **Disconnect in Bluetooth settings**: Go to System Settings → Bluetooth → Disconnect keyboard, then reconnect
- **Verify UUID**: Make sure you copied the correct UUID from LightBlue
- **Check Bluetooth**: Ensure Bluetooth is enabled and the keyboard is paired

### Permission issues

- **Bluetooth permission**: Grant permission when prompted on first run
- **App won't open**: Make sure Xcode Command Line Tools are installed
- **"Damaged or incomplete" error**: Run `./install.sh` again - it removes quarantine attributes

### Menu bar icon issues

- **Icon not visible**: Check if app is running in Activity Monitor
- **Empty lightbulb**: Click icon and select Configure... to set up your UUID
- **X mark showing**: Check connection, try reconfiguring

### General tips

- The app needs to stay running to keep the light on
- Quit the app by clicking the icon and selecting Quit
- Logs are printed to Terminal if you run the app from command line

## Uninstall

### Using the uninstaller script:

```bash
./uninstall.sh
```

### Manual removal:

```bash
rm -rf ~/Applications/MX\ Light.app
```

**Don't forget:** If you added the app to Login Items, remove it from System Settings.

## Technical Details

### What the installer does

The `install.sh` script:
1. Compiles Swift source code with optimization (`-O`)
2. Creates proper macOS app bundle structure (`MX Light.app/Contents/MacOS/`)
3. Generates `Info.plist` with:
   - Bundle identifier: `com.mxlight.always-on`
   - Bluetooth permission description
   - LSUIElement flag (runs without Dock icon)
4. Removes quarantine attribute (`xattr -cr`) to bypass Gatekeeper warnings

### Security note

Removing quarantine is **safe** because:
- You're compiling from visible source code
- The code is open-source and auditable
- It's your own app, not downloaded from an unknown source

For distribution, you'd need an Apple Developer account to code-sign the app.

### Data storage

Configuration is stored in macOS UserDefaults:
- Key: `com.mxlight.device.uuid` - Your keyboard's UUID
- Key: `com.mxlight.refresh.interval` - Refresh interval in seconds

## Acknowledgments

Special thanks to [@rosickey](https://github.com/rosickey) for creating the original [mxlight](https://github.com/rosickey/mxlight) project, which serves as the foundation for this fork.

## License

MIT
