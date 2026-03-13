import Foundation

// MARK: - AIServiceProtocol

/// AI 服务协议
/// MVP：生成例句
/// 后续：语音对话、智能分组等
protocol AIServiceProtocol {
    /// 为单词生成带语境的例句
    func generateExampleSentences(for word: String, count: Int) async throws -> [String]
}
