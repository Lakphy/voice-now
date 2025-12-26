//
//  AudioRecorder.swift
//  voice-now
//
//  音频录制管理
//

import AVFoundation
import Foundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    @Published var isRecording = false
    @Published var errorMessage: String?
    
    var onAudioData: ((Data) -> Void)?
    
    override init() {
        super.init()
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        do {
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { return }
            
            inputNode = audioEngine.inputNode
            guard let inputNode = inputNode else { return }
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            let sampleRate = ConfigManager.shared.sampleRate
            
            // 创建 16kHz 单声道 PCM 格式
            guard let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: Double(sampleRate),
                channels: 1,
                interleaved: true
            ) else {
                errorMessage = "无法创建音频格式"
                return
            }
            
            // 创建格式转换器
            guard let converter = AVAudioConverter(from: recordingFormat, to: targetFormat) else {
                errorMessage = "无法创建音频转换器"
                return
            }
            
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self else { return }
                
                // 转换音频格式
                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: targetFormat,
                    frameCapacity: AVAudioFrameCount(targetFormat.sampleRate * 2.0 / recordingFormat.sampleRate * Double(buffer.frameCapacity))
                ) else {
                    print("无法创建转换后的音频缓冲区")
                    return
                }
                
                var error: NSError?
                converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                if let error = error {
                    print("音频转换错误: \(error)")
                    return
                }
                
                // 转换为 Data
                if let channelData = convertedBuffer.int16ChannelData {
                    let channelDataValue = channelData.pointee
                    let dataSize = Int(convertedBuffer.frameLength) * MemoryLayout<Int16>.size
                    let data = Data(bytes: channelDataValue, count: dataSize)
                    
                    self.onAudioData?(data)
                }
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            errorMessage = nil
            print("✅ 音频录制已启动")
            
        } catch {
            errorMessage = "录音启动失败: \(error.localizedDescription)"
            print("录音错误: \(error)")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        isRecording = false
        print("⏹️ 音频录制已停止")
    }
}

