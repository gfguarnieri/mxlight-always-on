import Foundation
import CoreBluetooth
import Cocoa

let svc10000 = CBUUID(string: "00010000-0000-1000-8000-011F2000046D")
let charCmd  = CBUUID(string: "00010001-0000-1000-8000-011F2000046D")

struct Args {
    var uuid: UUID
    var interval: TimeInterval
}
func promptForSettings() -> (uuid: UUID, interval: TimeInterval)? {
    let alert = NSAlert()
    alert.messageText = "Logitech MX Mechanical Mini - Configuration"
    alert.informativeText = "Please enter the UUID of your Logitech MX Mechanical Mini keyboard and the refresh interval.\n\nYou can find the UUID using LightBlue or similar Bluetooth scanning app:"
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")

    let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 70))

    // UUID Field
    let uuidLabel = NSTextField(labelWithString: "Device UUID:")
    uuidLabel.frame = NSRect(x: 0, y: 46, width: 300, height: 17)
    containerView.addSubview(uuidLabel)

    let uuidTextField = NSTextField(frame: NSRect(x: 0, y: 24, width: 300, height: 24))
    uuidTextField.placeholderString = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
    containerView.addSubview(uuidTextField)

    // Interval Field
    let intervalLabel = NSTextField(labelWithString: "Refresh Interval (seconds):")
    intervalLabel.frame = NSRect(x: 0, y: 7, width: 220, height: 17)
    containerView.addSubview(intervalLabel)

    let intervalTextField = NSTextField(frame: NSRect(x: 220, y: 0, width: 80, height: 24))
    intervalTextField.placeholderString = "6.5"
    intervalTextField.stringValue = "6.5"
    containerView.addSubview(intervalTextField)

    alert.accessoryView = containerView
    alert.window.initialFirstResponder = uuidTextField

    let response = alert.runModal()

    if response == .alertFirstButtonReturn {
        let uuidInput = uuidTextField.stringValue.trimmingCharacters(in: .whitespaces)
        let intervalInput = intervalTextField.stringValue.trimmingCharacters(in: .whitespaces)

        guard let uuid = UUID(uuidString: uuidInput) else {
            if !uuidInput.isEmpty {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Invalid UUID Format"
                errorAlert.informativeText = "The UUID you entered is not valid. Please check the format and try again."
                errorAlert.alertStyle = .warning
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
            }
            return nil
        }

        let interval = Double(intervalInput) ?? 6.5
        if interval < 1.0 {
            let errorAlert = NSAlert()
            errorAlert.messageText = "Invalid Interval"
            errorAlert.informativeText = "The interval must be at least 1.0 second."
            errorAlert.alertStyle = .warning
            errorAlert.addButton(withTitle: "OK")
            errorAlert.runModal()
            return nil
        }

        return (uuid, interval)
    }

    return nil
}

func parseArgs() -> Args? {
    var u: UUID? = nil
    var interval: TimeInterval = 6.5
    var i = 1
    while i < CommandLine.arguments.count {
        let a = CommandLine.arguments[i]
        if a == "--uuid", i+1 < CommandLine.arguments.count {
            u = UUID(uuidString: CommandLine.arguments[i+1]); i += 1
        } else if a == "--interval", i+1 < CommandLine.arguments.count {
            interval = Double(CommandLine.arguments[i+1]) ?? 6.5; i += 1
        }
        i += 1
    }

    // If UUID is not provided via argument, show GUI prompt
    if u == nil {
        guard let settings = promptForSettings() else { return nil }
        u = settings.uuid
        interval = settings.interval
    }

    guard let uu = u else { return nil }
    return Args(uuid: uu, interval: interval)
}

final class App: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, NSApplicationDelegate {
    private var central: CBCentralManager!
    private var targetUUID: UUID
    private var periph: CBPeripheral?
    private var cmdChar: CBCharacteristic?
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var refreshInterval: TimeInterval

    init(uuid: UUID, interval: TimeInterval) {
        self.targetUUID = uuid
        self.refreshInterval = interval
        super.init()
        self.setupMenuBar()
        self.central = CBCentralManager(delegate: self, queue: .main)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "lightbulb.fill", accessibilityDescription: "MX Light")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let statusMenuItem = NSMenuItem(title: "MX Light Always On", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        statusItem?.menu = menu
    }

    @objc private func quitApp() {
        timer?.invalidate()
        timer = nil
        if let peripheral = periph {
            central.cancelPeripheralConnection(peripheral)
        }
        NSApplication.shared.terminate(nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            let arr = central.retrievePeripherals(withIdentifiers: [targetUUID])
            if let p = arr.first {
                self.periph = p
                p.delegate = self
                central.connect(p, options: nil)
            } else {
                fputs("Device with UUID \(targetUUID) not found\n", stderr)
                CFRunLoopStop(CFRunLoopGetMain())
            }
        default:
            fputs("Bluetooth not ready: \(central.state.rawValue)\n", stderr)
            CFRunLoopStop(CFRunLoopGetMain())
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([svc10000])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for s in peripheral.services ?? [] {
            if s.uuid == svc10000 {
                peripheral.discoverCharacteristics([charCmd], for: s)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for c in service.characteristics ?? [] where c.uuid == charCmd {
            self.cmdChar = c
            peripheral.setNotifyValue(true, for: c)
            sendCommand()
        }
    }

    private func sendCommand() {
        guard let c = cmdChar, let p = periph else { return }
        let payload: [UInt8] = [0x0b,0x1e,0x01,0x00,0x00,0x00,0x00,0x00]
        let data = Data(payload)
        print("write \(c.uuid.uuidString) \(data.map { String(format:"%02x",$0) }.joined())")
        p.writeValue(data, for: c, type: .withResponse)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let e = error {
            fputs("write error: \(e)\n", stderr)
            updateMenuBarStatus(success: false)
        } else {
            print("Light turned ON successfully")
            updateMenuBarStatus(success: true)

            // Setup timer to keep sending command at specified interval
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
                    self?.sendCommand()
                }
                print("Always-on mode activated: sending command every \(refreshInterval) seconds")
            }
        }
    }

    private func updateMenuBarStatus(success: Bool) {
        if let menu = statusItem?.menu {
            if let statusMenuItem = menu.items.first {
                statusMenuItem.title = success ? "MX Light Always On ✓" : "MX Light Always On ✗"
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let e = error { fputs("notify error: \(e)\n", stderr) }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let d = characteristic.value {
            print("[notify]", d.map { String(format:"%02x",$0) }.joined())
        }
    }
}

NSApplication.shared.setActivationPolicy(.accessory)

if let args = parseArgs() {
    let app = App(uuid: args.uuid, interval: args.interval)
    NSApplication.shared.delegate = app
    NSApplication.shared.run()
} else {
    print("""
    Usage:
      swiftc -O -o mxlight mxlight.swift -framework CoreBluetooth -framework Cocoa
      ./mxlight [--uuid <UUID from LightBlue>] [--interval <seconds>]

    Notes:
      - This program turns the keyboard light ON and keeps it on.
      - If UUID is not provided via --uuid, a dialog will appear to enter it and configure the refresh interval.
      - Default refresh interval is 6.5 seconds (recommended).
      - You can find the UUID using LightBlue or similar Bluetooth scanning app.
      - Recommended to quit Logi Options+ first. If connection fails, you can "disconnect" the keyboard in system Bluetooth settings or switch to an idle slot, then run again.
      - A menu bar icon will appear. Click it to quit the application.
    """)
}
