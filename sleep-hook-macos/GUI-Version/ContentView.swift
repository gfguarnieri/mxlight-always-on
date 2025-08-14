import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingAbout = false
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.blue)
                Text("菜单栏应用")
                    .font(.headline)
            }
            .padding(.top, 10)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("设置")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Toggle("开机自启动", isOn: $appState.launchAtLogin)
                    .padding(.horizontal, 5)
                    .onChange(of: appState.launchAtLogin) { _ in
                        appState.toggleLaunchAtLogin()
                    }
            }
            .padding(.horizontal)
            
            Divider()
            
            HStack(spacing: 15) {
                Button("关于") {
                    showingAbout = true
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(5)
                
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Text("设置")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Fallback on earlier versions
                }
                
                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.1))
                .cornerRadius(5)
            }
            .padding(.bottom, 10)
        }
        .padding(.vertical, 5)
        .frame(width: 250)
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "star.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .padding(.top, 20)
            
            Text("菜单栏应用")
                .font(.title)
                .bold()
            
            Text("版本 1.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("一个简单的macOS菜单栏应用程序，提供菜单栏图标和交互功能。")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 10)
            
            Text("© 2023 开发者")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 20)
                .padding(.bottom, 20)
        }
        .frame(width: 300, height: 300)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
