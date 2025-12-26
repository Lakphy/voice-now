//
//  AppCoordinator.swift
//  voice-now
//
//  全局应用协调器 - 管理后台运行和全局快捷键
//

import Cocoa
import SwiftUI
import Combine

class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()
    
    @Published var isRecording = false
    
    private var audioRecorder = AudioRecorder()
    private var webSocket = ASRWebSocket()
    private var config = ConfigManager.shared
    
    private var floatingWindow: NSWindow?
    private var lastInputText = ""  // 上次输入的文本（用于计算差异）
    private var inputCharCount = 0  // 已输入的字符数（用于删除）
    private var isProcessing = false  // 是否正在处理输入（防止重复启动）
    private let processingQueue = DispatchQueue(label: "com.voice-now.processing", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    private var connectionTimer: Timer?  // 连接超时定时器
    
    private init() {
        setupCallbacks()
    }
    
    func start() {
        print("🚀 启动应用协调器")
        
        // 请求麦克风权限
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.audioRecorder.requestPermission { granted in
                print("🎤 麦克风权限: \(granted ? "已授予" : "未授予")")
            }
        }
        
        // 请求辅助功能权限并启动监听（带重试机制）
        startMonitoringWithRetry()
    }
    
    func terminate() {
        print("🛑 应用即将退出，强制清理资源")
        // 立即停止所有活动，不等待队列
        GlobalHotkeyMonitor.shared.stopMonitoring()
        
        // 确保音频引擎停止
        audioRecorder.stopRecording()
        
        // 确保 WebSocket 断开
        webSocket.disconnect()
        
        connectionTimer?.invalidate()
        connectionTimer = nil
        cancellables.removeAll()
        
        hideFloatingWindow()
    }
    
    private func startMonitoringWithRetry(retryCount: Int = 0) {
        // 先请求权限（会弹出系统提示）
        GlobalHotkeyMonitor.shared.requestAccessibilityPermission()
        
        // 延迟后在主线程尝试启动监听
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // 尝试启动监听（必须在主线程）
            let monitor = GlobalHotkeyMonitor.shared
            let started = monitor.startMonitoring()
            
            if started {
                print("⌨️ 全局快捷键监听已启动")
                // 设置回调
                monitor.onRightCommandPressed = { [weak self] in
                    print("🔔 检测到右 Command 键按下！")
                    self?.toggleRecording()
                }
                print("🎯 快捷键回调已设置")
            } else {
                print("❌ 全局快捷键监听启动失败 - 需要在「系统设置 > 隐私与安全性 > 辅助功能」中授权")
                
                // 开发模式：10秒后自动重试（最多3次）
                if retryCount < 3 {
                    print("🔄 将在 10 秒后自动重试... (第 \(retryCount + 1)/3 次)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                        self.startMonitoringWithRetry(retryCount: retryCount + 1)
                    }
                }
            }
        }
    }
    
    func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    private func typeIncrementalText(newText: String) {
        // 注意：此方法在后台线程调用，避免阻塞主线程
        
        // 获取当前状态（需要线程安全访问）
        let currentLastText = self.lastInputText
        let currentInputCount = self.inputCharCount
        
        // 如果新文本比上次短，说明识别回退了，需要删除多余的字符
        if newText.count < currentLastText.count {
            let deleteCount = currentLastText.count - newText.count
            print("⬅️ 删除 \(deleteCount) 个字符")
            TextInputManager.shared.deleteCharacters(count: deleteCount)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.inputCharCount = max(0, self.inputCharCount - deleteCount)
            }
        }
        
        // 找出新增的文本部分
        if newText.hasPrefix(currentLastText) {
            // 新文本是旧文本的扩展，输入新增部分
            let newPart = String(newText.dropFirst(currentLastText.count))
            if !newPart.isEmpty {
                print("⌨️ 输入新增部分: \(newPart)")
                TextInputManager.shared.typeText(newPart)
                
                DispatchQueue.main.async { [weak self] in
                    self?.inputCharCount += newPart.count
                }
            }
        } else {
            // 识别结果完全不同，删除所有旧的，输入全新的
            if currentInputCount > 0 {
                print("🔄 识别结果变化，删除 \(currentInputCount) 个字符，重新输入")
                TextInputManager.shared.deleteCharacters(count: currentInputCount)
            }
            
            if !newText.isEmpty {
                print("⌨️ 输入新文本: \(newText)")
                TextInputManager.shared.typeText(newText)
                
                DispatchQueue.main.async { [weak self] in
                    self?.inputCharCount = newText.count
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.inputCharCount = 0
                }
            }
        }
        
        // 更新状态
        DispatchQueue.main.async { [weak self] in
            self?.lastInputText = newText
        }
    }
    
    private func setupCallbacks() {
        // 设置音频数据回调
        audioRecorder.onAudioData = { [weak self] data in
            self?.webSocket.sendAudioData(data)
        }
        
        // 设置识别结果回调
        webSocket.onResultGenerated = { [weak self] text, isFinal in
            guard let self = self else { return }
            
            if isFinal {
                // 句子结束，删除中间输入的文本，输入最终正确的文本
                let currentCount = self.inputCharCount
                print("✅ 最终结果，删除 \(currentCount) 个字符，输入正确文本")
                
                // 使用串行队列执行输入操作，避免并发问题
                self.processingQueue.async { [weak self] in
                    guard let self = self else { return }
                    
                    // 删除之前输入的所有中间文本
                    if currentCount > 0 {
                        TextInputManager.shared.deleteCharacters(count: currentCount)
                    }
                    
                    // 输入最终的正确文本
                    TextInputManager.shared.typeText(text)
                    print("📝 最终输入完成: \(text)")
                    
                    // 回到主线程重置状态
                    DispatchQueue.main.async { [weak self] in
                        self?.lastInputText = ""
                        self?.inputCharCount = 0
                    }
                }
            } else {
                // 中间结果，使用串行队列实时输入差异部分
                self.processingQueue.async { [weak self] in
                    self?.typeIncrementalText(newText: text)
                }
            }
        }
        
        // 监听 WebSocket 错误（只打印日志，不弹窗）
        webSocket.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] errorMsg in
                guard let self = self else { return }
                print("❌ WebSocket 错误: \(errorMsg)")
                DispatchQueue.main.async {
                    // 停止录音并关闭浮窗
                    if self.isRecording {
                        self.stopRecording()
                    } else {
                        self.hideFloatingWindow()
                    }
                    self.isProcessing = false
                }
            }
            .store(in: &cancellables)
    }
    
    func toggleRecording() {
        print("🎤 切换录音状态...")
        
        // 确保在主线程处理状态
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.toggleRecording()
            }
            return
        }
        
        if !config.isConfigured {
            print("⚠️ API Key 未配置，请先在主窗口配置")
            return
        }
        
        // 防止在处理中重复操作
        if isProcessing {
            print("⚠️ 正在处理中，请稍候...")
            return
        }
        
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        // 关键 UI 操作需要在主线程
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.startRecording()
            }
            return
        }
        print("▶️ 开始录音")
        
        // 确保之前的会话完全停止
        audioRecorder.stopRecording()  // 内部有 guard，安全调用
        
        // 立即断开旧连接（确保同步执行）
        webSocket.disconnect()
        
        // 清理之前的定时器和窗口
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        // 先清理旧窗口
        if floatingWindow != nil {
            hideFloatingWindow()
        }
        
        // 标记为处理中
        isProcessing = true
        isRecording = true
        lastInputText = ""
        inputCharCount = 0
        
        // 显示新窗口
        showFloatingWindow()
        
        // 然后开始连接（在后台线程）
        startWebSocketConnection()
    }
    
    private func startWebSocketConnection() {
        
        // 设置连接成功回调
        webSocket.onConnected = { [weak self] in
            guard let self = self else { return }
            print("✅ WebSocket 已连接")
            
            // 取消超时定时器
            self.connectionTimer?.invalidate()
            self.connectionTimer = nil
            
            self.webSocket.startTask()
            
            // 启动录音
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.audioRecorder.startRecording()
                print("✅ 音频录制已启动")
                // 启动成功，解除处理标志
                self.isProcessing = false
            }
        }
        
        // 连接失败回调（例如握手失败）
        webSocket.onConnectionFailed = { [weak self] in
            guard let self = self else { return }
            print("❌ WebSocket 连接失败，请检查网络和 API Key")
            DispatchQueue.main.async {
                self.webSocket.errorMessage = "连接失败，请检查网络和 API Key"
                self.isProcessing = false
                if self.isRecording {
                    self.stopRecording()
                }
            }
        }
        
        // 设置连接超时定时器（保存到实例变量）
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if !self.webSocket.isConnected {
                print("❌ WebSocket 连接超时，请检查网络和 API Key")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.webSocket.errorMessage = "连接超时，请检查网络和 API Key"
                    self.isProcessing = false
                    self.stopRecording()
                }
            }
            timer.invalidate()
        }
        
        // 连接 WebSocket
        webSocket.connect()
    }
    
    private func stopRecording() {
        // 关键 UI 操作需要在主线程
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.stopRecording()
            }
            return
        }
        print("⏹️ 停止录音")
        
        // 清理定时器
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        // 标记为处理中，防止重复操作
        isProcessing = true
        isRecording = false
        
        // 在后台线程处理停止操作，避免阻塞主线程
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.audioRecorder.stopRecording()
            print("🎤 录音已停止")
            
            self.webSocket.finishTask()
            print("📤 已发送 finish-task")
            
            // 等待 WebSocket 处理完成
            Thread.sleep(forTimeInterval: 1.0)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.webSocket.disconnect()
                self.hideFloatingWindow()
                
                // 等待更长时间确保所有输入操作完成和资源释放
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    self.lastInputText = ""
                    self.inputCharCount = 0
                    self.isProcessing = false
                    print("✅ 识别会话已关闭，可以开始新的会话")
                }
            }
        }
    }
    
    private func showFloatingWindow() {
        // 确保在主线程执行
        assert(Thread.isMainThread, "showFloatingWindow must be called on main thread")
        
        // 先确保旧窗口完全清理
        if floatingWindow != nil {
            print("⚠️ 清理旧窗口")
            hideFloatingWindow()
        }
        
        // 创建悬浮窗口（使用 NSPanel 支持 non-activating）
        let contentView = FloatingMicView(
            recorder: audioRecorder,
            webSocket: webSocket,
            isVisible: Binding(
                get: { [weak self] in self?.isRecording ?? false },
                set: { [weak self] newValue in
                    if !newValue {
                        self?.stopRecording()
                    }
                }
            )
        )
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: contentView)
        panel.center()
        panel.orderFrontRegardless()
        
        self.floatingWindow = panel
        print("✅ 悬浮窗口已创建")
    }
    
    private func hideFloatingWindow() {
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.hideFloatingWindow()
            }
            return
        }
        
        if let window = floatingWindow {
            // 先清理 contentView，断开 SwiftUI 的绑定
            window.contentView = nil
            window.close()
            print("✅ 悬浮窗口已关闭")
        }
        floatingWindow = nil
    }
}

