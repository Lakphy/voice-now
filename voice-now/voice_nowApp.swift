//
//  voice_nowApp.swift
//  voice-now
//
//  Created by Lakphy on 2025/12/26.
//

import SwiftUI
import Combine

@main
struct voice_nowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("设置...") {
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
    
    private func openSettings() {
        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "设置"
            settingsWindow.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow.center()
            settingsWindow.makeKeyAndOrderFront(nil)
            settingsWindow.identifier = NSUserInterfaceItemIdentifier("settings")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 应用已启动")
        
        // 启动全局协调器
        AppCoordinator.shared.start()
        
        // 确保窗口关闭时应用不退出
        NSApplication.shared.windows.forEach { window in
            window.delegate = self
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 返回 false，确保关闭窗口后应用继续在后台运行
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("👋 应用将退出")
        GlobalHotkeyMonitor.shared.stopMonitoring()
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        print("🪟 窗口已关闭，应用继续在后台运行")
    }
}
