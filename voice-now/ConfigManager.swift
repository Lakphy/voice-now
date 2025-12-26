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
    
    @Published var region: Region {
        didSet {
            UserDefaults.standard.set(region.rawValue, forKey: "region")
        }
    }
    
    @Published var sampleRate: Int {
        didSet {
            UserDefaults.standard.set(sampleRate, forKey: "sampleRate")
        }
    }
    
    enum Region: String, CaseIterable {
        case beijing = "wss://dashscope.aliyuncs.com/api-ws/v1/inference/"
        case singapore = "wss://dashscope-intl.aliyuncs.com/api-ws/v1/inference/"
        
        var displayName: String {
            switch self {
            case .beijing: return "中国大陆（北京）"
            case .singapore: return "国际（新加坡）"
            }
        }
    }
    
    private init() {
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        
        if let regionString = UserDefaults.standard.string(forKey: "region"),
           let region = Region(rawValue: regionString) {
            self.region = region
        } else {
            self.region = .beijing
        }
        
        let savedSampleRate = UserDefaults.standard.integer(forKey: "sampleRate")
        self.sampleRate = savedSampleRate > 0 ? savedSampleRate : 16000
    }
    
    var isConfigured: Bool {
        return !apiKey.isEmpty
    }
}

