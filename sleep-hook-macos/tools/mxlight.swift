import Foundation
import CoreBluetooth

let svc10000 = CBUUID(string: "00010000-0000-1000-8000-011F2000046D")
let charCmd  = CBUUID(string: "00010001-0000-1000-8000-011F2000046D")

enum Mode { case on, off }
struct Args {
    var mode: Mode
    var uuid: UUID? = nil
}
func parseArgs() -> Args? {
    var m: Mode? = nil
    var u: UUID? = nil
    var i = 1
    while i < CommandLine.arguments.count {
        let a = CommandLine.arguments[i]
        if a == "--on" { m = .on }
        else if a == "--off" { m = .off }
        else if a == "--uuid", i+1 < CommandLine.arguments.count {
            u = UUID(uuidString: CommandLine.arguments[i+1]); i += 1
        }
        i += 1
    }
    guard let mm = m else { return nil }
    return Args(mode: mm, uuid: u)
}

final class App: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager!
    private var targetUUID: UUID?
    private var mode: Mode
    private var periph: CBPeripheral?
    private var cmdChar: CBCharacteristic?

    init(mode: Mode, uuid: UUID?) {
        self.mode = mode
        self.targetUUID = uuid
        super.init()
        self.central = CBCentralManager(delegate: self, queue: .main)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if let u = targetUUID {
                // 优先用 retrieve，不依赖广播
                let arr = central.retrievePeripherals(withIdentifiers: [u])
                if let p = arr.first {
                    self.periph = p
                    p.delegate = self
                    central.connect(p, options: nil)
                    return
                } else {
                    // 退化到扫描
                    central.scanForPeripherals(withServices: [svc10000], options: nil)
                }
            } else {
                central.scanForPeripherals(withServices: [svc10000], options: nil)
            }
        default:
            fputs("Bluetooth not ready: \(central.state.rawValue)\n", stderr)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // 名称匹配也接受
        let name = (peripheral.name ?? "").uppercased()
        if name.contains("MX MCHNCL") || name.contains("MX MECHANICAL") {
            self.periph = peripheral
            peripheral.delegate = self
            central.stopScan()
            central.connect(peripheral, options: nil)
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
            // 写命令（带响应）
            let payload: [UInt8] = (mode == .off)
                ? [0x0b,0x1e,0x00,0x00,0x00,0x00,0x00,0x00]
                : [0x0b,0x1e,0x01,0x00,0x00,0x00,0x00,0x00]
            let data = Data(payload)
            print("write \(c.uuid.uuidString) \(data.map { String(format:"%02x",$0) }.joined())")
            peripheral.writeValue(data, for: c, type: .withResponse)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let e = error {
            fputs("write error: \(e)\n", stderr)
            CFRunLoopStop(CFRunLoopGetMain())
        } else {
            // 给设备 1s 发回 notify，再退出
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                CFRunLoopStop(CFRunLoopGetMain())
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

if let args = parseArgs() {
    let app = App(mode: args.mode, uuid: args.uuid)
    CFRunLoopRun()
} else {
    print("""
    用法:
      swiftc -O -o mxlight mxlight.swift -framework CoreBluetooth
      ./mxlight --off [--uuid <LightBlue里的UUID>]
      ./mxlight --on  [--uuid <LightBlue里的UUID>]

    说明:
      - 建议先退出 Logi Options+；若连接失败，可在系统蓝牙里“断开”键盘或切到空闲槽，再运行。
      - 若你有 LightBlue 看到的 UUID，建议加上 --uuid，可不依赖广播直接连接。
    """)
}
