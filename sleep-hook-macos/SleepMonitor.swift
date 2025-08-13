import Foundation
import AppKit
import CoreGraphics
import IOKit
import IOKit.graphics

// ======= 配置：指令与时间窗口 =======
let commandA: String = "/Users/m2p/src/code/keyboard/mxlight --off --uuid 6D6299B8-F57F-04B3-7285-E0A5C0448F00"
let commandB: String = "/Users/m2p/src/code/keyboard/mxlight --on  --uuid 6D6299B8-F57F-04B3-7285-E0A5C0448F00"

// 夜间窗口：17:00 ~ 次日 07:00
let nightStartHour = 17
let nightEndHour   = 7

// 去抖（秒）
let debounceSeconds: TimeInterval = 4.0

// 日志
let logPath = (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
    .appendingPathComponent("Library/Logs/mxlight-sleep-monitor.log")

// ======= 工具 =======
func log(_ s: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    let line = "[\(ts)] \(s)\n"
    guard let data = line.data(using: .utf8) else { return }
    if !FileManager.default.fileExists(atPath: logPath) {
        FileManager.default.createFile(atPath: logPath, contents: nil)
    }
    if let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
        defer { try? h.close() }
        _ = try? h.seekToEnd()
        try? h.write(contentsOf: data)
    }
    fputs(line, stdout)
}

