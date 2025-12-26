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
    
    @Published var isConnected = false
    @Published var errorMessage: String?
    @Published var recognitionText = ""
    
    var onResultGenerated: ((String) -> Void)?
    
    override init() {
        super.init()
    }
    
    func connect() {
        print("🔌 开始连接 WebSocket...")
        
        guard !ConfigManager.shared.apiKey.isEmpty else {
            errorMessage = "请先配置 API Key"
            print("❌ API Key 为空")
            return
        }
        
        let urlString = ConfigManager.shared.region.rawValue
        guard let url = URL(string: urlString) else {
            errorMessage = "无效的 URL"
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
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
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
                DispatchQueue.main.async {
                    self.errorMessage = "接收消息失败: \(error.localizedDescription)"
                    self.isConnected = false
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
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
                   let text = sentence["text"] as? String {
                    
                    self.recognitionText = text
                    self.onResultGenerated?(text)
                    
                    print("识别结果: \(text)")
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
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket 已断开")
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}

