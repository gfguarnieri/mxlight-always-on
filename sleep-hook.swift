// 编译：swiftc -O -o sleep-hook main.swift
import Foundation
import AppKit

// --- 配置区 ---
// 将你的指令 A 写在这里（建议写“绝对路径 + 参数”，避免 PATH 问题）
let commandA: String = "/Users/m2p/src/code/keyboard/mxlight --off --uuid 6D6299B8-F57F-04B3-7285-E0A5C0448F00"
let commandB: String = "/Users/m2p/src/code/keyboard/mxlight --on --uuid 6D6299B8-F57F-04B3-7285-E0A5C0448F00"
// 如果你想通过命令行传入，也可用：let commandA = CommandLine.arguments.dropFirst().joined(separator: " ")

// 可选开关
let triggerOnDisplaySleep = true      // 息屏 -> A
let triggerOnDisplayWake  = true      // 屏幕亮起 -> B(夜间)
let triggerOnScreensaver  = false     // 屏保起停也当作息屏/亮屏（有些策略会先进入屏保）

// 夜间窗口（17:00 ~ 次日 07:00）
let nightStartHour = 17
let nightEndHour   = 7

// ---- 工具函数 ----
func runShell(_ cmd: String) {
    guard !cmd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = ["-lc", cmd]
    do { try p.run() } catch { fputs("runShell error: \(error)\n", stderr) }
}

func isInNightWindow(_ date: Date = Date()) -> Bool {
    let cal = Calendar.current
    let h = cal.component(.hour, from: date)
    let m = cal.component(.minute, from: date)
    let minutes = h*60 + m
    let start = nightStartHour*60
    let end   = nightEndHour*60
    return (start > end) ? (minutes >= start || minutes < end) : (minutes >= start && minutes < end)
}

// 唤醒事件去抖（不少机器会连发）
var lastWakeFire = Date.distantPast
func shouldFireWakeNow() -> Bool {
    let now = Date()
    if now.timeIntervalSince(lastWakeFire) < 3 { return false }
    lastWakeFire = now
    return true
}

// ---- 事件订阅 ----
let nc  = NSWorkspace.shared.notificationCenter
let dnc = DistributedNotificationCenter.default()

// A) 系统睡眠/唤醒（整机）
let obsWillSleep = nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
    print("[sleep-hook] willSleep -> A")
    runShell(commandA)
}
let obsDidWake = nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
    print("[sleep-hook] didWake")
    if isInNightWindow(), shouldFireWakeNow() {
        print("[sleep-hook] night window -> B")
        runShell(commandB)
    }
}

// B) 显示器息屏/点亮（用 NSDistributedNotificationCenter 更可靠）
if triggerOnDisplaySleep {
    dnc.addObserver(forName: NSNotification.Name("com.apple.powermanagement.displayIsAsleep"), object: nil, queue: .main) { _ in
        print("[sleep-hook] displayIsAsleep -> A (DNC)")
        runShell(commandA)
    }
    // 兼容老路径：有些系统还会发这个
    dnc.addObserver(forName: NSNotification.Name("com.apple.powermanagement.systemDisplayDidSleep"), object: nil, queue: .main) { _ in
        print("[sleep-hook] systemDisplayDidSleep -> A (DNC-compat)")
        runShell(commandA)
    }
}

if triggerOnDisplayWake {
    dnc.addObserver(forName: NSNotification.Name("com.apple.powermanagement.displayIsOn"), object: nil, queue: .main) { _ in
        print("[sleep-hook] displayIsOn (DNC)")
        if isInNightWindow(), shouldFireWakeNow() {
            print("[sleep-hook] night window -> B (displayOn)")
            runShell(commandB)
        }
    }
    dnc.addObserver(forName: NSNotification.Name("com.apple.powermanagement.systemDisplayDidWake"), object: nil, queue: .main) { _ in
        print("[sleep-hook] systemDisplayDidWake (DNC-compat)")
        if isInNightWindow(), shouldFireWakeNow() {
            print("[sleep-hook] night window -> B (displayDidWake)")
            runShell(commandB)
        }
    }
}

// （可选）屏保起停作为参考事件（有的策略会先进屏保再熄屏）
if triggerOnScreensaver {
    dnc.addObserver(forName: NSNotification.Name("com.apple.screensaver.didstart"), object: nil, queue: .main) { _ in
        print("[sleep-hook] screensaver.didstart -> A")
        runShell(commandA)
    }
    dnc.addObserver(forName: NSNotification.Name("com.apple.screensaver.didstop"), object: nil, queue: .main) { _ in
        print("[sleep-hook] screensaver.didstop")
        if isInNightWindow(), shouldFireWakeNow() {
            print("[sleep-hook] night window -> B (screensaver.stop)")
            runShell(commandB)
        }
    }
}

print("[sleep-hook] started. Waiting for events…")
RunLoop.main.run()
