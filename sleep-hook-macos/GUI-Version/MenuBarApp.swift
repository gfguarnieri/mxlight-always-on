import SwiftUI
import AppKit
import ServiceManagement
import Foundation
import CoreGraphics
import IOKit
import IOKit.graphics

@main
struct MenuBarApp: App {
    @StateObject private var appState = AppState()
    
    @SceneBuilder
    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        
        createMenuBarExtra()
    }
    
    private func createMenuBarExtra() -> some Scene {
        return menuBarExtraScene
    }
    
    @available(macOS 13.0, *)
    private var modernMenuBarScene: some Scene {
        MenuBarExtra("菜单栏应用", systemImage: "star.fill") {
            ContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
    
    private var legacyMenuBarScene: some Scene {
        // 对于旧版本macOS，创建一个隐藏的窗口
        WindowGroup("Hidden") {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowStyle(.hiddenTitleBar)
    }
    
    private var menuBarExtraScene: some Scene {
        if #available(macOS 13.0, *) {
            return modernMenuBarScene
        } else {
            return legacyMenuBarScene
        }
    }
    
    init() {
        // 应用程序初始化代码
    }
}

// 应用程序状态管理
class AppState: ObservableObject {
    @Published var launchAtLogin: Bool = false
    @Published var keyboardMonitorEnabled: Bool = false
    
    // 键盘监控配置
    @Published var mxlightPath: String = "/Users/m2p/src/code/keyboard/mxlight"
    @Published var keyboardUUID: String = "6D6299B8-F57F-04B3-7285-E0A5C0448F00"
    @Published var nightStartHour: Int = 17
    @Published var nightEndHour: Int = 7
    @Published var debounceSeconds: Double = 4.0
    
    private var sleepWakeMonitor: SleepWakeMonitor?
    
    init() {
        // 从用户默认设置中读取启动设置
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        self.keyboardMonitorEnabled = UserDefaults.standard.bool(forKey: "keyboardMonitorEnabled")
        
        // 读取键盘监控配置
        if let path = UserDefaults.standard.string(forKey: "mxlightPath") {
            self.mxlightPath = path
        }
        if let uuid = UserDefaults.standard.string(forKey: "keyboardUUID") {
            self.keyboardUUID = uuid
        }
        self.nightStartHour = UserDefaults.standard.object(forKey: "nightStartHour") as? Int ?? 17
        self.nightEndHour = UserDefaults.standard.object(forKey: "nightEndHour") as? Int ?? 7
        self.debounceSeconds = UserDefaults.standard.object(forKey: "debounceSeconds") as? Double ?? 4.0
        
        // 如果启用了监控，自动启动
        if keyboardMonitorEnabled {
            startKeyboardMonitoring()
        }
    }
    
    func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
        
        // 实际设置开机自启动
        setLaunchAtLogin(launchAtLogin)
    }
    
    func toggleKeyboardMonitor() {
        keyboardMonitorEnabled.toggle()
        UserDefaults.standard.set(keyboardMonitorEnabled, forKey: "keyboardMonitorEnabled")
        
        if keyboardMonitorEnabled {
            startKeyboardMonitoring()
        } else {
            stopKeyboardMonitoring()
        }
    }
    
    func updateConfiguration() {
        UserDefaults.standard.set(mxlightPath, forKey: "mxlightPath")
        UserDefaults.standard.set(keyboardUUID, forKey: "keyboardUUID")
        UserDefaults.standard.set(nightStartHour, forKey: "nightStartHour")
        UserDefaults.standard.set(nightEndHour, forKey: "nightEndHour")
        UserDefaults.standard.set(debounceSeconds, forKey: "debounceSeconds")
        
        // 如果监控正在运行，重启以应用新配置
        if keyboardMonitorEnabled {
            stopKeyboardMonitoring()
            startKeyboardMonitoring()
        }
    }
    
    private func startKeyboardMonitoring() {
        sleepWakeMonitor = SleepWakeMonitor(
            mxlightPath: mxlightPath,
            keyboardUUID: keyboardUUID,
            nightStartHour: nightStartHour,
            nightEndHour: nightEndHour,
            debounceSeconds: debounceSeconds
        )
        sleepWakeMonitor?.start()
    }
    
    private func stopKeyboardMonitoring() {
        sleepWakeMonitor?.stop()
        sleepWakeMonitor = nil
    }
    
    private func setLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enable ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            }
        } else {
            // Fallback for earlier versions
            guard let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue() else {
                print("Failed to create login items list")
                return
            }
            
            if enable {
                let appURL = Bundle.main.bundleURL
                LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast.takeRetainedValue(), nil, nil, appURL as CFURL, nil, nil)
            } else {
                // Remove from login items (implementation needed)
                print("Remove from login items not implemented")
            }
        }
    }
}

// Sleep/Wake monitoring implementation
enum EventKind { case sleepLike, wakeLike }

// Log file path
private let logPath = (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
    .appendingPathComponent("Library/Logs/mxlight-sleep-monitor.log")

// Logging function
func log(_ s: String) {
    let timestamp = DateFormatter().string(from: Date())
    let logEntry = "[\(timestamp)] \(s)\n"
    
    if let data = logEntry.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logPath) {
            if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: URL(fileURLWithPath: logPath))
        }
    }
}

@discardableResult
func runShell(_ command: String) -> Int32 {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", command]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    
    do {
        try task.run()
        task.waitUntilExit()
        return task.terminationStatus
    } catch {
        log("Failed to run command: \(command), error: \(error)")
        return -1
    }
}

