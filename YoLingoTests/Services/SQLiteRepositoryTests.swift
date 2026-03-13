import XCTest
@testable import YoLingo

final class SQLiteRepositoryTests: XCTestCase {

    private var repository: SQLiteWordRepository!

    override func setUp() {
        super.setUp()
        // In-memory GRDB database — fast, isolated, no cleanup needed
        repository = try! SQLiteWordRepository()
    }

    override func tearDown() {
        repository = nil
        super.tearDown()
    }

    // MARK: - CRUD Tests

    func testSaveAndFetchAll() async throws {
        let entry = WordEntry(word: "ephemeral", definition: "lasting for a short time")

        try await repository.save(entry)
        let all = try await repository.fetchAll()

        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.word, "ephemeral")
        XCTAssertEqual(all.first?.definition, "lasting for a short time")
    }

    func testSavePreservesAllFields() async throws {
        let entry = WordEntry(
            word: "serendipity",
            definition: "finding good things by chance",
            phonetic: "/ˌserənˈdɪpəti/",
            exampleSentences: ["A serendipity led to the discovery.", "What a serendipity!"],
            sourceApp: "Safari",
            capturedAt: Date(timeIntervalSinceReferenceDate: 1000),
            learningState: .learning,
            srsData: SRSData(
                nextReviewDate: Date(timeIntervalSinceReferenceDate: 2000),
                interval: 86400,
                easeFactor: 2.6,
                repetitions: 3
            )
        )

        try await repository.save(entry)
        let all = try await repository.fetchAll()
        let fetched = try XCTUnwrap(all.first)
        XCTAssertEqual(fetched.id, entry.id)
        XCTAssertEqual(fetched.word, "serendipity")
        XCTAssertEqual(fetched.phonetic, "/ˌserənˈdɪpəti/")
        XCTAssertEqual(fetched.exampleSentences, ["A serendipity led to the discovery.", "What a serendipity!"])
        XCTAssertEqual(fetched.sourceApp, "Safari")
        XCTAssertEqual(fetched.capturedAt.timeIntervalSinceReferenceDate, 1000, accuracy: 0.001)
        XCTAssertEqual(fetched.learningState, LearningState.learning)
        XCTAssertEqual(fetched.srsData.nextReviewDate.timeIntervalSinceReferenceDate, 2000, accuracy: 0.001)
        XCTAssertEqual(fetched.srsData.interval, 86400, accuracy: 0.001)
        XCTAssertEqual(fetched.srsData.easeFactor, 2.6, accuracy: 0.001)
        XCTAssertEqual(fetched.srsData.repetitions, 3)
    }

    func testUpdate() async throws {
        var entry = WordEntry(word: "test", definition: "original")
        try await repository.save(entry)

        entry.definition = "updated"
        try await repository.update(entry)

        let all = try await repository.fetchAll()
        XCTAssertEqual(all.first?.definition, "updated")
    }

    func testUpdateNonExistentThrows() async throws {
        let entry = WordEntry(word: "ghost", definition: "does not exist")

        do {
            try await repository.update(entry)
            XCTFail("Expected StorageError.recordNotFound")
        } catch let error as StorageError {
            if case .recordNotFound(let id) = error {
                XCTAssertEqual(id, entry.id)
            } else {
                XCTFail("Expected recordNotFound error, got \(error)")
            }
        }
    }

    func testDelete() async throws {
        let entry = WordEntry(word: "test", definition: "to be deleted")
        try await repository.save(entry)

        try await repository.delete(entry.id)
        let all = try await repository.fetchAll()

        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - Query Tests

    func testFindByWord() async throws {
        let entry = WordEntry(word: "Serendipity", definition: "finding good things by chance")
        try await repository.save(entry)

        let found = try await repository.find(byWord: "serendipity")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, entry.id)
    }

    func testFindByWordCaseInsensitive() async throws {
        let entry = WordEntry(word: "hello", definition: "a greeting")
        try await repository.save(entry)

        // All case variations should find the same entry
        let found1 = try await repository.find(byWord: "Hello")
        let found2 = try await repository.find(byWord: "HELLO")
        let found3 = try await repository.find(byWord: "hElLo")
        XCTAssertNotNil(found1)
        XCTAssertNotNil(found2)
        XCTAssertNotNil(found3)
    }

    func testFindByWordNotFound() async throws {
        let found = try await repository.find(byWord: "nonexistent")
        XCTAssertNil(found)
    }

    func testFetchWithPredicate() async throws {
        let new = WordEntry(word: "new", definition: "new word", learningState: .new)
        let learning = WordEntry(word: "learning", definition: "learning word", learningState: .learning)
        try await repository.save(new)
        try await repository.save(learning)

        let result = try await repository.fetch { $0.learningState == .learning }
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.word, "learning")
    }

    func testFetchAllOrderedByCapturedAtDesc() async throws {
        let older = WordEntry(
            word: "first",
            definition: "older",
            capturedAt: Date(timeIntervalSinceReferenceDate: 1000)
        )
        let newer = WordEntry(
            word: "second",
            definition: "newer",
            capturedAt: Date(timeIntervalSinceReferenceDate: 2000)
        )
        try await repository.save(older)
        try await repository.save(newer)

        let all = try await repository.fetchAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].word, "second")  // newer first
        XCTAssertEqual(all[1].word, "first")
    }

    // MARK: - Constraint Tests

    func testSaveDuplicateWordThrows() async throws {
        let entry1 = WordEntry(word: "duplicate", definition: "first")
        let entry2 = WordEntry(word: "duplicate", definition: "second")

        try await repository.save(entry1)

        do {
            try await repository.save(entry2)
            XCTFail("Expected StorageError.duplicateWord")
        } catch let error as StorageError {
            if case .duplicateWord(let word) = error {
                XCTAssertEqual(word, "duplicate")
            } else {
                XCTFail("Expected duplicateWord error, got \(error)")
            }
        }
    }

    func testSaveDuplicateWordCaseInsensitiveThrows() async throws {
        let entry1 = WordEntry(word: "Hello", definition: "first")
        let entry2 = WordEntry(word: "hello", definition: "second")

        try await repository.save(entry1)

        do {
            try await repository.save(entry2)
            XCTFail("Expected StorageError.duplicateWord")
        } catch is StorageError {
            // Expected: COLLATE NOCASE treats "Hello" and "hello" as the same
        }
    }
}
