import Combine
import Foundation

// MARK: - FloatingCardViewModel

/// 管理桌面悬浮卡片的状态
@MainActor
final class FloatingCardViewModel: ObservableObject {

    // MARK: - Published State

    /// 当前展示的待复习单词
    @Published var currentWord: WordEntry?

    /// 今日待复习总数
    @Published var dueCount: Int = 0

    /// 是否展开卡片（vs 收缩为小气泡）
    @Published var isExpanded: Bool = true

    /// 收纳弹跳动画触发
    @Published var bounceEffect: Bool = false

    /// 卡片是否显示释义（默认只显示单词）
    @Published var showDefinition: Bool = false

    // MARK: - Dependencies

    private let repository: WordRepositoryProtocol
    private let scheduler: SRSSchedulerProtocol
    private let eventBus: EventBus
    private var cancellables = Set<AnyCancellable>()

    /// 当前待复习队列
    private var dueQueue: [WordEntry] = []

    // MARK: - Init

    init(
        repository: WordRepositoryProtocol,
        scheduler: SRSSchedulerProtocol,
        eventBus: EventBus
    ) {
        self.repository = repository
        self.scheduler = scheduler
        self.eventBus = eventBus
        subscribeToEvents()
    }

    // MARK: - Actions

    /// 加载今日待复习列表
    func loadDueWords() async {
        do {
            let allWords = try await repository.fetchAll()
            dueQueue = scheduler.getDueWords(from: allWords, on: Date())
            dueCount = dueQueue.count
            currentWord = dueQueue.first
            NSLog("[FloatingCard] loadDueWords: %d total, %d due", allWords.count, dueQueue.count)
        } catch {
            NSLog("[FloatingCard] loadDueWords failed: %@", error.localizedDescription)
        }
    }

    /// 用户滑动/点击「认识」
    func markAsKnown() {
        guard let word = currentWord else { return }
        submitFeedback(for: word, feedback: .good)
    }

    /// 用户滑动「不认识」
    func markAsForgotten() {
        guard let word = currentWord else { return }
        submitFeedback(for: word, feedback: .forgot)
    }

    /// 切换展开/收缩状态
    func toggleExpand() {
        isExpanded.toggle()
    }

    /// 翻转卡片显示/隐藏释义
    func toggleDefinition() {
        showDefinition.toggle()
    }

    // MARK: - Private

    private func submitFeedback(for word: WordEntry, feedback: ReviewFeedback) {
        var updatedWord = word
        updatedWord.srsData = scheduler.schedule(word, feedback: feedback)

        if feedback == .easy && updatedWord.srsData.repetitions > 5 {
            updatedWord.learningState = .mastered
        } else if updatedWord.learningState == .new {
            updatedWord.learningState = .learning
        }

        Task {
            try? await repository.update(updatedWord)
            eventBus.emit(.wordReviewed(updatedWord, feedback))
            advanceToNextWord()
        }
    }

    private func advanceToNextWord() {
        guard !dueQueue.isEmpty else { return }
        dueQueue.removeFirst()
        dueCount = dueQueue.count
        currentWord = dueQueue.first
        showDefinition = false
    }

    private func subscribeToEvents() {
        eventBus.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .wordSaved:
                    // 新词入库，触发弹跳动画并刷新
                    self?.bounceEffect = true
                    Task { await self?.loadDueWords() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.bounceEffect = false
                    }
                case .wordUpdated:
                    Task { await self?.loadDueWords() }
                case .reviewSessionEnded:
                    Task { await self?.loadDueWords() }
                case .settingsChanged(let key):
                    switch key {
                    case .floatingCardOpacity, .floatingCardPosition:
                        // FloatingCardWindow 会在 show 时读取 Config，
                        // 后续可在此触发实时重定位
                        break
                    default:
                        break
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}