@discardableResult
func runShell(_ command: String) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = ["-lc", command]
    let outPipe = Pipe(), errPipe = Pipe()
    p.standardOutput = outPipe; p.standardError = errPipe
    do { try p.run() } catch {
        log("❌ 启动命令失败: \(command)  error=\(error)")
        return -1
    }
    p.waitUntilExit()
    if let d = try? outPipe.fileHandleForReading.readToEnd(),
       let s = String(data: d, encoding: .utf8), !s.isEmpty {
        log("ℹ️ [stdout] \(s.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
    if let d = try? errPipe.fileHandleForReading.readToEnd(),
       let s = String(data: d, encoding: .utf8), !s.isEmpty {
        log("ℹ️ [stderr] \(s.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
    let status = p.terminationStatus
    log("✅ 命令结束: \(command)  status=\(status)")
    return status
}

func isInNightWindow(_ date: Date = Date()) -> Bool {
    let hour = Calendar.current.component(.hour, from: date)
    return (hour >= nightStartHour) || (hour < nightEndHour)
}

enum EventKind { case sleepLike, wakeLike }

// ======= IODisplayWrangler 监听器（核心） =======
// ======= IODisplayWrangler 监听器（用 PM 状态变化判定 on/off） =======
final class DisplayWranglerWatcher {
    private var notifyPort: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private var wrangler: io_service_t = 0
    private var started = false

    private var lastPMState: Int? = nil   // 记录上一次的 CurrentPowerState
    private var onSleep: (() -> Void)?
    private var onWake:  (() -> Void)?

    deinit {
        if notifier != 0 { IOObjectRelease(notifier); notifier = 0 }
        if wrangler != 0 { IOObjectRelease(wrangler); wrangler = 0 }
        if let p = notifyPort {
            CFRunLoopRemoveSource(CFRunLoopGetMain(),
                                  IONotificationPortGetRunLoopSource(p).takeUnretainedValue(),
                                  .defaultMode)
            IONotificationPortDestroy(p)
            notifyPort = nil
        }
    }

    func start(onSleep: @escaping () -> Void, onWake: @escaping () -> Void) {
        guard !started else { return }
        started = true
        self.onSleep = onSleep
        self.onWake  = onWake

        guard let matching = IOServiceMatching("IODisplayWrangler") else {
            log("⚠️ IOServiceMatching(IODisplayWrangler) 失败")
            return
        }
        wrangler = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        if wrangler == 0 {
            log("⚠️ 未找到 IODisplayWrangler 服务")
            return
        }

        // 先读取一次初始电源状态，仅记录，不触发
        lastPMState = readPMState()
        if let s = lastPMState {
            log("🔌 IODisplayWrangler 初始 PM state=\(s) (\(s >= 2 ? "ON" : "SLEEP"))（仅记录，不触发）")
        } else {
            log("🔌 IODisplayWrangler 初始 PM state 读取失败")
        }

        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let np = notifyPort else {
            log("⚠️ IONotificationPortCreate 失败")
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(),
                           IONotificationPortGetRunLoopSource(np).takeUnretainedValue(),
                           .defaultMode)

        // 注册兴趣通知；回调里不看 msgType，直接读取 PM 状态判断 on/off
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let kr = IOServiceAddInterestNotification(
            np,
            wrangler,
            kIOGeneralInterest,
            { (refcon, service, msgType, msgArg) in
                let me = Unmanaged<DisplayWranglerWatcher>.fromOpaque(refcon!).takeUnretainedValue()
                me.handlePowerChange()
            },
            selfPtr,
            &notifier
        )
        if kr != KERN_SUCCESS {
            log("⚠️ IOServiceAddInterestNotification 失败: \(kr)")
        } else {
            log("✅ IODisplayWrangler 监听已启动")
        }
    }

    private func readPMState() -> Int? {
        guard wrangler != 0 else { return nil }
        guard let pm = IORegistryEntryCreateCFProperty(
            wrangler,
            "IOPowerManagement" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSDictionary,
              let cur = pm["CurrentPowerState"] as? Int else {
            return nil
        }
        return cur
    }

    private func handlePowerChange() {
        guard let cur = readPMState() else {
            log("ℹ️ IODisplayWrangler: 无法读取 PM 状态（忽略）")
            return
        }
        let prev = lastPMState
        lastPMState = cur

        // 初次无前态，或状态未变，不动作
        guard let p = prev, p != cur else {
            log("ℹ️ IODisplayWrangler: PM state=\(cur)（无变化，忽略）")
            return
        }

        let wasOn  = (p   >= 2)
        let nowOn  = (cur >= 2)

        if wasOn && !nowOn {
            log("📥 IODisplayWrangler: ON → SLEEP（捕捉到显示器睡眠）")
            onSleep?()     // 例如 pmset displaysleepnow 时会来到这里
        } else if !wasOn && nowOn {
            log("📤 IODisplayWrangler: SLEEP → ON（捕捉到显示器点亮）")
            onWake?()
        } else {
            // 其它跨档位变化，同样按 on/off 归类
            log("ℹ️ IODisplayWrangler: PM \(p) → \(cur)")
            if nowOn { onWake?() } else { onSleep?() }
        }
    }
}
// ======= 主监控 =======
final class SleepWakeMonitor {
    private var lastSleepLike: Date = .distantPast
    private var lastWakeLike:  Date = .distantPast
    private let wrangler = DisplayWranglerWatcher()

    func start() {
        log("🚀 启动 mxlight 监控（IODisplayWrangler + 系统休眠）...")

        // 1) IODisplayWrangler：准确捕捉 pmset displaysleepnow 的显示器睡眠/点亮
        wrangler.start(
            onSleep: { [weak self] in self?.handleSleep(reason: "IODisplayWrangler.DeviceWillPowerOff") },
            onWake:  { [weak self] in self?.handleWake (reason: "IODisplayWrangler.DeviceHasPoweredOn") }
        )

        // 2) 系统级（可留作冗余）：整机休眠/唤醒
        let wsNC = NSWorkspace.shared.notificationCenter
        wsNC.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSleep(reason: "NSWorkspace.willSleep")
        }
        wsNC.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleWake(reason: "NSWorkspace.didWake")
        }

        RunLoop.main.run()
    }

    private func shouldIgnore(kind: EventKind) -> Bool {
        let now = Date()
        switch kind {
        case .sleepLike:
            if now.timeIntervalSince(lastSleepLike) < debounceSeconds { return true }
            lastSleepLike = now
        case .wakeLike:
            if now.timeIntervalSince(lastWakeLike) < debounceSeconds { return true }
            lastWakeLike = now
        }
        return false
    }

    private func handleSleep(reason: String) {
        if shouldIgnore(kind: .sleepLike) {
            log("⏱️ 忽略重复 Sleep 事件（去抖）：\(reason)")
            return
        }
        log("🌙 Sleep：\(reason) -> 执行 A")
        _ = runShell(commandA)
    }

    private func handleWake(reason: String) {
        if shouldIgnore(kind: .wakeLike) {
            log("⏱️ 忽略重复 Wake 事件（去抖）：\(reason)")
            return
        }
        let inNight = isInNightWindow()
        log("☀️ Wake：\(reason)  夜间窗口=\(inNight)")
        if inNight {
            log("➡️ 在 17:00~次日07:00 范围内，执行 B")
            _ = runShell(commandB)
        } else {
            log("➡️ 非夜间窗口，不执行 B")
        }
    }
}

// 全局强引用，避免被提前释放
let monitor = SleepWakeMonitor()

@main
struct Main {
    static func main() {
        monitor.start()
    }
}
