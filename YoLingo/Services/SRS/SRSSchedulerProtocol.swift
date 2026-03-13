import Foundation

// MARK: - SRSSchedulerProtocol

/// 间隔重复调度协议
/// MVP 用 SM-2，以后可换 FSRS，只需写新实现类
protocol SRSSchedulerProtocol {
    /// 根据用户反馈计算新的 SRS 调度参数
    func schedule(_ entry: WordEntry, feedback: ReviewFeedback) -> SRSData

    /// 从词条列表中筛选出指定日期需要复习的词
    func getDueWords(from entries: [WordEntry], on date: Date) -> [WordEntry]
}
