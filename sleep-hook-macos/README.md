# SleepHook (menu bar app for macOS)

Run Logitech MX keyboard backlight **OFF** when Mac sleeps / display sleeps, and turn it **ON** on wake **only during a night window**.

Includes:
- Menu bar app with **Preferences** (UUID, night window, login item, triggers)
- Bundled tools: `mxlight` (BLE light toggle) and CLI `sleep-hook`
- One-command build & install scripts
- Logs & config under `~/Library/Application Support/SleepHook/`

## Features
- Display sleep or system sleep → **OFF** (Command A)
- Wake or display on → if within **17:00–07:00** → **ON** (Command B)
- Preferences: set **UUID**, **time window**, **launch at login**, **trigger toggles**
- Uses Distributed Power Management notifications for stable display sleep/wake
- No Dock icon (menu bar only)

## Build & Install
```bash
chmod +x build.sh install.sh uninstall.sh
./build.sh
./install.sh
```
The app is copied to `/Applications/SleepHook.app` and launched. A 🌙 icon appears in the menu bar.

## Configure (Preferences)
- **UUID**: the keyboard's Bluetooth identifier
- **Night window**: `"HH:mm"` (cross-day supported, e.g. 17:00–07:00)
- **Launch at login**: toggles a user LaunchAgent
- **Triggers**: whether to react to display sleep/wake and screensaver

Config file (auto-created):
```
~/Library/Application Support/SleepHook/config.json
```

## Get your UUID with LightBlue
1. Install **LightBlue** from the Mac App Store.
2. Power on and wake your keyboard.
3. In LightBlue → **Peripherals**, find your MX keyboard, tap **Connect**.
4. Copy the **Identifier / UUID** shown at the top (not service/characteristic UUIDs).
5. Paste the UUID into the app Preferences (or edit `config.json`).

> Tip: If `mxlight` needs Bluetooth permission, run it once from Terminal to trigger the prompt:
> ```bash
> /Applications/SleepHook.app/Contents/Resources/bin/mxlight --off --uuid <YOUR-UUID>
> ```

## Test
```bash
pmset displaysleepnow     # should trigger OFF (A)
pmset sleepnow            # sleep -> OFF, wake (night) -> ON
tail -f ~/Library/Application\ Support/SleepHook/SleepHook.log
```

## Uninstall
```bash
./uninstall.sh
```

## Notes
- Unsigned app: the first launch may require allowing in System Settings → Privacy & Security.
- `sleep-hook.swift` is included for reference; the menu app already handles events itself.

---

# SleepHook（中文说明）

当 Mac **系统睡眠 / 显示器息屏** 时自动**关灯**；当 **唤醒** 且处于 **夜间时段（默认 17:00–次日 07:00）** 时自动**开灯**。  
内置：
- 菜单栏程序（偏好设置里可配置 **UUID、时间段、开机自启、触发项**）
- 工具：`mxlight`（BLE 控灯）与 `sleep-hook` CLI（保留源码）
- 一键构建与安装脚本

## 构建与安装
```bash
chmod +x build.sh install.sh uninstall.sh
./build.sh
./install.sh
```
安装后在右上角出现 🌙 图标。

## 偏好设置
- **UUID**：键盘的蓝牙标识（使用 LightBlue 获取）
- **夜间时段**：`"HH:mm"`，支持跨日（如 17:00–07:00）
- **开机自启动**：启用/禁用用户级 LaunchAgent
- **触发项**：是否响应“仅息屏/亮屏”、屏保等

配置文件：
```
~/Library/Application Support/SleepHook/config.json
```

## 使用 LightBlue 获取 UUID
1. 在 Mac App Store 安装 **LightBlue**。
2. 打开键盘电源并唤醒。
3. 在 LightBlue 的 **Peripherals** 列表连接键盘。
4. 复制顶部显示的 **Identifier / UUID**（不是服务/特征 UUID）。
5. 粘贴到应用偏好设置（或直接修改 `config.json`）。

> 提示：若首次需蓝牙权限，可在终端手动运行一次：
> ```
> /Applications/SleepHook.app/Contents/Resources/bin/mxlight --off --uuid <你的UUID>
> ```

## 卸载
```bash
./uninstall.sh
```

## 说明
- 应用未签名，首次运行可能需在「系统设置 → 隐私与安全性」允许打开。
- `sleep-hook.swift` 仅作为参考，菜单栏应用本身已监听系统/显示睡眠。
