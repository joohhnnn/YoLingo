import Foundation

// MARK: - CaptureResult

/// 抓词操作的结果
struct CaptureResult {
    let text: String
    let sourceApp: String
    let captureMethod: CaptureMethod
    let position: CGPoint          // 抓取位置（屏幕坐标，用于动画起点）
    let timestamp: Date

    init(
        text: String,
        sourceApp: String = "",
        captureMethod: CaptureMethod,
        position: CGPoint = .zero,
        timestamp: Date = Date()
    ) {
        self.text = text
        self.sourceApp = sourceApp
        self.captureMethod = captureMethod
        self.position = position
        self.timestamp = timestamp
    }
}

// MARK: - CaptureMethod

enum CaptureMethod: String {
    case accessibility  // 通过 Accessibility API 获取
    case ocr            // 通过截图 + Vision OCR 获取
}
