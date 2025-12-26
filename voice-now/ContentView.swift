//
//  ContentView.swift
//  voice-now
//
//  Created by Lakphy on 2025/12/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var webSocket = ASRWebSocket()
    @ObservedObject private var config = ConfigManager.shared
    @State private var showingFloatingMic = false
    @State private var hasPermissions = false
    @State private var lastRecognizedText = ""
    
    var body: some View {
        ZStack {
            // 主界面
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
                        Image(systemName: hasPermissions ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(hasPermissions ? .green : .orange)
                        Text(hasPermissions ? "已授予权限" : "需要麦克风和辅助功能权限")
                    }
                }
                .font(.body)
                
                Divider()
                    .padding(.vertical)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("使用方法：")
                        .font(.headline)
                    
                    HStack(alignment: .top) {
                        Text("1.")
                        Text("点击下方「打开设置」配置 API Key")
                    }
                    
                    HStack(alignment: .top) {
                        Text("2.")
                        Text("按下右 Command 键激活语音识别")
                    }
                    
                    HStack(alignment: .top) {
                        Text("3.")
                        Text("对着麦克风说话，识别结果会自动输入")
                    }
                    
                    HStack(alignment: .top) {
                        Text("4.")
                        Text("再次按右 Command 键关闭识别")
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
                    
                    Button("测试识别") {
                        testRecognition()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!config.isConfigured)
                }
            }
            .padding(40)
            .frame(maxWidth: 600)
            
            // 悬浮麦克风窗口
            if showingFloatingMic {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeFloatingMic()
                    }
                
                FloatingMicView(
                    recorder: audioRecorder,
                    webSocket: webSocket,
                    isVisible: $showingFloatingMic
                )
            }
        }
        .onAppear {
            setupApplication()
        }
        .onChange(of: showingFloatingMic) { newValue in
            if !newValue {
                closeFloatingMic()
            }
        }
    }
    
    private func setupApplication() {
        // 异步请求麦克风权限
        DispatchQueue.global(qos: .userInitiated).async {
            self.audioRecorder.requestPermission { granted in
                DispatchQueue.main.async {
                    self.hasPermissions = granted
                }
            }
        }
        
        // 异步设置全局快捷键监听
        DispatchQueue.global(qos: .userInitiated).async {
            let monitor = GlobalHotkeyMonitor.shared
            let started = monitor.startMonitoring()
            
            DispatchQueue.main.async {
                if started {
                    self.hasPermissions = true
                }
                
                monitor.onRightCommandPressed = {
                    self.toggleRecording()
                }
            }
        }
        
        // 设置音频数据回调
        audioRecorder.onAudioData = { data in
            self.webSocket.sendAudioData(data)
        }
        
        // 设置识别结果回调
        webSocket.onResultGenerated = { text in
            // 只输入新增的文本
            DispatchQueue.main.async {
                if text != self.lastRecognizedText {
                    let newText = text.replacingOccurrences(of: self.lastRecognizedText, with: "")
                    if !newText.isEmpty {
                        TextInputManager.shared.typeText(newText)
                    }
                    self.lastRecognizedText = text
                }
            }
        }
    }
    
    private func toggleRecording() {
        print("🎤 切换录音状态...")
        
        if !config.isConfigured {
            print("⚠️ API Key 未配置")
            return
        }
        
        if showingFloatingMic {
            print("⏹️ 停止录音")
            closeFloatingMic()
        } else {
            print("▶️ 开始录音")
            openFloatingMic()
        }
    }
    
    private func openFloatingMic() {
        showingFloatingMic = true
        lastRecognizedText = ""
        
        // 异步连接 WebSocket
        DispatchQueue.global(qos: .userInitiated).async {
            self.webSocket.connect()
            
            // 等待连接建立，最多等待 3 秒
            var waitCount = 0
            while !self.webSocket.isConnected && waitCount < 30 {
                Thread.sleep(forTimeInterval: 0.1)
                waitCount += 1
            }
            
            DispatchQueue.main.async {
                if self.webSocket.isConnected {
                    print("✅ WebSocket 已连接")
                    self.webSocket.startTask()
                    
                    // 等待任务启动后开始录音
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.audioRecorder.startRecording()
                    }
                } else {
                    print("❌ WebSocket 连接超时")
                    self.webSocket.errorMessage = "连接超时，请检查网络和 API Key"
                    // 自动关闭悬浮窗
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.showingFloatingMic = false
                    }
                }
            }
        }
    }
    
    private func closeFloatingMic() {
        audioRecorder.stopRecording()
        webSocket.finishTask()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            webSocket.disconnect()
            showingFloatingMic = false
            lastRecognizedText = ""
        }
    }
    
    private func testRecognition() {
        toggleRecording()
    }
    
    private func openSettings() {
        // 打开设置窗口
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
