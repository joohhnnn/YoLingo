import Foundation

// MARK: - Config

/// 应用全局配置
/// 从 SettingsService 读取用户配置，提供合理的默认值
struct Config {

    private let settings: SettingsServiceProtocol?

    init(settings: SettingsServiceProtocol? = nil) {
        self.settings = settings
    }

    // MARK: - AI Service

    var openAIKey: String {
        settings?.getAPIKey(for: "openai")
            ?? ProcessInfo.processInfo.environment["YOLINGO_OPENAI_KEY"]
            ?? ""
    }

    var geminiKey: String {
        settings?.getAPIKey(for: "gemini")
            ?? ProcessInfo.processInfo.environment["YOLINGO_GEMINI_KEY"]
            ?? ""
    }

    /// AI 例句生成数量
    var exampleSentenceCount: Int = 2

    // MARK: - Capture

    /// 抓词快捷键（MVP 默认 fn）
    var captureHotkey: CaptureHotkey = .fn

    /// OCR 截图区域大小（像素）
    var ocrCaptureSize: CGSize = CGSize(width: 400, height: 100)

    // MARK: - Floating Card

    var floatingCardPosition: FloatingCardPosition {
        settings?.floatingCardPosition ?? .bottomRight
    }

    var floatingCardIdleOpacity: Double {
        settings?.floatingCardOpacity ?? 0.85
    }

    // MARK: - SRS

    /// SRS 算法类型
    var srsAlgorithm: SRSAlgorithmType = .sm2

    // MARK: - Storage

    /// 数据库文件名
    var databaseFileName: String = "yolingo.db"
}

// MARK: - Supporting Types

enum CaptureHotkey: String {
    case fn
    // 以后可以扩展其他快捷键组合
}

enum SRSAlgorithmType: String {
    case sm2
    case fsrs  // 后续实现
}
