import Foundation

// MARK: - DictionaryServiceProtocol

/// 词典查询服务协议
/// MVP 用免费 API，以后可换本地词典或其他 API
protocol DictionaryServiceProtocol {
    /// 查询单词释义
    func lookup(_ word: String) async throws -> DictionaryResult
}
