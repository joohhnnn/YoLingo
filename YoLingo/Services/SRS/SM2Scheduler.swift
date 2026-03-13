import Foundation

// MARK: - SM2Scheduler

/// SM-2 算法实现
/// 参考: https://www.supermemo.com/en/blog/application-of-a-computer-to-improve-the-results-of-learning
///
/// 核心逻辑：
/// - 每次复习后根据用户反馈调整间隔和难度系数
/// - 反馈越好 → 间隔越长、难度系数越高
/// - 反馈越差 → 重置间隔、降低难度系数
final class SM2Scheduler: SRSSchedulerProtocol {

    func schedule(_ entry: WordEntry, feedback: ReviewFeedback) -> SRSData {
        var data = entry.srsData

        // SM-2 quality 通常是 0-5，我们用 0-3 映射为 0,2,4,5
        let mappedQuality = mapQuality(feedback)

        if mappedQuality < 3 {
            // 回答不好：重置重复次数，从头开始
            data.repetitions = 0
            data.interval = 60  // 1 分钟后再复习
        } else {
            // 回答正确：递增间隔
            data.repetitions += 1

            switch data.repetitions {
            case 1:
                data.interval = 60 * 60           // 1 小时
            case 2:
                data.interval = 60 * 60 * 24      // 1 天
            default:
                data.interval = data.interval * data.easeFactor
            }
        }

        // 更新难度系数 (EF)
        // EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        let ef = data.easeFactor + (0.1 - Double(5 - mappedQuality) * (0.08 + Double(5 - mappedQuality) * 0.02))
        data.easeFactor = max(1.3, ef)  // 最低 1.3

        // 计算下次复习时间
        data.nextReviewDate = Date().addingTimeInterval(data.interval)

        return data
    }

    func getDueWords(from entries: [WordEntry], on date: Date) -> [WordEntry] {
        entries.filter { entry in
            entry.learningState != .mastered && entry.srsData.nextReviewDate <= date
        }
        .sorted { $0.srsData.nextReviewDate < $1.srsData.nextReviewDate }
    }

    // MARK: - Private

    /// 将 ReviewFeedback (0-3) 映射到 SM-2 的 quality (0-5)
    private func mapQuality(_ feedback: ReviewFeedback) -> Int {
        switch feedback {
        case .forgot: return 0
        case .hard:   return 2
        case .good:   return 4
        case .easy:   return 5
        }
    }
}
