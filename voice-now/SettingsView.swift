//
//  SettingsView.swift
//  voice-now
//
//  配置页面
//

import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var config = ConfigManager.shared
    @State private var showingSaveAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("API 配置")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.headline)
                    
                    SecureField("请输入阿里云百炼 API Key", text: $config.apiKey)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("获取 API Key: https://help.aliyun.com/zh/model-studio/get-api-key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("服务区域")
                        .font(.headline)
                    
                    Picker("", selection: $config.region) {
                        ForEach(ConfigManager.Region.allCases, id: \.self) { region in
                            Text(region.displayName).tag(region)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("音频配置")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("采样率")
                        .font(.headline)
                    
                    Picker("", selection: $config.sampleRate) {
                        Text("16000 Hz (推荐)").tag(16000)
                    }
                    .pickerStyle(.radioGroup)
                    
                    Text("Fun-ASR 实时模型支持 16000Hz 采样率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("使用说明")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("1.")
                        Text("配置好 API Key 后，按右 Command 键激活语音识别")
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("2.")
                        Text("对着麦克风说话，识别结果会自动输入到当前焦点的文本框")
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("3.")
                        Text("再次按右 Command 键关闭语音识别")
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("⚠️")
                        Text("首次使用需要授予麦克风和辅助功能权限")
                            .foregroundColor(.orange)
                    }
                }
                .font(.body)
            }
            
            Section {
                HStack {
                    Spacer()
                    Button("保存配置") {
                        showingSaveAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 600, minHeight: 500)
        .alert("配置已保存", isPresented: $showingSaveAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("您的配置已成功保存")
        }
    }
}

#Preview {
    SettingsView()
}

