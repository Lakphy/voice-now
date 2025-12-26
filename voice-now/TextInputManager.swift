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
    
    func typeText(_ text: String) {
        // 使用 CGEvent 模拟键盘输入
        let source = CGEventSource(stateID: .hidSystemState)
        
        for character in text {
            let keyCode = self.keyCodeForCharacter(character)
            
            if keyCode >= 0 {
                // 对于标准按键
                if let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true) {
                    keyDownEvent.post(tap: .cghidEventTap)
                }
                
                if let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false) {
                    keyUpEvent.post(tap: .cghidEventTap)
                }
                
                usleep(10000) // 10ms 延迟
            } else {
                // 对于 Unicode 字符（如中文）
                self.typeUnicodeCharacter(character, source: source)
            }
        }
    }
    
    private func typeUnicodeCharacter(_ character: Character, source: CGEventSource?) {
        let string = String(character)
        let utf16 = Array(string.utf16)
        
        for codeUnit in utf16 {
            if let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                keyDownEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [codeUnit])
                keyDownEvent.post(tap: .cghidEventTap)
            }
            
            if let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                keyUpEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [codeUnit])
                keyUpEvent.post(tap: .cghidEventTap)
            }
            
            usleep(10000) // 10ms 延迟
        }
    }
    
    private func keyCodeForCharacter(_ character: Character) -> Int {
        // 简化的按键映射（仅用于英文和标点）
        let keyMap: [Character: Int] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8,
            "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
            "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25,
            "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33,
            "i": 34, "p": 35, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
            ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, " ": 49
        ]
        
        return keyMap[Character(character.lowercased())] ?? -1
    }
}

