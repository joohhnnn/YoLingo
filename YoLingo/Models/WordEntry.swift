import Foundation

// MARK: - WordEntry

/// 生词本中的一条记录，包含单词信息和 SRS 调度参数
struct WordEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var word: String
    var definition: String
    var phonetic: String?
    var exampleSentences: [String]
    var sourceApp: String
    var capturedAt: Date
    var learningState: LearningState
    var srsData: SRSData

    init(
        id: UUID = UUID(),
        word: String,
        definition: String = "",
        phonetic: String? = nil,
        exampleSentences: [String] = [],
        sourceApp: String = "",
        capturedAt: Date = Date(),
        learningState: LearningState = .new,
        srsData: SRSData = SRSData()
    ) {
        self.id = id
        self.word = word
        self.definition = definition
        self.phonetic = phonetic
        self.exampleSentences = exampleSentences
        self.sourceApp = sourceApp
        self.capturedAt = capturedAt
        self.learningState = learningState
        self.srsData = srsData
    }
}

// MARK: - LearningState

enum LearningState: String, Codable, CaseIterable {
    case new        // 新词，从未复习
    case learning   // 学习中
    case mastered   // 已掌握

    var label: String {
        switch self {
        case .new:      return "新词"
        case .learning: return "学习中"
        case .mastered: return "已掌握"
        }
    }
}

// MARK: - SRSData

/// 间隔重复调度参数
struct SRSData: Codable, Equatable {
    var nextReviewDate: Date
    var interval: TimeInterval    // 当前间隔（秒）
    var easeFactor: Double        // 难度系数，SM-2 默认 2.5
    var repetitions: Int          // 连续正确次数

    init(
        nextReviewDate: Date = Date(),
        interval: TimeInterval = 0,
        easeFactor: Double = 2.5,
        repetitions: Int = 0
    ) {
        self.nextReviewDate = nextReviewDate
        self.interval = interval
        self.easeFactor = easeFactor
        self.repetitions = repetitions
    }
}
