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
    @StateObject private var appDelegate = AppDelegate()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("设置...") {
                    appDelegate.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        
        // 设置窗口
        WindowGroup("设置", id: "settings") {
            SettingsView()
                .frame(minWidth: 600, minHeight: 500)
        }
        .defaultSize(width: 600, height: 500)
    }
}

class AppDelegate: ObservableObject {
    @Published var showingSettings = false
    
    func showSettings() {
        if let url = URL(string: "voicenow://settings") {
            NSWorkspace.shared.open(url)
        }
    }
}
