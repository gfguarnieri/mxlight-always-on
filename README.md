# mxlight — Toggle Logitech MX Mechanical backlight (macOS, CoreBluetooth)

> **English • 中文在下方**

A tiny CLI for macOS that turns the **Logitech MX Mechanical / MX Mechanical Mini** backlight **ON/OFF** by writing to its private BLE characteristic via **CoreBluetooth**.

**Repository contains:** a single Swift source file `mxlight.swift` (provided in the issue/README context) and this README.

---

## Overview (EN)

This command-line tool connects to your Logitech MX Mechanical / MX Mechanical Mini over Bluetooth Low Energy and writes a short command to a private characteristic to toggle the keyboard backlight.

- **Service**: `00010000-0000-1000-8000-011F2000046D`
- **Characteristic (write + notify)**: `00010001-0000-1000-8000-011F2000046D`

**Payloads**

- **OFF**: `0b1e000000000000`
- **ON** : `0b1e010000000000`

The app accepts `--on` or `--off`. Optionally pass `--uuid <device-UUID>` to connect even when the keyboard isn’t advertising.

> ⚠️ Payloads are firmware-specific and were verified against **MX Mechanical Mini (Bluetooth)**. Other models/firmware may differ; capture frames with a BLE logger if needed.

### Features
- Works offline (no Logitech software required).
- Uses CoreBluetooth, no kernel extensions.
- `--uuid` lets you connect even if the device isn’t advertising (using `retrievePeripherals`).
- Prints notification frames (if your firmware echoes them).

### Supported / Tested
- Logitech **MX Mechanical Mini (Bluetooth)** on macOS.

---

## Prerequisites (EN)

- macOS with **Xcode Command Line Tools**  
  ```bash
  xcode-select --install
  ```
- First run will ask for **Bluetooth permission**.
- Optional: **LightBlue** (Mac App Store) to find your device UUID.

---

## Get your device UUID with LightBlue (EN)

1. Open **LightBlue** and connect to your keyboard (`MX MCHNCL M` / `MX Mechanical`).
2. Copy the **Peripheral Identifier** (looks like `6D6299B8-F57F-04B3-7285-E0A5C0448F00`).
3. You can now run `mxlight` with `--uuid <that-UUID>` to connect without advertising.

> If you can’t get the UUID, you can omit `--uuid`. In that case the tool will **scan**, which requires the keyboard to be **advertising** (e.g., switch it to an empty slot so it starts advertising).

---

## Build (EN)

```bash
swiftc -O -o mxlight mxlight.swift -framework CoreBluetooth
```

---

## Run (EN)

```bash
# Turn backlight OFF
./mxlight --off --uuid 6D6299B8-F57F-04B3-7285-E0A5C0448F00

# Turn backlight ON
./mxlight --on  --uuid 6D6299B8-F57F-04B3-7285-E0A5C0448F00
```

Without `--uuid` (requires advertising):
```bash
./mxlight --off
```

### Expected output (EN)

```
write 00010001-0000-1000-8000-011F2000046D 0b1e000000000000
[notify] 0b1e000000000000000000000000000000
```

> Notifications may vary by firmware; some devices echo an ACK, others are silent. A successful **write with response** is sufficient to toggle the light.

---

## How it works (EN)

- The app uses **CoreBluetooth** to connect and discover the private Logitech service/characteristic.
- It writes an 8‑byte payload to `00010001-...` with **response** enabled.
- If notifications are enabled by the device, they are printed to stdout.

**High-level flow:**
1. Power on Bluetooth → retrieve by `--uuid` or scan for service `0x00010000`.
2. Discover characteristic `0x00010001`.
3. Enable notify (for logs) and write the ON/OFF payload.
4. Wait ~1s for potential notify and exit.

---

## Troubleshooting (EN)

- **Cannot connect / times out**  
  - Quit **Logi Options+** (it may hold the BLE connection).  
  - Temporarily **Disconnect** the keyboard in macOS Bluetooth and run the tool; or pass `--uuid`.
- **Tool doesn’t find device without `--uuid`**  
  - The keyboard must be **advertising**. Switch it to an unused slot to begin advertising, then run the tool.
- **Different model/firmware**  
  - Payloads may differ. Capture your ON/OFF frames using LightBlue (Log tab) or Apple PacketLogger, then substitute the payloads in `mxlight.swift`.

