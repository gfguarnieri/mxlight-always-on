// 编译：swiftc -O -framework AppKit -framework Foundation -o MenuApp app/MenuApp.swift
import AppKit
import Foundation

// =============== 基础配置/存储 ===============
struct Config: Codable {
    var uuid: String = "6D6299B8-F57F-04B3-7285-E0A5C0448F00"
    var nightStart: String = "17:00"    // HH:mm
    var nightEnd:   String = "07:00"    // HH:mm (跨日)
    var triggerOnDisplaySleep: Bool = true
    var triggerOnDisplayWake:  Bool = true
    var triggerOnScreensaver:  Bool = false
    var launchAtLogin: Bool = true
}

let appName = "SleepHook"
let labelLaunchAgent = "com.example.sleephook.menu"
let fm = FileManager.default

let supportDir = (fm.homeDirectoryForCurrentUser
    .appendingPathComponent("Library")
    .appendingPathComponent("Application Support")
    .appendingPathComponent(appName)).path
let logPath  = (supportDir as NSString).appendingPathComponent("SleepHook.log")
let confPath = (supportDir as NSString).appendingPathComponent("config.json")

func ensureDirs() { try? fm.createDirectory(atPath: supportDir, withIntermediateDirectories: true) }

func log(_ s: String) {
    ensureDirs()
    let line = "[\\(ISO8601DateFormatter().string(from: Date()))] \\(s)\\n"
    if !fm.fileExists(atPath: logPath) { fm.createFile(atPath: logPath, contents: Data()) }
    if let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
        defer { try? h.close() }
        try? h.seekToEnd()
        try? h.write(contentsOf: Data(line.utf8))
    }
    print(s)
}

func loadConfig() -> Config {
    ensureDirs()
    if let data = try? Data(contentsOf: URL(fileURLWithPath: confPath)),
       let c = try? JSONDecoder().decode(Config.self, from: data) {
        return c
    }
    let def = Config()
    if let d = try? JSONEncoder().encode(def) { try? d.write(to: URL(fileURLWithPath: confPath)) }
    return def
}

func saveConfig(_ c: Config) {
    if let d = try? JSONEncoder().encode(c) { try? d.write(to: URL(fileURLWithPath: confPath)) }
}

// =============== LaunchAgent 自启动 ===============
func launchAgentPlistPath() -> String {
    return (fm.homeDirectoryForCurrentUser
        .appendingPathComponent("Library")
        .appendingPathComponent("LaunchAgents")
        .appendingPathComponent("\\(labelLaunchAgent).plist")).path
}

func appExecutablePath() -> String {
    // /Applications/SleepHook.app/Contents/MacOS/SleepHook
    return Bundle.main.executablePath ?? "/Applications/\\(appName).app/Contents/MacOS/\\(appName)"
}

