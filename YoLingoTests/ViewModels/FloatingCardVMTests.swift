import XCTest
@testable import YoLingo

// MARK: - Mock Services for Testing

final class MockWordRepository: WordRepositoryProtocol {
    var words: [WordEntry] = []

    func save(_ entry: WordEntry) async throws { words.append(entry) }
    func update(_ entry: WordEntry) async throws {
        if let index = words.firstIndex(where: { $0.id == entry.id }) {
            words[index] = entry
        }
    }
    func delete(_ id: UUID) async throws { words.removeAll { $0.id == id } }
    func fetchAll() async throws -> [WordEntry] { words }
    func fetch(where predicate: @Sendable (WordEntry) -> Bool) async throws -> [WordEntry] {
        words.filter(predicate)
    }
    func find(byWord word: String) async throws -> WordEntry? {
        words.first { $0.word.lowercased() == word.lowercased() }
    }
}

final class MockSRSScheduler: SRSSchedulerProtocol {
    func schedule(_ entry: WordEntry, feedback: ReviewFeedback) -> SRSData {
        var data = entry.srsData
        data.repetitions += 1
        data.nextReviewDate = Date().addingTimeInterval(3600)
        return data
    }

    func getDueWords(from entries: [WordEntry], on date: Date) -> [WordEntry] {
        entries.filter { $0.srsData.nextReviewDate <= date }
    }
}

// MARK: - FloatingCardVM Tests

@MainActor
final class FloatingCardVMTests: XCTestCase {

    private var viewModel: FloatingCardViewModel!
    private var mockRepo: MockWordRepository!
    private var mockScheduler: MockSRSScheduler!
    private var eventBus: EventBus!

    override func setUp() {
        super.setUp()
        mockRepo = MockWordRepository()
        mockScheduler = MockSRSScheduler()
        eventBus = EventBus()
        viewModel = FloatingCardViewModel(
            repository: mockRepo,
            scheduler: mockScheduler,
            eventBus: eventBus
        )
    }

    func testLoadDueWordsEmpty() async {
        await viewModel.loadDueWords()
        XCTAssertNil(viewModel.currentWord)
        XCTAssertEqual(viewModel.dueCount, 0)
    }

    func testLoadDueWordsWithEntries() async {
        let entry = WordEntry(
            word: "test",
            definition: "a test",
            srsData: SRSData(nextReviewDate: Date().addingTimeInterval(-3600))
        )
        mockRepo.words = [entry]

        await viewModel.loadDueWords()
        XCTAssertNotNil(viewModel.currentWord)
        XCTAssertEqual(viewModel.dueCount, 1)
    }
}
