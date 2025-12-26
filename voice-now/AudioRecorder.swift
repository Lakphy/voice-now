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
                
                // 计算转换后的帧数（采样率转换比例）
                let ratio = targetFormat.sampleRate / recordingFormat.sampleRate
                let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
                
                // 创建转换后的缓冲区
                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: targetFormat,
                    frameCapacity: outputFrameCapacity
                ) else {
                    print("❌ 无法创建转换后的音频缓冲区")
                    return
                }
                
                convertedBuffer.frameLength = outputFrameCapacity
                
                var error: NSError?
                var hasReturnedData = false  // 标记是否已返回数据
                
                let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                    if !hasReturnedData {
                        outStatus.pointee = .haveData
                        hasReturnedData = true  // 标记为已返回
                        return buffer
                    } else {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                }
                
                if let error = error {
                    print("❌ 音频转换错误: \(error)")
                    return
                }
                
                if status == .error {
                    print("❌ 音频转换失败")
                    return
                }
                
                // 转换为 Data（使用实际转换后的帧长度）
                if let channelData = convertedBuffer.int16ChannelData {
                    let channelDataValue = channelData.pointee
                    let dataSize = Int(convertedBuffer.frameLength) * MemoryLayout<Int16>.size
                    let data = Data(bytes: channelDataValue, count: dataSize)
                    
                    // 打印调试信息（可选）
                    // print("🎵 音频数据: \(buffer.frameLength) 帧 -> \(convertedBuffer.frameLength) 帧, \(data.count) 字节")
                    
                    self.onAudioData?(data)
                }
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.errorMessage = nil
            }
            print("✅ 音频录制已启动")
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "录音启动失败: \(error.localizedDescription)"
            }
            print("录音错误: \(error)")
        }
    }
    
    func stopRecording() {
        // 使用 audioEngine 作为更可靠的检查（线程安全）
        guard let engine = audioEngine else {
            DispatchQueue.main.async { [weak self] in
                self?.isRecording = false
            }
            return
        }
        
        inputNode?.removeTap(onBus: 0)
        engine.stop()
        audioEngine = nil
        inputNode = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
        }
        print("⏹️ 音频录制已停止")
    }
}

