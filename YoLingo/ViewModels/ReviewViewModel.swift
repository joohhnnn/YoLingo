import Combine
import Foundation

// MARK: - ReviewViewModel

/// 管理深度复习界面的状态
/// 支持两种模式：词库浏览（默认）和 SRS 复习会话
@MainActor
final class ReviewViewModel: ObservableObject {

    // MARK: - Published State

    /// 全部生词列表
    @Published var allWords: [WordEntry] = []

    /// 到期待复习数量
    @Published var dueCount: Int = 0

    /// 当前复习的单词
    @Published var currentWord: WordEntry?

    /// 卡片是否翻转（显示释义面）
    @Published var isFlipped: Bool = false

    /// 复习进度
    @Published var progress: ReviewProgress = ReviewProgress()

    /// 复习会话是否进行中
    @Published var isSessionActive: Bool = false

    // MARK: - Dependencies

    private let repository: WordRepositoryProtocol
    private let scheduler: SRSSchedulerProtocol
    private let dictionaryService: DictionaryServiceProtocol
    private let eventBus: EventBus
    private var cancellables = Set<AnyCancellable>()

    /// 待复习队列
    private var reviewQueue: [WordEntry] = []

    // MARK: - Init

    init(
        repository: WordRepositoryProtocol,
        scheduler: SRSSchedulerProtocol,
        dictionaryService: DictionaryServiceProtocol,
        eventBus: EventBus
    ) {
        self.repository = repository
        self.scheduler = scheduler
        self.dictionaryService = dictionaryService
        self.eventBus = eventBus
        subscribeToEvents()
    }

    // MARK: - Data Loading

    /// 加载全部生词和待复习数量
    func loadWords() async {
        do {
            allWords = try await repository.fetchAll()
            let dueWords = scheduler.getDueWords(from: allWords, on: Date())
            dueCount = dueWords.count
            NSLog("[Review] loadWords: %d total, %d due", allWords.count, dueCount)
        } catch {
            NSLog("[Review] loadWords failed: %@", error.localizedDescription)
        }
    }

    // MARK: - Session Management

    /// 开始复习会话
    func startSession() async {
        do {
            let fetchedWords = try await repository.fetchAll()
            allWords = fetchedWords
            reviewQueue = scheduler.getDueWords(from: fetchedWords, on: Date())
            dueCount = reviewQueue.count

            progress = ReviewProgress(
                total: reviewQueue.count,
                completed: 0,
                remaining: reviewQueue.count
            )

            currentWord = reviewQueue.first
            isSessionActive = true
            isFlipped = false
            eventBus.emit(.reviewSessionStarted)
        } catch {
            NSLog("[Review] startSession failed: %@", error.localizedDescription)
        }
    }

    /// 结束复习会话，回到词库列表
    func endSession() {
        isSessionActive = false
        currentWord = nil
        reviewQueue = []
        eventBus.emit(.reviewSessionEnded)
        // 刷新词库列表以反映复习后的变化
        Task { await loadWords() }
    }

    // MARK: - Review Actions

    /// 翻转卡片
    func flipCard() {
        isFlipped.toggle()
    }

    /// 提交复习反馈
    func submitFeedback(_ feedback: ReviewFeedback) {
        guard let word = currentWord else { return }

        var updatedWord = word
        updatedWord.srsData = scheduler.schedule(word, feedback: feedback)

        // 更新学习状态
        switch feedback {
        case .forgot:
            updatedWord.learningState = .learning
        case .easy where updatedWord.srsData.repetitions > 5:
            updatedWord.learningState = .mastered
        default:
            if updatedWord.learningState == .new {
                updatedWord.learningState = .learning
            }
        }

        Task {
            do {
                try await repository.update(updatedWord)
                eventBus.emit(.wordReviewed(updatedWord, feedback))
            } catch {
                NSLog("[Review] submitFeedback update failed: %@", error.localizedDescription)
            }
            advanceToNextWord()
        }
    }

    /// 删除词条
    func deleteWord(_ entry: WordEntry) {
        Task {
            do {
                try await repository.delete(entry.id)
                eventBus.emit(.wordDeleted(entry.id))
                await loadWords()
            } catch {
                NSLog("[Review] deleteWord failed: %@", error.localizedDescription)
            }
        }
    }

    // MARK: - Private

    private func advanceToNextWord() {
        reviewQueue.removeFirst()
        progress.completed += 1
        progress.remaining = reviewQueue.count

        if reviewQueue.isEmpty {
            endSession()
        } else {
            currentWord = reviewQueue.first
            isFlipped = false
        }
    }

    private func subscribeToEvents() {
        eventBus.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .wordSaved, .wordUpdated, .wordDeleted:
                    // 词库变化时刷新列表
                    Task { await self?.loadWords() }
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - ReviewProgress

struct ReviewProgress {
    var total: Int = 0
    var completed: Int = 0
    var remaining: Int = 0

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}
