//
//  HistoryManager.swift
//  voice-now
//
//  历史记录管理
//

import Foundation
import SwiftUI
import Combine

struct RecognitionHistory: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    
    init(id: UUID = UUID(), text: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var histories: [RecognitionHistory] = []
    
    private let saveKey = "recognitionHistories"
    private let maxHistoryCount = 1000 // 最多保存1000条
    
    private init() {
        loadHistories()
    }
    
    func addHistory(text: String) {
        guard !text.isEmpty else { return }
        
        let history = RecognitionHistory(text: text)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 添加到开头
            self.histories.insert(history, at: 0)
            
            // 限制数量（最多100条，防止内存和性能问题）
            if self.histories.count > self.maxHistoryCount {
                self.histories = Array(self.histories.prefix(self.maxHistoryCount))
            }
            
            // 异步保存到磁盘，不阻塞主线程
            DispatchQueue.global(qos: .utility).async {
                self.saveHistories()
            }
            
            print("📝 已添加历史记录 (共 \(self.histories.count) 条): \(text.prefix(20))...")
        }
    }
    
    func deleteHistory(at offsets: IndexSet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.histories.remove(atOffsets: offsets)
            
            // 异步保存，不阻塞UI
            DispatchQueue.global(qos: .utility).async {
                self.saveHistories()
            }
        }
    }
    
    func clearAll() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let count = self.histories.count
            self.histories.removeAll()
            
            // 异步保存，不阻塞UI
            DispatchQueue.global(qos: .utility).async {
                self.saveHistories()
            }
            
            print("🗑️ 已清空 \(count) 条历史记录")
        }
    }
    
    private func saveHistories() {
        if let encoded = try? JSONEncoder().encode(histories) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadHistories() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([RecognitionHistory].self, from: data) {
            self.histories = decoded
            print("📚 已加载 \(decoded.count) 条历史记录")
        }
    }
}