func setLaunchAtLogin(_ enable: Bool) {
    let plist = launchAgentPlistPath()
    if enable {
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
          <key>Label</key><string>\\(labelLaunchAgent)</string>
          <key>ProgramArguments</key>
          <array><string>\\(appExecutablePath())</string></array>
          <key>RunAtLoad</key><true/>
          <key>KeepAlive</key><true/>
          <key>LimitLoadToSessionType</key><string>Aqua</string>
          <key>StandardOutPath</key><string>\\(supportDir)/launchd.out.log</string>
          <key>StandardErrorPath</key><string>\\(supportDir)/launchd.err.log</string>
        </dict></plist>
        """
        try? content.data(using: .utf8)?.write(to: URL(fileURLWithPath: plist))
        _ = runShell("launchctl unload \\(shellQuote(plist)) 2>/dev/null || true")
        _ = runShell("launchctl load \\(shellQuote(plist))")
        _ = runShell("launchctl start \\(labelLaunchAgent)")
    } else {
        _ = runShell("launchctl unload \\(shellQuote(plist)) 2>/dev/null || true")
        try? fm.removeItem(atPath: plist)
    }
}

func isLaunchAtLoginEnabled() -> Bool {
    let plist = launchAgentPlistPath()
    return fm.fileExists(atPath: plist)
}

// =============== 工具函数 ===============
@discardableResult
func runShell(_ cmd: String) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = ["-lc", cmd]
    do { try p.run(); p.waitUntilExit() } catch { log("runShell error: \\(error)") }
    return p.terminationStatus
}
func shellQuote(_ s: String) -> String { return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

func parseHHmm(_ s: String) -> (h:Int, m:Int)? {
    let a = s.split(separator: ":"); guard a.count == 2, let h = Int(a[0]), let m = Int(a[1]) else { return nil }
    guard (0..<24).contains(h), (0..<60).contains(m) else { return nil }
    return (h,m)
}
func inNight(_ c: Config, date: Date = Date()) -> Bool {
    let (hs,ms) = parseHHmm(c.nightStart) ?? (17,0)
    let (he,me) = parseHHmm(c.nightEnd)   ?? (7,0)
    let start = hs*60+ms, end = he*60+me
    let cal = Calendar.current
    let cur = cal.component(.hour, from: date)*60 + cal.component(.minute, from: date)
    return start > end ? (cur >= start || cur < end) : (cur >= start && cur < end)
}

func bundleBin(_ name: String) -> String {
    // Resources/bin/<name>
    let path = Bundle.main.resourcePath ?? (Bundle.main.bundlePath + "/Contents/Resources")
    return (path as NSString).appendingPathComponent("bin/\\(name)")
}

// =============== 电源/显示 监听 ===============
final class PowerObserver {
    private let wsNC = NSWorkspace.shared.notificationCenter
    private let dnc  = DistributedNotificationCenter.default()
    private var config: () -> Config
    init(configProvider: @escaping () -> Config) { self.config = configProvider }

    private var lastWake = Date.distantPast
    private func shouldFireWakeNow() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastWake) < 3 { return false }
        lastWake = now
        return true
    }

    func start() {
        wsNC.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            log("willSleep -> A")
            self.runA()
        }
        wsNC.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            log("didWake")
            let c = self.config()
            if inNight(c), self.shouldFireWakeNow() {
                log("night window -> B")
                self.runB()
            }
        }

        let c = config()
        if c.triggerOnDisplaySleep {
            dnc.addObserver(forName: NSNotification.Name("com.apple.powermanagement.displayIsAsleep"), object: nil, queue: .main) { _ in
                log("displayIsAsleep -> A")
                self.runA()
            }
            dnc.addObserver(forName: NSNotification.Name("com.apple.powermanagement.systemDisplayDidSleep"), object: nil, queue: .main) { _ in
                log("systemDisplayDidSleep -> A")
                self.runA()
            }
        }
        if c.triggerOnDisplayWake {
            dnc.addObserver(forName: NSNotification.Name("com.apple.powermanagement.displayIsOn"), object: nil, queue: .main) { _ in
                log("displayIsOn")
                let c = self.config()
                if inNight(c), self.shouldFireWakeNow() {
                    log("night window -> B (display)")
                    self.runB()
                }
            }
            dnc.addObserver(forName: NSNotification.Name("com.apple.powermanagement.systemDisplayDidWake"), object: nil, queue: .main) { _ in
                log("systemDisplayDidWake")
                let c = self.config()
                if inNight(c), self.shouldFireWakeNow() {
                    log("night window -> B (display)")
                    self.runB()
                }
            }
        }

        if c.triggerOnScreensaver {
            dnc.addObserver(forName: NSNotification.Name("com.apple.screensaver.didstart"), object: nil, queue: .main) { _ in
                log("screensaver.didstart -> A")
                self.runA()
            }
            dnc.addObserver(forName: NSNotification.Name("com.apple.screensaver.didstop"), object: nil, queue: .main) { _ in
                log("screensaver.didstop")
                let c = self.config()
                if inNight(c), self.shouldFireWakeNow() {
                    log("night window -> B (screensaver.stop)")
                    self.runB()
                }
            }
        }
        log("observers started")
    }

    // A/B 使用 bundle 内置 mxlight
    private func runA() { runLight(off: true) }
    private func runB() { runLight(off: false) }

    private func runLight(off: Bool) {
        let c = config()
        let mx = bundleBin("mxlight")
        var cmd = shellQuote(mx) + (off ? " --off" : " --on")
        if !c.uuid.trimmingCharacters(in: .whitespaces).isEmpty {
            cmd += " --uuid \\(shellQuote(c.uuid))"
        }
        _ = runShell(cmd)
    }
}

// =============== 偏好设置窗口（任务栏菜单） ===============
final class PreferencesWindow: NSWindow, NSWindowDelegate {
    private var uuidField = NSTextField()
    private var nsField = NSTextField()
    private var neField = NSTextField()
    private var cbDisplaySleep = NSButton(checkboxWithTitle: "Trigger on display sleep（息屏触发A）", target: nil, action: nil)
    private var cbDisplayWake  = NSButton(checkboxWithTitle: "Trigger on display wake（亮屏触发B-限夜间）", target: nil, action: nil)
    private var cbScreensaver  = NSButton(checkboxWithTitle: "Treat screensaver as sleep/wake（屏保也算）", target: nil, action: nil)
    private var cbLaunchAtLogin = NSButton(checkboxWithTitle: "Launch at login（登录自启）", target: nil, action: nil)
    private var saveBtn = NSButton(title: "Save / 保存", target: nil, action: nil)

    private var config: Config { didSet { saveConfig(config) } }

    init(config: Config) {
        self.config = config
        super.init(contentRect: NSRect(x: 0, y: 0, width: 520, height: 260),
                   styleMask: [.titled, .closable],
                   backing: .buffered, defer: false)
        self.center()
        self.title = "SleepHook Preferences"
        self.isReleasedWhenClosed = false
        self.delegate = self

        uuidField.stringValue = config.uuid
        nsField.stringValue = config.nightStart
        neField.stringValue = config.nightEnd
        cbDisplaySleep.state = config.triggerOnDisplaySleep ? .on : .off
        cbDisplayWake.state  = config.triggerOnDisplayWake  ? .on : .off
        cbScreensaver.state  = config.triggerOnScreensaver  ? .on : .off
        cbLaunchAtLogin.state = (config.launchAtLogin || isLaunchAtLoginEnabled()) ? .on : .off

        // 简单布局
        func label(_ s:String)->NSTextField { let l=NSTextField(labelWithString:s); l.font=.systemFont(ofSize:13); return l }
        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 8
        content.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        let row1 = NSStackView(views: [label("Keyboard UUID:"), uuidField])
        row1.orientation = .horizontal; row1.distribution = .fillProportionally; uuidField.frame.size.width = 360
        let row2 = NSStackView(views: [label("Night Start (HH:mm):"), nsField, label("Night End (HH:mm):"), neField])
        row2.orientation = .horizontal; row2.spacing = 8
        cbDisplaySleep.setButtonType(.switch)
        cbDisplayWake.setButtonType(.switch)
        cbScreensaver.setButtonType(.switch)
        cbLaunchAtLogin.setButtonType(.switch)

        saveBtn.target = self
        saveBtn.action = #selector(onSave)

        content.addArrangedSubview(row1)
        content.addArrangedSubview(row2)
        content.addArrangedSubview(cbDisplaySleep)
        content.addArrangedSubview(cbDisplayWake)
        content.addArrangedSubview(cbScreensaver)
        content.addArrangedSubview(cbLaunchAtLogin)
        content.addArrangedSubview(saveBtn)
        self.contentView = content
    }

    @objc private func onSave() {
        var c = self.config
        c.uuid = uuidField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        c.nightStart = nsField.stringValue
        c.nightEnd = neField.stringValue
        c.triggerOnDisplaySleep = (cbDisplaySleep.state == .on)
        c.triggerOnDisplayWake  = (cbDisplayWake.state  == .on)
        c.triggerOnScreensaver  = (cbScreensaver.state  == .on)
        c.launchAtLogin = (cbLaunchAtLogin.state == .on)

        // 校验时间
        if parseHHmm(c.nightStart) == nil || parseHHmm(c.nightEnd) == nil {
            NSSound.beep()
            return
        }
        self.config = c
        setLaunchAtLogin(c.launchAtLogin)
        log("preferences saved")
        self.close()
    }
}

// =============== App 入口（菜单栏） ===============
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var prefWin: PreferencesWindow!
    var observer: PowerObserver!
    var config = loadConfig()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureDirs()
        // 将 app 运行路径写入一次 LaunchAgent（保持与 config.launchAtLogin 同步）
        if config.launchAtLogin { setLaunchAtLogin(true) }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🌙"
        let menu = NSMenu()
        menu.addItem(withTitle: "Preferences… / 偏好设置…", action: #selector(openPrefs), keyEquivalent: ",")
        menu.addItem(withTitle: "Open Log / 查看日志", action: #selector(openLog), keyEquivalent: "l")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Test OFF (A)", action: #selector(testA), keyEquivalent: "a")
        menu.addItem(withTitle: "Test ON  (B)", action: #selector(testB), keyEquivalent: "b")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit / 退出", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu

        observer = PowerObserver { [weak self] in self?.config ?? loadConfig() }
        observer.start()
    }

    @objc func openPrefs() {
        config = loadConfig()
        prefWin = PreferencesWindow(config: config)
        prefWin.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func openLog() { NSWorkspace.shared.open(URL(fileURLWithPath: logPath)) }
    @objc func testA() {
        let mx = bundleBin("mxlight")
        var cmd = shellQuote(mx) + " --off"
        if !config.uuid.isEmpty { cmd += " --uuid \\(shellQuote(config.uuid))" }
        _ = runShell(cmd)
    }
    @objc func testB() {
        let mx = bundleBin("mxlight")
        var cmd = shellQuote(mx) + " --on"
        if !config.uuid.isEmpty { cmd += " --uuid \\(shellQuote(config.uuid))" }
        _ = runShell(cmd)
    }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // 菜单栏 App
let delegate = AppDelegate()
app.delegate = delegate
app.run()
