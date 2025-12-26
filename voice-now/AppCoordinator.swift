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
    private var isProcessing = false  // 是否正在处理输入（防止重复启动）
    private let processingQueue = DispatchQueue(label: "com.voice-now.processing", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    private var connectionTimer: Timer?  // 连接超时定时器
    private var finishTimer: Timer?  // finish-task 超时定时器
    private var hasReceivedTaskFinished = false  // 是否已收到 task-finished 事件
    
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
        
        // 请求辅助功能权限并启动监听
        startMonitoring()
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
        finishTimer?.invalidate()
        finishTimer = nil
        hasReceivedTaskFinished = false
        cancellables.removeAll()
        
        hideFloatingWindow()
    }
    
    func startMonitoring() {
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
                print("💡 请在系统设置中授权后，点击界面上的「刷新」按钮重试")
            }
        }
    }
    
    func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    private func setupCallbacks() {
        // 设置音频数据回调
        audioRecorder.onAudioData = { [weak self] data in
            self?.webSocket.sendAudioData(data)
        }
        
        // 设置任务启动回调（可以开始说话时播放提示音）
        webSocket.onTaskStarted = { [weak self] in
            guard let self = self else { return }
            print("🔔 播放提示音：可以开始说话了")
            // 播放系统提示音
            NSSound.beep()
        }
        
        // 设置识别结果回调
        webSocket.onResultGenerated = { [weak self] text, isFinal in
            guard let self = self else { return }
            
            if isFinal {
                // 句子结束，直接将最终文本输入到文本框
                print("✅ 最终结果: '\(text)'，准备输入到文本框")
                
                // 检查最终文本是否为空
                if text.isEmpty {
                    print("⚠️ 最终文本为空，跳过输入")
                    return
                }
                
                // 使用串行队列执行输入操作
                self.processingQueue.async {
                    print("⌨️ 开始输入最终文本...")
                    TextInputManager.shared.typeText(text)
                    print("📝 最终文本输入完成: \(text)")
                }
            } else {
                // 中间结果，只在悬浮窗内显示（WebSocket 的 recognitionText 会自动更新）
                print("⏳ 中间结果（仅显示）: '\(text)'")
            }
        }
        
        // 设置任务完成回调（收到 task-finished 事件）
        webSocket.onTaskFinished = { [weak self] in
            guard let self = self else {
                print("⚠️ onTaskFinished 回调执行时 self 已释放")
                return
            }
            print("🎯 收到 task-finished，等待文本输入队列完成...")
            
            // 立即标记已收到 task-finished（必须在主线程）
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                print("🏁 设置标志: hasReceivedTaskFinished = true")
                self.hasReceivedTaskFinished = true
                
                // 取消超时定时器
                if let timer = self.finishTimer {
                    print("🛑 取消超时定时器")
                    timer.invalidate()
                    self.finishTimer = nil
                } else {
                    print("⚠️ 超时定时器已经不存在")
                }
            }
            
            // 使用串行队列的 barrier，确保所有之前的文本输入操作都完成
            self.processingQueue.async { [weak self] in
                guard let self = self else { return }
                print("✅ 所有文本输入操作已完成，准备关闭")
                
                // 回到主线程关闭窗口和断开连接
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.webSocket.disconnect()
                    self.hideFloatingWindow()
                    
                    // 延迟一下确保资源释放
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self = self else { return }
                        self.isProcessing = false
                        self.hasReceivedTaskFinished = false  // 重置标志
                        print("✅ 识别会话已完全关闭，可以开始新的会话")
                    }
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
        hasReceivedTaskFinished = false  // 重置标志
        
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
        print("⏹️ 用户结束说话，停止录音")
        
        // 清理连接定时器
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        // 重置 task-finished 标志
        print("🔄 重置标志: hasReceivedTaskFinished = false")
        hasReceivedTaskFinished = false
        
        // 标记状态（但不立即清理）
        isRecording = false
        
        // 停止音频录制
        audioRecorder.stopRecording()
        print("🎤 音频录制已停止")
        
        // 发送 finish-task 指令
        webSocket.finishTask()
        print("📤 已发送 finish-task，等待服务端返回 task-finished...")
        
        // 设置超时定时器（如果 5 秒内没收到 task-finished，强制关闭）
        print("⏱️ 设置 5 秒超时定时器")
        finishTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] timer in
            guard let self = self else {
                print("⚠️ 定时器触发时 self 已释放")
                timer.invalidate()
                return
            }
            
            print("⏰ 超时定时器触发，检查标志: hasReceivedTaskFinished = \(self.hasReceivedTaskFinished)")
            
            // 检查是否已收到 task-finished
            if self.hasReceivedTaskFinished {
                print("✅ 已收到 task-finished，忽略超时")
                timer.invalidate()
                return
            }
            
            print("⚠️ 等待 task-finished 超时，强制关闭")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.forceCloseSession()
            }
            timer.invalidate()
        }
        
        // 注意：不在这里关闭窗口和断开连接
        // 等待 onTaskFinished 回调处理后续流程
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
    
    private func forceCloseSession() {
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.forceCloseSession()
            }
            return
        }
        
        print("🚨 强制关闭会话")
        
        // 取消所有定时器
        finishTimer?.invalidate()
        finishTimer = nil
        
        // 使用串行队列等待所有文本输入操作完成
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            print("✅ 文本输入队列已清空，强制关闭")
            
            // 回到主线程关闭窗口和断开连接
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.webSocket.disconnect()
                self.hideFloatingWindow()
                
                self.isProcessing = false
                self.hasReceivedTaskFinished = false  // 重置标志
                print("✅ 会话已强制关闭")
            }
        }
    }
}

