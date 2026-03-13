import Foundation

// MARK: - AppEvent

/// 事件总线中流转的事件类型
/// 模块间通过发布/订阅这些事件实现解耦
enum AppEvent {
    // 抓词相关
    case captureActivated                        // fn 按下，进入抓词模式
    case captureDeactivated                      // fn 松开，退出抓词模式
    case captureClicked(CGPoint)                 // fn+点击，开始抓词（位置为 Cocoa 坐标）
    case wordCaptured(CaptureResult)             // 成功抓到文字
    case captureFailed(CaptureError)             // 抓词失败

    // 生词本相关
    case wordSaved(WordEntry)                    // 新词已存入生词本
    case wordUpdated(WordEntry)                  // 词条已更新（复习后）
    case wordDeleted(UUID)                       // 词条已删除

    // 复习相关
    case wordReviewed(WordEntry, ReviewFeedback)  // 用户完成一次复习
    case reviewSessionStarted                     // 开始复习会话
    case reviewSessionEnded                       // 结束复习会话

    // 设置相关
    case settingsChanged(SettingsKey)            // 某个设置项发生变化
}

// MARK: - CaptureError

enum CaptureError: Error, LocalizedError {
    case accessibilityNotAvailable
    case ocrFailed
    case noTextFound
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .accessibilityNotAvailable:
            return "无法通过 Accessibility API 获取文本"
        case .ocrFailed:
            return "OCR 文字识别失败"
        case .noTextFound:
            return "未检测到有效文字"
        case .permissionDenied:
            return "缺少必要的系统权限"
        }
    }
}
