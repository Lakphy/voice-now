//
//  GlobalHotkeyMonitor.swift
//  voice-now
//
//  全局快捷键监听（右 Command 键）
//

import Cocoa
import Carbon
import Combine

class GlobalHotkeyMonitor: ObservableObject {
    static let shared = GlobalHotkeyMonitor()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    var onRightCommandPressed: (() -> Void)?
    
    private init() {}
    
    func startMonitoring() -> Bool {
        // 请求辅助功能权限
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        guard accessEnabled else {
            print("需要辅助功能权限")
            return false
        }
        
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                
                let monitor = Unmanaged<GlobalHotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handleEvent(type: type, event: event)
                
                return Unmanaged.passRetained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("无法创建事件监听")
            return false
        }
        
        self.eventTap = eventTap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        print("全局快捷键监听已启动")
        return true
    }
    
    func stopMonitoring() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        
        print("全局快捷键监听已停止")
    }
    
    private var isRightCommandPressed = false
    
    private func handleEvent(type: CGEventType, event: CGEvent) {
        guard type == .flagsChanged else { return }
        
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // 右 Command 键的 keyCode 是 54
        guard keyCode == 54 else { return }
        
        let commandPressed = flags.contains(.maskCommand)
        
        // 检测右 Command 键按下（从未按下到按下）
        if commandPressed && !isRightCommandPressed {
            isRightCommandPressed = true
            DispatchQueue.main.async {
                self.onRightCommandPressed?()
            }
        }
        // 检测右 Command 键释放
        else if !commandPressed && isRightCommandPressed {
            isRightCommandPressed = false
        }
    }
}

