import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("常规", systemImage: "gear")
                }
                .tag(0)
            
            KeyboardSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("键盘监控", systemImage: "keyboard")
                }
                .tag(1)
            
            AboutSettingsView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
                .tag(2)
        }
        .padding(20)
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Form {
            Section(header: Text("启动选项").font(.headline)) {
                Toggle("开机自启动", isOn: $appState.launchAtLogin)
                    .onChange(of: appState.launchAtLogin) { _ in
                        appState.toggleLaunchAtLogin()
                    }
                Text("设置应用程序在系统启动时自动运行")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("外观").font(.headline)) {
                Picker("菜单栏图标", selection: .constant(0)) {
                    Text("默认图标").tag(0)
                    Text("简约图标").tag(1)
                    Text("彩色图标").tag(2)
                }
            }
        }
    }
}

struct KeyboardSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingFilePicker = false
    
    var body: some View {
        Form {
            Section(header: Text("键盘监控").font(.headline)) {
                Toggle("启用键盘灯光监控", isOn: $appState.keyboardMonitorEnabled)
                    .onChange(of: appState.keyboardMonitorEnabled) { _ in
                        appState.toggleKeyboardMonitor()
                    }
                Text("监控系统睡眠/唤醒状态，自动控制键盘背光")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("mxlight 配置").font(.headline)) {
                HStack {
                    TextField("mxlight 路径", text: $appState.mxlightPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: appState.mxlightPath) { _ in
                            appState.updateConfiguration()
                        }
                    
                    Button("选择文件") {
                        showingFilePicker = true
                    }
                    .buttonStyle(.bordered)
                }
                
                TextField("键盘 UUID", text: $appState.keyboardUUID)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: appState.keyboardUUID) { _ in
                        appState.updateConfiguration()
                    }
                
                Text("请确保 mxlight 工具路径正确，并填入正确的键盘 UUID")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("时间窗口设置").font(.headline)) {
                HStack {
                    Text("夜间开始时间:")
                    Picker("", selection: $appState.nightStartHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text("\(hour):00").tag(hour)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: appState.nightStartHour) { _ in
                        appState.updateConfiguration()
                    }
                }
                
                HStack {
                    Text("夜间结束时间:")
                    Picker("", selection: $appState.nightEndHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text("\(hour):00").tag(hour)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: appState.nightEndHour) { _ in
                        appState.updateConfiguration()
                    }
                }
                
                Text("在夜间时间窗口内，系统唤醒时会自动开启键盘背光")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("高级设置").font(.headline)) {
                HStack {
                    Text("防抖延迟 (秒):")
                    TextField("", value: $appState.debounceSeconds, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                        .onChange(of: appState.debounceSeconds) { _ in
                            appState.updateConfiguration()
                        }
                }
                
                Text("设置事件触发的防抖延迟时间，避免重复执行")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.executable, .unixExecutable],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    appState.mxlightPath = url.path
                    appState.updateConfiguration()
                }
            case .failure(let error):
                print("文件选择失败: \(error.localizedDescription)")
            }
        }
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "star.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("菜单栏应用")
                .font(.title2)
                .bold()
            
            Text("版本 1.0")
                .font(.subheadline)
            
            Text("一个简单的macOS菜单栏应用程序，提供菜单栏图标和键盘灯光监控功能。")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 5)
            
            Spacer()
            
            HStack {
                Text("© 2023 开发者")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("访问网站") {
                    if let url = URL(string: "https://example.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .padding()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppState())
    }
}
