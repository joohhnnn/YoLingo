import Foundation

// MARK: - WordRepositoryProtocol

/// 生词本持久化协议
/// MVP 用 SQLite，以后可换 SwiftData / CoreData / CloudKit
protocol WordRepositoryProtocol {
    /// 保存新词
    func save(_ entry: WordEntry) async throws

    /// 更新词条（复习后更新 SRS 参数等）
    func update(_ entry: WordEntry) async throws

    /// 删除词条
    func delete(_ id: UUID) async throws

    /// 获取所有词条
    func fetchAll() async throws -> [WordEntry]

    /// 按条件筛选词条
    func fetch(where predicate: @Sendable (WordEntry) -> Bool) async throws -> [WordEntry]

    /// 按单词查找（去重用）
    func find(byWord word: String) async throws -> WordEntry?
}
