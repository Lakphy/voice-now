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
    @State private var waveScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部状态栏
            HStack(spacing: 12) {
                // 脉动波纹动画
                ZStack {
                    // 外层波纹
                    if recorder.isRecording {
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 2)
                            .frame(width: 50, height: 50)
                            .scaleEffect(waveScale)
                            .opacity(2 - waveScale)
                    }
                    
                    // 中层波纹
                    if recorder.isRecording {
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                            .frame(width: 42, height: 42)
                            .scaleEffect(waveScale * 0.8)
                            .opacity(2 - waveScale)
                    }
                    
                    // 麦克风图标
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: recorder.isRecording ? 
                                        [Color.red, Color.red.opacity(0.8)] :
                                        [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: recorder.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 50, height: 50)
                .onAppear {
                    if recorder.isRecording {
                        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                            waveScale = 1.8
                        }
                    }
                }
                .onChange(of: recorder.isRecording) { isRecording in
                    if isRecording {
                        waveScale = 1.0
                        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                            waveScale = 1.8
                        }
                    } else {
                        waveScale = 1.0
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(recorder.isRecording ? "正在录音" : "准备录音")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("按右⌘键停止")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 关闭按钮
                Button {
                    isVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.controlBackgroundColor).opacity(0.3))
            
            Divider()
            
            // 识别结果区域
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label {
                        Text("识别内容")
                            .font(.system(size: 12, weight: .medium))
                    } icon: {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !webSocket.recognitionText.isEmpty {
                        Text("\(webSocket.recognitionText.count) 字")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                ScrollView {
                    if webSocket.recognitionText.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "ellipsis.bubble")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary.opacity(0.5))
                            
                            Text("等待识别...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        Text(webSocket.recognitionText)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(8)
                    }
                }
                .frame(height: 100)
            }
            .padding(16)
            
            // 错误信息
            if let errorMessage = recorder.errorMessage ?? webSocket.errorMessage {
                VStack {
                    Divider()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        
                        Text(errorMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.1))
                }
            }
        }
        .frame(width: 340)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
        )
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 15)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
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

