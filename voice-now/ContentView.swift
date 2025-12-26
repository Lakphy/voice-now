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
        VStack(spacing: 20) {
            // 头部 - 紧凑版
            HStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Voice Now")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    
                    Text("实时语音识别")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 录音状态
                if coordinator.isRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("录音中")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    // 快速状态
                    HStack(spacing: 12) {
                        MiniStatusCard(icon: "key.fill", isActive: config.isConfigured)
                        MiniStatusCard(icon: "mic.fill", isActive: hasMicPermission)
                        MiniStatusCard(icon: "hand.point.up.braille.fill", isActive: hasAccessibilityPermission)
                    }
                    
                    // API 配置
                    VStack(alignment: .leading, spacing: 10) {
                        Label("API 配置", systemImage: "key.fill")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            SecureField("阿里云百炼 API Key", text: $config.apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.callout, design: .monospaced))
                            
                            HStack {
                                Link("获取 API Key", destination: URL(string: "https://help.aliyun.com/zh/model-studio/get-api-key")!)
                                    .font(.caption2)
                                
                                Spacer()
                                
                                Picker("", selection: $config.region) {
                                    ForEach(ConfigManager.Region.allCases, id: \.self) { region in
                                        Text(region.displayName).tag(region)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                .frame(width: 180)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    
                    // 权限提示（紧凑版）
                    if !hasAccessibilityPermission || !hasMicPermission {
                        VStack(spacing: 10) {
                            if !hasAccessibilityPermission {
                                CompactPermissionBox(
                                    icon: "hand.point.up.braille.fill",
                                    title: "需要辅助功能权限",
                                    action: openAccessibilitySettings
                                )
                            }
                            
                            if !hasMicPermission {
                                CompactPermissionBox(
                                    icon: "mic.fill",
                                    title: "需要麦克风权限",
                                    action: nil
                                )
                            }
                            
                            Button {
                                checkPermissions()
                            } label: {
                                Label("刷新", systemImage: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    // 使用说明 - 紧凑版
                    VStack(alignment: .leading, spacing: 8) {
                        Label("使用方法", systemImage: "lightbulb.fill")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            CompactInstructionRow(number: "1", text: "配置 API Key")
                            CompactInstructionRow(number: "2", text: "按 右⌘ 键开始说话")
                            CompactInstructionRow(number: "3", text: "再按 右⌘ 键完成输入")
                        }
                        
                        Text("💡 关闭窗口后应用继续在后台运行")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .frame(minWidth: 480, minHeight: 420)
        .background(Color(.windowBackgroundColor))
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

// MARK: - UI Components

struct MiniStatusCard: View {
    let icon: String
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isActive ? .green : .orange)
            
            Circle()
                .fill(isActive ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        )
    }
}

struct CompactPermissionBox: View {
    let icon: String
    let title: String
    let action: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            if let action = action {
                Button("设置") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct CompactInstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.blue))
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
