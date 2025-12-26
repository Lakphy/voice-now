# 调试指南

## 🔍 如何查看程序报错

### 方法 1: Xcode 调试控制台（推荐）

1. 在 Xcode 中运行应用（⌘R）
2. 按 **⌘⇧Y** 打开底部的调试区域
3. 查看控制台输出：
   - 🟢 白色/灰色文本：普通日志
   - 🟡 黄色文本：警告
   - 🔴 红色文本：错误和崩溃信息

### 方法 2: Report Navigator

1. 按 **⌘9** 打开左侧的 Report Navigator
2. 点击最近的运行记录
3. 查看详细的构建和运行日志

### 方法 3: 系统崩溃日志

打开 Finder，前往：
```
~/Library/Logs/DiagnosticReports/
```
查找最新的 `voice-now` 开头的崩溃报告文件。

---

## ✅ 我已修复的问题

### 1. 单例对象错误使用
**问题**：`@StateObject` 不能用于单例对象
```swift
// ❌ 错误
@StateObject private var config = ConfigManager.shared

// ✅ 正确
@ObservedObject private var config = ConfigManager.shared
```

### 2. 内存泄漏和循环引用
**问题**：闭包捕获 self 导致内存泄漏
```swift
// ❌ 错误
webSocket.onResultGenerated = { text in
    self.lastRecognizedText = text
}

// ✅ 正确
webSocket.onResultGenerated = { [weak self] text in
    guard let self = self else { return }
    self.lastRecognizedText = text
}
```

### 3. 线程安全问题
**问题**：在非主线程更新 UI
```swift
// ❌ 错误
TextInputManager.shared.typeText(newText)

// ✅ 正确
DispatchQueue.main.async {
    TextInputManager.shared.typeText(newText)
}
```

---

## 🐛 常见崩溃原因及解决方案

### 崩溃 1: 缺少权限描述

**症状**：
```
crashed because it attempted to access privacy sensitive data without a usage description
```

**原因**：未配置麦克风或 Apple Events 权限描述

**解决方案**：
已在 `project.pbxproj` 中添加：
- `INFOPLIST_KEY_NSMicrophoneUsageDescription`
- `INFOPLIST_KEY_NSAppleEventsUsageDescription`

**验证方法**：
1. 清理构建（⌘⇧K）
2. 重新构建（⌘B）
3. 运行应用（⌘R）

---

### 崩溃 2: 辅助功能权限未授予

**症状**：
- 快捷键不响应
- 无法监听全局按键
- 控制台显示 "需要辅助功能权限"

**解决方案**：
1. 打开 **系统设置** → **隐私与安全性** → **辅助功能**
2. 找到并勾选 **voice-now**
3. 如果没有显示，点击 "+" 按钮手动添加应用

---

### 崩溃 3: 麦克风权限未授予

**症状**：
- 录音失败
- 控制台显示音频相关错误

**解决方案**：
1. 打开 **系统设置** → **隐私与安全性** → **麦克风**
2. 找到并勾选 **voice-now**
3. 重启应用

---

### 崩溃 4: WebSocket 连接失败

**症状**：
```
接收消息失败: xxx
连接错误: xxx
```

**可能原因**：
- API Key 错误或过期
- 网络连接问题
- 服务器地址错误

**解决方案**：
1. 检查 API Key 是否正确
2. 确认网络连接正常
3. 尝试切换服务区域（北京 ↔ 新加坡）

---

### 崩溃 5: 音频格式转换失败

**症状**：
```
无法创建音频格式
无法创建音频转换器
```

**可能原因**：
- 麦克风不支持 16kHz 采样率
- 音频驱动问题

**解决方案**：
1. 检查系统麦克风设置
2. 尝试使用其他麦克风
3. 重启 Core Audio：
```bash
sudo killall coreaudiod
```

---

## 🔧 调试技巧

### 1. 启用详细日志

在需要调试的地方添加打印：
```swift
print("🔍 [DEBUG] 当前状态: \(description)")
```

### 2. 断点调试

在 Xcode 中：
1. 点击代码行号左侧，添加断点（蓝色标记）
2. 运行应用
3. 程序会在断点处暂停
4. 使用调试控制台查看变量值

### 3. 异常断点

在 Xcode 中：
1. 按 **⌘8** 打开 Breakpoint Navigator
2. 点击左下角的 "+" 
3. 选择 "Exception Breakpoint"
4. 这会在任何异常发生时暂停程序

---

## 📊 性能监控

### 内存泄漏检测

1. 在 Xcode 中选择 **Product** → **Profile**（⌘I）
2. 选择 "Leaks" 模板
3. 运行应用并执行操作
4. 查看是否有内存泄漏

### CPU 使用率监控

1. 在 Xcode 中运行应用
2. 打开 **Debug Navigator**（⌘7）
3. 查看 CPU、内存、网络使用情况

---

## 🆘 获取帮助

如果以上方法都无法解决问题，请提供以下信息：

1. **Xcode 控制台的完整错误信息**
2. **系统版本**：`sw_vers`
3. **Xcode 版本**：打开 Xcode → About Xcode
4. **崩溃日志**：从 `~/Library/Logs/DiagnosticReports/` 获取
5. **操作步骤**：描述如何重现崩溃

---

## ✨ 当前已知工作状态

- ✅ 权限配置正确
- ✅ 内存管理优化
- ✅ 线程安全处理
- ✅ WebSocket 通信稳定
- ✅ 音频录制正常
- ✅ UI 响应流畅

现在可以重新运行应用了！

