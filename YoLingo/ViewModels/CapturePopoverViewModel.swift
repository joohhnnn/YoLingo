import Combine
import Foundation

// MARK: - CapturePopoverViewModel

/// 管理抓词浮窗的状态
/// 抓词成功后弹出，显示单词释义和 AI 例句，用户可选择加入生词本或忽略
@MainActor
final class CapturePopoverViewModel: ObservableObject {

    // MARK: - Published State

    /// 抓取到的原始文本
    @Published var capturedText: String = ""

    /// 词典查询结果
    @Published var dictionaryResult: DictionaryResult?

    /// AI 生成的例句
    @Published var exampleSentences: [String] = []

    /// 来源应用
    @Published var sourceApp: String = ""

    /// 浮窗显示位置（屏幕坐标）
    @Published var position: CGPoint = .zero

    /// 加载状态
    @Published var isLoadingDefinition: Bool = false
    @Published var isLoadingSentences: Bool = false

    /// 是否已添加到生词本
    @Published var isAdded: Bool = false

    /// 错误信息（显示给用户）
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let dictionaryService: DictionaryServiceProtocol
    private let aiService: AIServiceProtocol
    private let repository: WordRepositoryProtocol
    private let eventBus: EventBus
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        dictionaryService: DictionaryServiceProtocol,
        aiService: AIServiceProtocol,
        repository: WordRepositoryProtocol,
        eventBus: EventBus
    ) {
        self.dictionaryService = dictionaryService
        self.aiService = aiService
        self.repository = repository
        self.eventBus = eventBus
        subscribeToEvents()
    }

    // MARK: - Actions

    /// 收到抓词结果后，自动查词和生成例句
    func onWordCaptured(_ result: CaptureResult) {
        capturedText = result.text
        sourceApp = result.sourceApp
        position = result.position
        isAdded = false
        errorMessage = nil
        dictionaryResult = nil
        exampleSentences = []

        // 并行查词典和生成例句
        Task { await lookupDefinition(result.text) }
        Task { await generateSentences(result.text) }
    }

    /// 用户点击「加入生词本」
    func addToVocabulary() {
        guard !isAdded else { return }

        let definition = dictionaryResult?.definitions
            .map { "\($0.partOfSpeech): \($0.meaning)" }
            .joined(separator: "\n") ?? ""

        let entry = WordEntry(
            word: capturedText,
            definition: definition,
            phonetic: dictionaryResult?.phonetic,
            exampleSentences: exampleSentences,
            sourceApp: sourceApp
        )

        Task {
            do {
                // 检查是否已存在（case-insensitive）
                if let existing = try await repository.find(byWord: capturedText) {
                    // 已存在，更新例句等
                    var updated = existing
                    if !exampleSentences.isEmpty {
                        updated.exampleSentences = exampleSentences
                    }
                    try await repository.update(updated)
                    eventBus.emit(.wordUpdated(updated))
                    isAdded = true
                } else {
                    // 新词入库
                    try await repository.save(entry)
                    eventBus.emit(.wordSaved(entry))
                    isAdded = true
                }
            } catch let error as StorageError {
                switch error {
                case .duplicateWord:
                    // 重复词直接标记为已添加（用户不需要再操作）
                    isAdded = true
                case .recordNotFound:
                    errorMessage = error.errorDescription
                }
            } catch {
                errorMessage = "保存失败: \(error.localizedDescription)"
                NSLog("[CapturePopoverVM] addToVocabulary failed: %@", error.localizedDescription)
            }
        }
    }

    /// 用户点击「忽略」
    func dismiss() {
        // 通知 UI 关闭浮窗（通过清空 capturedText 触发）
        capturedText = ""
    }

    // MARK: - Private

    private func lookupDefinition(_ word: String) async {
        isLoadingDefinition = true
        defer { isLoadingDefinition = false }

        do {
            dictionaryResult = try await dictionaryService.lookup(word)
        } catch {
            // 查词失败不阻塞流程，用户仍然可以手动添加
        }
    }

    private func generateSentences(_ word: String) async {
        isLoadingSentences = true
        defer { isLoadingSentences = false }

        do {
            exampleSentences = try await aiService.generateExampleSentences(for: word, count: 2)
        } catch {
            // AI 例句生成失败不阻塞流程
        }
    }

    private func subscribeToEvents() {
        eventBus.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                if case .wordCaptured(let result) = event {
                    self?.onWordCaptured(result)
                }
            }
            .store(in: &cancellables)
    }
}
