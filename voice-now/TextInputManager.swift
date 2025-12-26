//
//  TextInputManager.swift
//  voice-now
//
//  文本自动输入管理
//

import Cocoa
import Carbon

class TextInputManager {
    static let shared = TextInputManager()
    
    private init() {}
    
    /// 使用粘贴板方式输入文本（不会触发输入法）
    func typeText(_ text: String) {
        guard !text.isEmpty else { return }
        
        print("📋 准备粘贴输入文本: \(text)")
        
        // 1. 保存当前剪贴板的字符串内容（只保存字符串类型）
        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)
        
        // 2. 将要输入的文本复制到剪贴板
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 3. 短暂延迟，确保剪贴板更新
        usleep(20000) // 20ms
        
        // 4. 模拟 Cmd+V 粘贴
        simulatePaste()
        
        // 5. 延迟后恢复原剪贴板内容（只恢复字符串类型）
        if let previousString = previousString, !previousString.isEmpty {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                pasteboard.setString(previousString, forType: .string)
                print("📋 已恢复剪贴板内容")
            }
        }
        
        print("✅ 文本已通过粘贴输入")
    }
    
    /// 删除指定数量的字符（使用退格键）
    func deleteCharacters(count: Int) {
        guard count > 0 else { return }
        
        print("⌫ 删除 \(count) 个字符")
        
        let source = CGEventSource(stateID: .hidSystemState)
        let deleteKeyCode: CGKeyCode = 51 // 退格键的 keyCode
        
        for _ in 0..<count {
            // 按下退格键
            if let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: deleteKeyCode, keyDown: true) {
                keyDownEvent.post(tap: .cghidEventTap)
            }
            
            // 释放退格键
            if let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: deleteKeyCode, keyDown: false) {
                keyUpEvent.post(tap: .cghidEventTap)
            }
            
            usleep(10000) // 10ms 延迟
        }
    }
    
    /// 模拟 Cmd+V 粘贴操作
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // V 键的 keyCode
        let vKeyCode: CGKeyCode = 9
        
        // 按下 Command 键
        let cmdDownEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true)
        cmdDownEvent?.flags = .maskCommand
        cmdDownEvent?.post(tap: .cghidEventTap)
        
        usleep(10000) // 10ms
        
        // 按下 V 键（同时保持 Command）
        let vDownEvent = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        vDownEvent?.flags = .maskCommand
        vDownEvent?.post(tap: .cghidEventTap)
        
        usleep(10000) // 10ms
        
        // 释放 V 键
        let vUpEvent = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        vUpEvent?.flags = .maskCommand
        vUpEvent?.post(tap: .cghidEventTap)
        
        usleep(10000) // 10ms
        
        // 释放 Command 键
        let cmdUpEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false)
        cmdUpEvent?.post(tap: .cghidEventTap)
        
        usleep(20000) // 20ms，等待粘贴完成
    }
}

