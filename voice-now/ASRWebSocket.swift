//
//  ASRWebSocket.swift
//  voice-now
//
//  Fun-ASR WebSocket 通信管理
//

import Foundation
import Combine

class ASRWebSocket: NSObject, ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var taskId: String = ""
    private var isManuallyClosed = false  // 用于区分主动断开导致的 cancelled
    
    @Published var isConnected = false
    @Published var errorMessage: String?
    @Published var recognitionText = ""
    
    var onResultGenerated: ((String, Bool) -> Void)?  // (text, isFinal)
    var onConnected: (() -> Void)?  // 连接成功回调
    var onConnectionFailed: (() -> Void)?  // 连接失败回调
    
    override init() {
        super.init()
    }
    
    func connect() {
        print("🔌 开始连接 WebSocket...")
        isManuallyClosed = false
        
        // 先清理旧连接
        if webSocketTask != nil {
            print("⚠️ 检测到旧连接，先清理")
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
        }
        
        guard !ConfigManager.shared.apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = "请先配置 API Key"
            }
            print("❌ API Key 为空")
            return
        }
        
        let urlString = ConfigManager.shared.region.rawValue
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.errorMessage = "无效的 URL"
            }
            print("❌ URL 无效: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("bearer \(ConfigManager.shared.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 30
        
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        print("⏳ WebSocket 连接中...")
        receiveMessage()
    }
    
    func disconnect() {
        print("📡 准备断开 WebSocket...")
        isManuallyClosed = true
        
        // 清理回调
        onConnected = nil
        onConnectionFailed = nil
        
        // 立即执行清理，而不是 dispatch async
        // 如果不在主线程，才 dispatch
        if Thread.isMainThread {
            self.performDisconnect()
        } else {
            DispatchQueue.main.async {
                self.performDisconnect()
            }
        }
    }
    
    private func performDisconnect() {
        self.webSocketTask?.cancel(with: .goingAway, reason: nil)
        self.webSocketTask = nil
        self.isConnected = false
        self.recognitionText = ""
        self.taskId = ""
        print("✅ WebSocket 已完全断开")
    }
    
    func startTask() {
        taskId = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(32)).lowercased()
        
        let message: [String: Any] = [
            "header": [
                "action": "run-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "model": "fun-asr-realtime",
                "parameters": [
                    "format": "pcm",
                    "sample_rate": ConfigManager.shared.sampleRate
                ],
                "input": [:]
            ]
        ]
        
        sendJSON(message)
    }
    
    func sendAudioData(_ data: Data) {
        guard isConnected else { return }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("发送音频数据错误: \(error)")
            }
        }
    }
    
    func finishTask() {
        let message: [String: Any] = [
            "header": [
                "action": "finish-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "input": [:]
            ]
        ]
        
        sendJSON(message)
    }
    
    private func sendJSON(_ json: [String: Any]) {
        // 打印发送的消息
        if let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print("📤 发送 WebSocket 消息:\n\(prettyString)")
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: json),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("发送消息错误: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                
                // 继续接收下一条消息
                self.receiveMessage()
                
            case .failure(let error):
                let nsError = error as NSError
                
                // 如果是我们主动断开或系统返回的 cancelled（如 stop 时的取消），忽略
                if self.isManuallyClosed || nsError.code == NSURLErrorCancelled {
                    print("ℹ️ 接收被取消（可能是主动断开），忽略错误: \(error.localizedDescription)")
                    return
                }
                
                DispatchQueue.main.async {
                    self.errorMessage = "接收消息失败: \(error.localizedDescription)"
                    self.isConnected = false
                    self.onConnectionFailed?()
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        // 打印接收的消息（格式化 JSON）
        if let data = text.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print("📥 收到 WebSocket 消息:\n\(prettyString)")
        } else {
            print("📥 收到 WebSocket 消息 (原始): \(text)")
        }
        
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let header = json["header"] as? [String: Any],
              let event = header["event"] as? String else {
            return
        }
        
        DispatchQueue.main.async {
            switch event {
            case "task-started":
                print("任务已启动")
                self.isConnected = true
                
            case "result-generated":
                if let payload = json["payload"] as? [String: Any],
                   let output = payload["output"] as? [String: Any],
                   let sentence = output["sentence"] as? [String: Any],
                   let text = sentence["text"] as? String,
                   let sentenceEnd = sentence["sentence_end"] as? Bool {
                    
                    // 更新显示的文本（中间结果和最终结果都显示）
                    self.recognitionText = text
                    
                    // 调用回调，传递文本和是否是最终结果
                    self.onResultGenerated?(text, sentenceEnd)
                    
                    if sentenceEnd {
                        print("✅ 最终识别结果: \(text)")
                    } else {
                        // 只在文本有实际内容时打印中间结果
                        if !text.isEmpty {
                            print("⏳ 中间: \(text)")
                        }
                    }
                }
                
            case "task-finished":
                print("任务已完成")
                
            case "task-failed":
                if let errorMsg = header["error_message"] as? String {
                    self.errorMessage = "识别失败: \(errorMsg)"
                }
                self.disconnect()
                
            default:
                print("未知事件: \(event)")
            }
        }
    }
}

extension ASRWebSocket: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket 连接成功")
        DispatchQueue.main.async {
            self.isConnected = true
            self.onConnected?()
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket 已断开")
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}

