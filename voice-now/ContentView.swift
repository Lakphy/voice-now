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
        ScrollView {
            VStack(spacing: 24) {
                // 头部
                VStack(spacing: 12) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                    
                    Text("Voice Now")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("实时语音识别工具")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // API 配置区域
                GroupBox(label: Label("API 配置", systemImage: "key.fill")) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Key")
                                .font(.headline)
                            
                            SecureField("请输入阿里云百炼 API Key", text: $config.apiKey)
                                .textFieldStyle(.roundedBorder)
                            
                            Link("获取 API Key", destination: URL(string: "https://help.aliyun.com/zh/model-studio/get-api-key")!)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("服务区域")
                                .font(.headline)
                            
                            Picker("", selection: $config.region) {
                                ForEach(ConfigManager.Region.allCases, id: \.self) { region in
                                    Text(region.displayName).tag(region)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        HStack {
                            Image(systemName: config.isConfigured ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(config.isConfigured ? .green : .orange)
                            Text(config.isConfigured ? "API Key 已配置" : "请配置 API Key")
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 权限状态
                GroupBox(label: Label("权限状态", systemImage: "checkmark.shield.fill")) {
                    VStack(alignment: .leading, spacing: 12) {
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
                        
                        Button("刷新权限状态") {
                            checkPermissions()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                    .padding(.vertical, 8)
                }
                
                // 权限说明（如果未授予）
                if !hasAccessibilityPermission {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("需要授予辅助功能权限")
                                    .font(.headline)
                            }
                            
                            Text("为了实现全局快捷键监听，需要授予辅助功能权限：")
                                .font(.body)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("1. 点击下方按钮打开系统设置")
                                Text("2. 在左侧选择「隐私与安全性」")
                                Text("3. 点击「辅助功能」")
                                Text("4. 找到「voice-now」并打开开关")
                                Text("5. 授权后稍等片刻，应用会自动重试")
                            }
                            .font(.caption)
                            .padding(.leading, 8)
                            
                            Button("打开系统设置") {
                                openAccessibilitySettings()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // 使用说明
                GroupBox(label: Label("使用方法", systemImage: "info.circle.fill")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("1.")
                            Text("配置好上方的 API Key")
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("2.")
                            Text("在任意应用中按下右 Command 键激活语音识别")
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("3.")
                            Text("对着麦克风说话，识别结果会自动输入")
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("4.")
                            Text("再次按右 Command 键关闭识别")
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("5.")
                            Text("关闭此窗口后，应用继续在后台运行")
                        }
                    }
                    .font(.body)
                    .padding(.vertical, 8)
                }
                
                // 测试按钮
                Button {
                    coordinator.toggleRecording()
                } label: {
                    Label(coordinator.isRecording ? "停止测试" : "测试识别", systemImage: coordinator.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!config.isConfigured || !hasAccessibilityPermission)
            }
            .padding(32)
        }
        .frame(minWidth: 650, minHeight: 700)
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
}

#Preview {
    ContentView()
}
