//
//  ConfigManager.swift
//  voice-now
//
//  语音识别配置管理
//

import Foundation
import Combine

class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "apiKey")
        }
    }
    
    // 固定使用北京区域
    let region: String = "wss://dashscope.aliyuncs.com/api-ws/v1/inference/"
    
    @Published var sampleRate: Int {
        didSet {
            UserDefaults.standard.set(sampleRate, forKey: "sampleRate")
        }
    }
    
    private init() {
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        
        let savedSampleRate = UserDefaults.standard.integer(forKey: "sampleRate")
        self.sampleRate = savedSampleRate > 0 ? savedSampleRate : 16000
    }
    
    var isConfigured: Bool {
        return !apiKey.isEmpty
    }
}