---

## Security & Permissions (EN)

- The app requests **Bluetooth** permission (first run).
- No Accessibility or HID permissions are needed—this tool only talks to BLE.

---

## License

MIT (or choose another license you prefer).

---

# 中文说明（ZH）

## 概述

`mxlight` 是一个在 macOS 上运行的命令行工具，通过 **CoreBluetooth** 连接到罗技 **MX Mechanical / MX Mechanical Mini（蓝牙版）**，向其私有特征写入命令实现**开/关背光**。

- **服务**：`00010000-0000-1000-8000-011F2000046D`
- **特征（写入 + 通知）**：`00010001-0000-1000-8000-011F2000046D`

**载荷（Payload）**

- **关灯**：`0b1e000000000000`
- **开灯**：`0b1e010000000000`

运行时使用 `--on` 或 `--off` 指定操作；可选 `--uuid <设备UUID>`，即使设备不在广播也能连接。

> ⚠️ 上述报文基于 **MX Mechanical Mini（蓝牙版）** 实测。不同机型/固件可能不同，必要时请先抓包确认。

### 特性
- 无需官方软件、无需联网。
- 纯 **CoreBluetooth**，无内核扩展。
- 支持 `--uuid` 直连（无需广播）。

### 已测试
- 罗技 **MX Mechanical Mini（蓝牙）**。

---

## 前置条件

- macOS + **Xcode 命令行工具**  
  ```bash
  xcode-select --install
  ```
- 首次运行会请求 **蓝牙权限**。
- 可选：**LightBlue**（Mac App Store）用于查看设备 UUID。

---

## 用 LightBlue 获取设备 UUID

1. 打开 **LightBlue**，连接键盘（“MX MCHNCL M” / “MX Mechanical”）。
2. 复制顶部的 **Peripheral Identifier（UUID）**，例如 `6D6299B8-F57F-04B3-7285-E0A5C0448F00`。
3. 运行本工具时加入 `--uuid <该UUID>`，即使设备不在广播也能连接。

> 如果没有 UUID，也可以不加 `--uuid`，此时程序会**扫描**；但需要键盘处于**广播状态**（例如切换到空闲配对槽以开始广播）。

---

## 编译

```bash
swiftc -O -o mxlight mxlight.swift -framework CoreBluetooth
```

---

## 运行

```bash
# 关灯
./mxlight --off --uuid 6D6299B8-F57F-04B3-7285-E0A5C0448F00

# 开灯
./mxlight --on  --uuid 6D6299B8-F57F-04B3-7285-E0A5C0448F00
```

省略 `--uuid`（需设备在广播）：
```bash
./mxlight --off
```

### 预期输出

```
write 00010001-0000-1000-8000-011F2000046D 0b1e000000000000
[notify] 0b1e000000000000000000000000000000
```

> 是否回通知取决于固件；就算没有通知，只要 **write with response** 成功也能完成开/关。

---

## 工作原理

- 程序使用 **CoreBluetooth** 连接设备，发现并打开罗技的私有服务/特征。
- 向 `00010001-...` 特征写入 8 字节载荷（带响应）。
- 若固件会通知，则把通知以十六进制打印出来。

**流程概览：**
1. 蓝牙就绪 → 通过 `--uuid` 检索连接，或扫描服务 `0x00010000`；
2. 发现特征 `0x00010001`；
3. 启用通知（用于日志）并写入开/关载荷；
4. 等待约 1 秒以接收可能的通知后退出。

---

## 常见问题

- **连不上/超时**  
  - 退出 **Logi Options+**（可能占用连接）；  
  - 在系统蓝牙里临时“断开”键盘后再运行；或使用 `--uuid` 直连。
- **不加 `--uuid` 找不到设备**  
  - 必须处于**广播**状态。把键盘切到空闲配对槽以开始广播，再运行工具。
- **不同型号/固件**  
  - 载荷可能不同。请用 LightBlue（Log 页）或 PacketLogger 抓“开/关灯”帧后替换 `mxlight.swift` 中的载荷。

---

## 权限说明

- 第一次运行会弹出**蓝牙**权限请求。  
- 程序不需要辅助功能或 HID 权限——只通过 BLE 通信。

---

## 许可

MIT（或按你的需要替换成其他协议）。
