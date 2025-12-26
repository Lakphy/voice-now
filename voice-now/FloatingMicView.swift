//
//  FloatingMicView.swift
//  voice-now
//
//  悬浮麦克风窗口
//

import SwiftUI

struct FloatingMicView: View {
    @ObservedObject var recorder: AudioRecorder
    @ObservedObject var webSocket: ASRWebSocket
    @Binding var isVisible: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // 麦克风动画图标
            ZStack {
                Circle()
                    .fill(recorder.isRecording ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(recorder.isRecording ? 1.2 : 1.0)
                    .animation(
                        recorder.isRecording ?
                        Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) :
                            .default,
                        value: recorder.isRecording
                    )
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 36))
                    .foregroundColor(recorder.isRecording ? .red : .gray)
            }
            
            // 状态文字
            Text(recorder.isRecording ? "正在录音..." : "准备录音")
                .font(.headline)
                .foregroundColor(.primary)
            
            // 识别结果
            if !webSocket.recognitionText.isEmpty {
                ScrollView {
                    Text(webSocket.recognitionText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxHeight: 100)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 错误信息
            if let errorMessage = recorder.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            if let errorMessage = webSocket.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            // 关闭按钮
            Button("关闭 (或按右 Command)") {
                isVisible = false
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(width: 300)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// 毛玻璃效果
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