func isInNightWindow(_ date: Date = Date(), startHour: Int, endHour: Int) -> Bool {
    let hour = Calendar.current.component(.hour, from: date)
    return startHour > endHour ? (hour >= startHour || hour < endHour) : (hour >= startHour && hour < endHour)
}

// Display wrangler watcher for sleep/wake detection
final class DisplayWranglerWatcher {
    private var notifyPort: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private var wrangler: io_service_t = 0
    private var started = false
    
    private var lastPMState: Int? = nil
    private var onSleep: (() -> Void)?
    private var onWake:  (() -> Void)?
    
    deinit {
        stop()
    }
    
    func stop() {
        guard started else { return }
        started = false
        
        if notifier != 0 {
            IOObjectRelease(notifier)
            notifier = 0
        }
        
        if let port = notifyPort {
            IONotificationPortDestroy(port)
            notifyPort = nil
        }
        
        if wrangler != 0 {
            IOObjectRelease(wrangler)
            wrangler = 0
        }
    }
    
    func start(onSleep: @escaping () -> Void, onWake: @escaping () -> Void) {
        guard !started else { return }
        
        self.onSleep = onSleep
        self.onWake = onWake
        
        wrangler = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODisplayWrangler"))
        guard wrangler != 0 else {
            log("Failed to get IODisplayWrangler service")
            return
        }
        
        notifyPort = IONotificationPortCreate(kIOMasterPortDefault)
        guard let port = notifyPort else {
            log("Failed to create notification port")
            return
        }
        
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceInterestCallback = { (refcon, service, messageType, messageArgument) in
            let watcher = Unmanaged<DisplayWranglerWatcher>.fromOpaque(refcon!).takeUnretainedValue()
            watcher.handlePowerChange()
        }
        
        let result = IOServiceAddInterestNotification(
            port,
            wrangler,
            kIOGeneralInterest,
            callback,
            refcon,
            &notifier
        )
        
        guard result == KERN_SUCCESS else {
            log("Failed to add interest notification")
            return
        }
        
        IONotificationPortSetDispatchQueue(port, DispatchQueue.global())
        started = true
        
        // Read initial state
        lastPMState = readPMState()
        log("DisplayWranglerWatcher started, initial PM state: \(lastPMState ?? -1)")
    }
    
    private func readPMState() -> Int? {
        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(wrangler, &properties, kCFAllocatorDefault, 0)
        
        guard result == KERN_SUCCESS, let props = properties?.takeRetainedValue() else {
            return nil
        }
        
        let dict = props as NSDictionary
        return dict["IOPowerManagement"] as? Int
    }
    
    private func handlePowerChange() {
        let currentState = readPMState()
        
        guard let current = currentState, let last = lastPMState, current != last else {
            lastPMState = currentState
            return
        }
        
        log("PM state changed from \(last) to \(current)")
        
        if current == 0 && last != 0 {
            // Going to sleep
            onSleep?()
        } else if current != 0 && last == 0 {
            // Waking up
            onWake?()
        }
        
        lastPMState = current
    }
}

// Sleep/Wake monitor
final class SleepWakeMonitor {
    private var lastSleepLike: Date = .distantPast
    private var lastWakeLike:  Date = .distantPast
    private let wrangler = DisplayWranglerWatcher()
    
    private let mxlightPath: String
    private let keyboardUUID: String
    private let nightStartHour: Int
    private let nightEndHour: Int
    private let debounceSeconds: TimeInterval
    
    private var commandA: String {
        return "\(mxlightPath) --off --uuid \(keyboardUUID)"
    }
    
    private var commandB: String {
        return "\(mxlightPath) --on --uuid \(keyboardUUID)"
    }
    
    init(mxlightPath: String, keyboardUUID: String, nightStartHour: Int, nightEndHour: Int, debounceSeconds: Double) {
        self.mxlightPath = mxlightPath
        self.keyboardUUID = keyboardUUID
        self.nightStartHour = nightStartHour
        self.nightEndHour = nightEndHour
        self.debounceSeconds = debounceSeconds
    }
    
    func start() {
        log("Starting sleep/wake monitor")
        wrangler.start(
            onSleep: { [weak self] in
                self?.handleSleep(reason: "DisplayWrangler sleep")
            },
            onWake: { [weak self] in
                self?.handleWake(reason: "DisplayWrangler wake")
            }
        )
    }
    
    func stop() {
        log("Stopping sleep/wake monitor")
        wrangler.stop()
    }
    
    private func shouldIgnore(kind: EventKind) -> Bool {
        let now = Date()
        let lastEvent = kind == .sleepLike ? lastSleepLike : lastWakeLike
        
        if now.timeIntervalSince(lastEvent) < debounceSeconds {
            log("Ignoring \(kind) event due to debounce (\(now.timeIntervalSince(lastEvent))s < \(debounceSeconds)s)")
            return true
        }
        
        return false
    }
    
    private func handleSleep(reason: String) {
        guard !shouldIgnore(kind: .sleepLike) else { return }
        lastSleepLike = Date()
        
        log("Sleep detected: \(reason)")
        runShell(commandA)
    }
    
    private func handleWake(reason: String) {
        guard !shouldIgnore(kind: .wakeLike) else { return }
        lastWakeLike = Date()
        
        log("Wake detected: \(reason)")
        
        if isInNightWindow(startHour: nightStartHour, endHour: nightEndHour) {
            log("In night window, turning on keyboard light")
            runShell(commandB)
        } else {
            log("Not in night window, keeping keyboard light off")
        }
    }
}