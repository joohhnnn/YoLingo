import Foundation

// MARK: - ReviewFeedback

/// 用户对复习单词的反馈，驱动 SRS 调度
enum ReviewFeedback: Int, CaseIterable {
    case forgot = 0   // 完全不认识
    case hard   = 1   // 想了很久才想起来
    case good   = 2   // 认识
    case easy   = 3   // 太简单了

    var label: String {
        switch self {
        case .forgot: return "不认识"
        case .hard:   return "模糊"
        case .good:   return "认识"
        case .easy:   return "简单"
        }
    }
}
