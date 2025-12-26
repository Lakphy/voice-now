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
    private let maxHistoryCount = 100 // 最多保存100条
    
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
            
            // 限制数量
            if self.histories.count > self.maxHistoryCount {
                self.histories = Array(self.histories.prefix(self.maxHistoryCount))
            }
            
            self.saveHistories()
            print("📝 已保存历史记录: \(text)")
        }
    }
    
    func deleteHistory(at offsets: IndexSet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.histories.remove(atOffsets: offsets)
            self.saveHistories()
        }
    }
    
    func clearAll() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.histories.removeAll()
            self.saveHistories()
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

