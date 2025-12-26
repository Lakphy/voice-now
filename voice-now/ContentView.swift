//
//  ContentView.swift
//  voice-now
//
//  Created by Lakphy on 2025/12/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var config = ConfigManager.shared
    @ObservedObject private var coordinator = AppCoordinator.shared
    @State private var hasMicPermission = false
    @State private var hasAccessibilityPermission = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("Voice Now")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("实时语音识别工具")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.vertical)
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: config.isConfigured ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(config.isConfigured ? .green : .red)
                    Text(config.isConfigured ? "已配置 API Key" : "未配置 API Key")
                }
                
                HStack {
                    Image(systemName: hasMicPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasMicPermission ? .green : .orange)
                    Text(hasMicPermission ? "麦克风权限已授予" : "需要麦克风权限")
                }
                
                HStack {
                    Image(systemName: hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasAccessibilityPermission ? .green : .orange)
                    Text(hasAccessibilityPermission ? "辅助功能权限已授予" : "需要辅助功能权限")
                    
                    if !hasAccessibilityPermission {
                        Button("打开系统设置") {
                            openAccessibilitySettings()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
                
                HStack {
                    Image(systemName: coordinator.isRecording ? "record.circle.fill" : "circle")
                        .foregroundColor(coordinator.isRecording ? .red : .gray)
                    Text(coordinator.isRecording ? "正在录音中..." : "未在录音")
                }
            }
            .font(.body)
            
            Divider()
                .padding(.vertical)
            
            // 权限说明
            if !hasAccessibilityPermission {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("需要辅助功能权限")
                            .font(.headline)
                    }
                    
                    Text("为了实现全局快捷键监听，需要授予辅助功能权限：")
                        .font(.body)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. 点击下方「打开系统设置」按钮")
                        Text("2. 在左侧选择「隐私与安全性」")
                        Text("3. 点击「辅助功能」")
                        Text("4. 找到「voice-now」并打开开关")
                        Text("5. 授权后稍等片刻，应用会自动重试连接（无需重启）")
                    }
                    .font(.caption)
                    .padding(.leading, 8)
                    
                    HStack {
                        Button("打开系统设置") {
                            openAccessibilitySettings()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Text("💡 开发提示：应用会每 10 秒自动重试")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("使用方法：")
                    .font(.headline)
                
                HStack(alignment: .top) {
                    Text("1.")
                    Text("点击下方「打开设置」配置 API Key")
        }
                
                HStack(alignment: .top) {
                    Text("2.")
                    Text("在任意应用中按下右 Command 键激活语音识别")
                }
                
                HStack(alignment: .top) {
                    Text("3.")
                    Text("对着麦克风说话，识别结果会自动输入")
                }
                
                HStack(alignment: .top) {
                    Text("4.")
                    Text("再次按右 Command 键关闭识别")
                }
                
                HStack(alignment: .top) {
                    Text("5.")
                    Text("关闭此窗口后，应用继续在后台运行")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button("打开设置") {
                    openSettings()
                }
                .buttonStyle(.bordered)
                
                Button("刷新权限状态") {
                    checkPermissions()
                }
                .buttonStyle(.bordered)
                
                Button("测试识别") {
                    coordinator.toggleRecording()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!config.isConfigured || !hasAccessibilityPermission)
            }
        }
        .padding(40)
        .frame(maxWidth: 600)
        .onAppear {
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        // 检查麦克风权限
        DispatchQueue.global(qos: .userInitiated).async {
            let audioRecorder = AudioRecorder()
            audioRecorder.requestPermission { granted in
                DispatchQueue.main.async {
                    self.hasMicPermission = granted
                }
            }
        }
        
        // 检查辅助功能权限
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hasAccessibilityPermission = self.coordinator.checkAccessibilityPermission()
        }
    }
    
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    private func openSettings() {
        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "设置"
            settingsWindow.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow.center()
            settingsWindow.makeKeyAndOrderFront(nil)
            settingsWindow.identifier = NSUserInterfaceItemIdentifier("settings")
        }
    }
}

#Preview {
    ContentView()
}
